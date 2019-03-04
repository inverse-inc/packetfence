package pf::Portal::Session;

=head1 NAME

pf::Portal::Session

=cut

=head1 DESCRIPTION

pf::Portal::Session wraps several parameter we often need from the captive
portal.

=cut

use strict;
use warnings;

use CGI;
# TODO reconsider logging or showing generic error instead of this..
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use CGI::Session::Driver::chi;
use pf::CHI;
use HTML::Entities;
use Locale::gettext qw(bindtextdomain textdomain bind_textdomain_codeset);
use pf::log;
use POSIX qw(locale_h); #qw(setlocale);
use Readonly;
use URI::Escape::XS qw(uri_escape uri_unescape);
use File::Spec::Functions;
use Digest::MD5 qw(md5_hex);
use Crypt::GeneratePassword qw(word);

use pf::constants;
use pf::config qw(
    %CAPTIVE_PORTAL
    $management_network
);
use pf::file_paths qw($conf_dir);
use pf::ip4log;
use pf::Connection::ProfileFactory;
use pf::util;
use pf::web::constants;
use pf::web::util;
use pf::web::constants;
use pf::activation qw(view_by_code);
use pf::constants::Portal::Session qw($DUMMY_MAC);

=head1 CONSTANTS

=cut

Readonly our $LOOPBACK_IPV4 => '127.0.0.1';

use constant SESSION_ID => 'CGISESSION_PF';

our $EXPIRES_IN = pf::CHI->config->{"storage"}{"httpd.portal"}{"expires_in"};

=head1 METHODS

=over

=item new

=cut

sub new {
    my ( $class, %argv ) = @_;
    my $logger = get_logger();
    $logger->debug("instantiating new ". __PACKAGE__ . " object");

    my $self = bless {}, $class;

    if (defined($argv{'client_mac'})) {
        $self->_initialize($argv{'client_mac'});
    } else {
        $self->_initialize() unless ($argv{'testing'});
    }

    return $self;
}

=item _initialize

=cut

# Warning: this task must be the least expensive possible since it will be
# run on every portal hit. We should profile then re-architect to store
# in session expensive components to look for.
sub _initialize {
    my ($self,$mac) = @_;
    my $logger = get_logger();
    my $cgi = new CGI;
    my $options;
    $cgi->charset("UTF-8");

    $self->{'_cgi'} = $cgi;

    my $md5_mac = defined($mac) ? md5_hex($mac) : undef;
    my $sid = $cgi->cookie(SESSION_ID) || $cgi->param(SESSION_ID) || $md5_mac || md5_hex(word(8, 12));
    $logger->debug("using session id '$sid'" );
    my $session;
    $self->{'_session'} = $session = new CGI::Session( "driver:chi;id:static", $sid, { chi_class => 'pf::CHI', namespace => 'httpd.portal' } );
    $logger->error(CGI::Session->errstr()) unless $session;
    $session->expires($EXPIRES_IN);

    $self->{'_client_ip'} = $self->_restoreFromSession("_client_ip",sub {
            return $self->_resolveIp();
        }
    );

    # Don't assign $mac if the dummy MAC was used for restoring the session
    $self->{'_client_mac'} = ((defined($mac) && $mac ne $DUMMY_MAC) ? $mac : undef) || $self->session->param("_client_mac") || $self->_restoreFromSession("_client_mac",sub {
            return $self->getClientMac;
        }
    );

    my $client_mac = $self->{_client_mac};
    $self->{_dummy_session} = (defined($client_mac) && $client_mac eq $DUMMY_MAC);

    $self->session->param("_client_mac", $client_mac);

    $self->{'_guest_node_mac'} = undef;
    $self->{'_profile'} = $self->_restoreFromSession("_profile", sub {
            return pf::Connection::ProfileFactory->instantiate($self->getClientMac);
        }
    );

    if ( defined $WEB::ALLOWED_RESOURCES_PROFILE_FILTER && defined ($cgi->url(-absolute=>1)) && $cgi->url(-absolute=>1) =~ /$WEB::ALLOWED_RESOURCES_PROFILE_FILTER/o) {
        my $option = {
            'last_uri' => $cgi->url(-absolute=>1),
        };
        $self->session->param('_profile',pf::Connection::ProfileFactory->instantiate($self->getClientMac,$option));
        $self->{'_profile'} = $self->_restoreFromSession("_profile", sub {
                return pf::Connection::ProfileFactory->instantiate($self->getClientMac,$option);
            }
        );
    } else {
        $self->{'_profile'} = $self->_restoreFromSession("_profile", sub {
                return pf::Connection::ProfileFactory->instantiate($self->getClientMac);
            }
        );
    }

    $self->{'_destination_url'} = $self->_restoreFromSession("_destination_url",sub {
            return $self->_getDestinationUrl();
        }
    );

    $self->{'_grant_url'} = $self->_restoreFromSession("_grant_url",sub {
            return $self->getGrantUrl;
        }
    );

    $self->_initializeStash();
    $self->_initializeI18n();
}

