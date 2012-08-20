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
use HTML::Entities;
use Locale::gettext qw(bindtextdomain textdomain);
use Log::Log4perl;
use POSIX qw(setlocale);
use URI::Escape qw(uri_escape uri_unescape);

use pf::config;
use pf::iplog qw(ip2mac);
use pf::Portal::ProfileFactory;
use pf::util;
# TODO we should aim to get rid of these deps (see other TODO tasks in _initialize)
use pf::web;
# called last to allow redefinitions
use pf::web::custom;

=head1 METHODS

=over

=item new

=cut
sub new {
    my ( $class, %argv ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->debug("instantiating new ". __PACKAGE__ . " object");

    my $self = bless {}, $class;
    
    $self->_initialize();
    return $self;
}

=item _initialize

=cut
# Warning: this task must be the least expensive possible since it will be
# run on every portal hit. We should profile then re-architect to store
# in session expensive components to look for.
sub _initialize {
    my ($self) = @_;

    $self->{'_cgi'} = new CGI;
    $self->{'_cgi'}->charset("UTF-8");

    $self->{'_session'} = new CGI::Session(undef, $self->getCgi, {Directory=>'/tmp'});

    # TODO inline this work here once there's no other pf::web::get_client_ip callers
    $self->{'_client_ip'} = pf::web::get_client_ip($self->getCgi);
    $self->{'_client_mac'} = ip2mac($self->getClientIp);

    $self->{'_destination_url'} = $self->_getDestinationUrl($self->getCgi);

    $self->{'_guest_node_mac'} = undef;

    $self->{'_profile'} = pf::Portal::ProfileFactory->instantiate($self->getClientMac);

    $self->_initializeStash();
    $self->_initializeI18n();
}

=item _initializeStash

Initialize a catalyst-style stash variable that is passed to the template
when rendering.

=cut
sub _initializeStash {
    my ($self) = @_;

    # Fill it with the Web constants first
    $self->{'stash'} = { pf::web::constants::to_hash() };
    $self->stash->{'destination_url'} = $self->getDestinationUrl();
}

=item _initializeI18n

=cut
sub _initializeI18n {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $authorized_locale_txt = $Config{'general'}{'locale'};
    my @authorized_locale_array = split(/\s*,\s*/, $authorized_locale_txt);

    my $override_lang;
    if ( defined($self->getCgi->url_param('lang')) ) {
        $logger->debug("url_param('lang') is " . $self->getCgi->url_param('lang'));
        my $user_chosen_language = $self->getCgi->url_param('lang');
        if (grep(/^$user_chosen_language$/, @authorized_locale_array) == 1) {
            $logger->debug("setting language to user chosen language $user_chosen_language");
            $self->getSession->param("lang", $user_chosen_language);
            $override_lang = $user_chosen_language;
        }
    }
    if ( defined($self->getSession->param("lang")) ) {
        $logger->debug("returning language " . $self->getSession->param("lang") . " from session");
        $override_lang = $self->getSession->param("lang");
    }

    # if it's overridden take it otherwise we take the first locale specified in config
    my $locale = defined($override_lang) ? $override_lang : $authorized_locale_array[0];

    setlocale( POSIX::LC_MESSAGES, $locale );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
}

=item _getDestinationUrl

Returns destination_url properly parsed, defended against XSS and with configured value if not defined.

=cut
sub _getDestinationUrl {
    my ($self, $cgi) = @_;

    # set default if destination_url not set
    return $Config{'trapping'}{'redirecturl'} if (!defined($cgi->param("destination_url")));

    return decode_entities(uri_unescape($cgi->param("destination_url")));
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

=item getClientMac

Returns the MAC of the captive portal client.

=cut
sub getClientMac {
    my ($self) = @_;
    return $self->{'_client_mac'};
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

Returns the proper captive portal profile for the current session.

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

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