=item _restoreFromSession

Restore an item from the session if it does not exists compute the value

=cut

sub _restoreFromSession {
    my ($self,$key,$compute) = @_;
    my $value = $self->session->param($key);
    unless ($value) {
        $value = $compute->();
        $self->session->param($key,$value);
    }
    return $value;
}

=item _initializeStash

Initialize a catalyst-style stash variable that is passed to the template
when rendering.

=cut

sub _initializeStash {
    my ($self) = @_;

    # Fill it with the Web constants first
    $self->{'stash'} = { pf::web::constants::to_hash() };
    $self->stash->{'destination_url'} = $self->_getDestinationUrl();
}

=item _initializeI18n

=cut

sub _initializeI18n {
    my ($self) = @_;
    my $logger = get_logger();

    my ($locale) = $self->getLanguages();
    $logger->debug("Setting locale to $locale");
    setlocale( POSIX::LC_MESSAGES, "$locale.utf8" );
    my $newlocale = setlocale(POSIX::LC_MESSAGES);
    if ($newlocale !~ m/^$locale/) {
        $logger->error("Error while setting locale to $locale.utf8. Is the locale generated on your system?");
    }
    $self->stash->{locale} = $newlocale;
    delete $ENV{'LANGUAGE'}; # Make sure $LANGUAGE is empty otherwise it will override LC_MESSAGES
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    bind_textdomain_codeset( "packetfence", "utf-8" );
    textdomain("packetfence");
}

=item _getDestinationUrl

Returns destination_url properly parsed, defended against XSS and with configured value if not defined.

=cut

sub _getDestinationUrl {
    my ($self) = @_;

    # Return connection profile's redirection URL if destination_url is not set or if redirection URL is forced
    if (!defined($self->cgi->param("destination_url")) || $self->getProfile->forceRedirectURL) {
        return $self->getProfile->getRedirectURL;
    }

    # Respect the user's initial destination URL
    return $self->{'_destination_url'} || decode_entities(uri_unescape($self->cgi->param("destination_url")));
}

=item _resolveIp

Returns the IP address of the client reaching the captive portal.
Either directly connected or through a proxy.

=cut

sub _resolveIp {
    my ($self) = @_;
    my $logger = get_logger();
    $logger->trace("resolving client IP");

    # we fetch CGI's remote address
    # if user is behind a proxy it's not sufficient since we'll get the proxy's IP
    my $directly_connected_ip = $self->cgi->remote_addr();

    # every source IP in this table are considered to be from a proxied source
    my %proxied_lookup = %{$CAPTIVE_PORTAL{'loadbalancers_ip'}}; #load balancers first
    $proxied_lookup{$LOOPBACK_IPV4} = 1; # loopback (proxy-bypass)
    # adding virtual IP if one is present (proxy-bypass w/ high-avail.)
    $proxied_lookup{$management_network->tag('vip')} = 1 if ($management_network && $management_network->tag('vip'));

    # if this is NOT from one of the expected proxy IPs return the IP
    if ( (!$proxied_lookup{$directly_connected_ip}) && !($directly_connected_ip ne '127.0.0.1') ) {
        return $directly_connected_ip;
    }

    # behind a proxy?
    if (defined($ENV{'HTTP_X_FORWARDED_FOR'})) {
        my @proxied_ip = split(',',$ENV{'HTTP_X_FORWARDED_FOR'});
        $logger->debug(
            "Remote Address is $directly_connected_ip. Client is behind proxy? "
            . "Returning: $proxied_ip[0] according to HTTP Headers"
        );
        return $proxied_ip[0];
    }

    $logger->debug("Remote Address is $directly_connected_ip but no further hints of client IP in HTTP Headers");
    return $directly_connected_ip;
}

=item stash

Initialize a catalyst-style stash variable that is passed to the template
when rendering. Use it like that:

  $portalSession->stash->{'username'} = encode_entities($cgi->param("username"));

and then username in the template will be set with the proper values.

One can also use a syntax like this:

  $portalSession->stash( { 'username' =>  encode_entities($cgi->param("username")) } );

Also, it is prepopulated with the Web constants from pf::web::constants.

=cut

sub stash {
    my ( $self, $hashref ) = @_;

    if (defined($hashref) && ref($hashref) eq 'HASH') {
        # merging the hashes, keys provided by caller wins
        $self->{'stash'} = { %{$self->{'stash'}}, %$hashref };
    }

    return $self->{'stash'};
}


=item getCgi

Returns the CGI object.

=cut

sub getCgi {
    my ($self) = @_;
    return $self->{'_cgi'};
}

=item cgi

Returns the CGI object. Allows for more perl-ish syntax:

   $portalSession->cgi->param...

=cut

sub cgi {
    my ($self) = @_;
    return $self->{'_cgi'};
}

=item getSession

Returns the CGI::Session object.

=cut

sub getSession {
    my ($self) = @_;
    return $self->{'_session'};
}

=item session

Returns the CGI::Session object. Allows for more perl-ish syntax:

   $portalSession->session->param...

=cut

sub session {
    my ($self) = @_;
    return $self->{'_session'};
}

=item getClientIp

Returns the IP of the client behind the captive portal. We do proper header
lookups for Proxy bypass and load balancers instead of looking at local TCP
from CGI.

=cut

sub getClientIp {
    my ($self) = @_;
    return $self->{'_client_ip'};
}

=item setClientIp

Set the IP of the captive portal client

=cut

sub setClientIp {
    my ($self,$ip) = @_;
    $self->getSession->param('_client_ip',$ip);
}

=item getClientMac

Returns the MAC of the captive portal client.

=cut

sub getClientMac {
    my ($self) = @_;
    if (defined($self->{'_client_mac'}) ) {
        return encode_entities($self->{'_client_mac'});
    }
    elsif (defined($self->cgi->param('mac'))) {
        return encode_entities($self->cgi->param('mac'));
    }
    return encode_entities(pf::ip4log::ip2mac($self->getClientIp));
}


=item setClientMac

Set the MAC of the captive portal client

=cut

sub setClientMac {
    my ($self,$mac) = @_;
    $self->{'_client_mac'} = $mac;
    $self->session->param('_client_mac',$mac);
}

=item getGrantUrl

Returns the grant url where we have to forward the device

=cut

sub getGrantUrl {
    my ($self) =@_;
    return $self->{'_grant_url'};
}

=item setGrantUrl

Set the grant url where we have to forward the client

=cut

sub setGrantUrl {
    my ($self, $url) =@_;
    $self->session->param('_grant_url',$url);
}

=item getDestinationUrl

Returns the original destination URL requested by the client.

=cut

# TODO we could store this in session and return from session if it exists
sub getDestinationUrl {
    my ($self) = @_;
    return $self->{'_destination_url'};
}

=item setDestinationUrl

Sets the destination url.

=cut

# TODO get rid of this when destination url for billing-engine (different destination url for each tier) will be implemented
sub setDestinationUrl {
    my ($self, $new_destination_url) = @_;

    $self->{'_destination_url'} = $new_destination_url;
}

=item getProfile

Returns the proper connection profile for the current session.

=cut

sub getProfile {
    my ($self) = @_;
    return $self->{'_profile'};
}

=item getGuestNodeMac

Return the guest node mac address in the case of an email activation.

=cut

sub getGuestNodeMac {
    my ($self) = @_;
    return $self->{'_guest_node_mac'};
}

=item setGuestNodeMac

Sets the guest node mac address in the case of an email activation.

=cut

sub setGuestNodeMac {
    my ($self, $guest_node_mac) = @_;

    $self->{'_guest_node_mac'} = $guest_node_mac;
}

=item getTemplateIncludePath

=cut

sub getTemplateIncludePath {
    my ($self) = @_;
    my $profile = $self->getProfile;
    return $profile->{_template_paths};
}

=item getRequestLanguages

Extract the preferred languages from the HTTP request.
Ex: Accept-Language: en-US,en;q=0.8,fr;q=0.6,fr-CA;q=0.4,no;q=0.2,es;q=0.2
will return qw(en_US en fr fr_CA no es)

=cut

sub getRequestLanguages {
    my ($self) = @_;
    my $s = $self->getCgi->http('Accept-language') || 'en_US';
    my @l = split(/,/, $s);
    map { s/;.+// } @l;
    map { s/-/_/g } @l;
    #@l = map { m/^en(_US)?/? ():$_ } @l;

    return \@l;
}

=item getLanguages

Retrieve the user prefered languages from the following ordered sources:

=over

=item 1. the 'lang' URL parameter

=item 2. the 'lang' parameter of the Web session

=item 3. the browser accepted languages

=back

If no language matches the authorized locales from the configuration, the first locale
of the configuration is returned.

=cut

sub getLanguages {
    my ($self) = @_;
    my $logger = get_logger();

    my ($lang, @languages);
    #my $authorized_locales_txt = $Config{'general'}{'locale'};
    my @authorized_locales = $self->getProfile->getLocales();
    unless (scalar @authorized_locales > 0) {
        @authorized_locales = @WEB::LOCALES;
    }
    #my @authorized_locales = split(/\s*,\s*/, $authorized_locales_txt);
    $logger->debug("Authorized locale(s) are " . join(', ', @authorized_locales));

    # 1. Check if a language is specified in the URL
    if ( defined($self->getCgi->url_param('lang')) ) {
        my $user_chosen_language = $self->getCgi->url_param('lang');
        $user_chosen_language =~ s/^(\w{2})(_\w{2})?/lc($1) . uc($2 || "")/e;
        if (grep(/^$user_chosen_language$/, @authorized_locales)) {
            $lang = $user_chosen_language;
            # Store the language in the session
            $self->getSession->param("lang", $lang);
            $logger->debug("locale from the URL is $lang");
        }
        else {
            $logger->warn("locale from the URL $user_chosen_language is not supported");
        }
    }

    # 2. Check if the language is set in the session
    if ( defined($self->getSession->param("lang")) ) {
        $lang = $self->getSession->param("lang");
        push(@languages, $lang) unless (grep/^$lang$/, @languages);
        $logger->debug("locale from the session is $lang");
    }

    # 3. Check the accepted languages of the browser
    my $browser_languages = $self->getRequestLanguages();
    foreach my $browser_language (@$browser_languages) {
        $browser_language =~ s/^(\w{2})(_\w{2})?/lc($1) . uc($2 || "")/e;
        if (grep(/^$browser_language$/, @authorized_locales)) {
            $lang = $browser_language;
            push(@languages, $lang) unless (grep/^$lang$/, @languages);
            $logger->debug("locale from the browser is $lang");
        }
        else {
            $logger->trace("locale from the browser $browser_language is not supported");
        }
    }

    if (scalar @languages > 0) {
        $logger->trace("prefered user languages are " . join(", ", @languages));
    }
    else {
        push(@languages, $authorized_locales[0]);
    }

    return @languages;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

