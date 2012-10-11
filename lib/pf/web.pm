package pf::web;

=head1 NAME

pf::web - module to generate the different web pages.

=cut

=head1 DESCRIPTION

pf::web contains the functions necessary to generate different web pages:
based on pre-defined templates: login, registration, release, error, status.  

It is possible to customize the behavior of this module by redefining its subs in pf::web::custom.
See F<pf::web::custom> for details.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following template files: F<release.html>, 
F<login.html>, F<enabler.html>, F<error.html>, F<status.html>, 
F<register.html>.

=cut

#TODO all template destination should be variables allowing redefinitions by pf::web::custom

use strict;
use warnings;

use Date::Parse;
use File::Basename;
use HTML::Entities;
use JSON;
use Locale::gettext qw(gettext ngettext);
use Log::Log4perl;
use Readonly;
use Template;
use URI::Escape qw(uri_escape uri_unescape);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw(i18n ni18n i18n_format render_template);
}

use pf::config;
use pf::enforcement qw(reevaluate_access);
use pf::iplog qw(ip2mac);
use pf::node qw(node_attributes node_modify node_register node_view is_max_reg_nodes_reached);
use pf::os qw(dhcp_fingerprint_view);
use pf::useragent;
use pf::util;
use pf::violation qw(violation_count);
use pf::web::auth; 
use pf::web::constants; 

Readonly our $LOGIN_TEMPLATE => 'login.html';

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

sub i18n {
    my $msgid = shift;

    return gettext($msgid);
}

sub ni18n {
    my $singular = shift;
    my $plural = shift;
    my $category = shift;

    return ngettext($singular, $plural, $category);
}

=item i18n_format

Pass message id through gettext then sprintf it.

Meant to be called from the TT templates.

=cut
sub i18n_format {
    my ($msgid, @args) = @_;

    return sprintf(gettext($msgid), @args);
}

=item render_template

Cuts in the session cookies and template rendering boiler plate.

=cut
sub render_template {
    my ($portalSession, $template, $r) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    # so that we will get the calling sub in the logs instead of this utility sub
    local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;

    # add generic components to the stash
    $portalSession->stash({
        'logo' => $portalSession->getProfile->getLogo,
        'i18n' => \&i18n,
        'i18n_format' => \&i18n_format,
    });

    my @list_help_info;
    push @list_help_info, { name => i18n('IP'),  value => $portalSession->getClientIp }
        if (defined($portalSession->getClientIp));
    push @list_help_info, { name => i18n('MAC'),  value => $portalSession->getClientMac }
        if (defined($portalSession->getClientMac));
    $portalSession->stash({ list_help_info => [ @list_help_info ] });

    # lastly add user-defined stash elements
    $portalSession->stash( pf::web::stash_template_vars() );

    my $cookie = $portalSession->cgi->cookie( CGISESSID => $portalSession->session->id );
    print $portalSession->cgi->header( -cookie => $cookie );

    $logger->debug("rendering template named $template");
    my $tt = Template->new({ 
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'} . $portalSession->getProfile->getTemplatePath], 
    });
    $tt->process( $template, $portalSession->stash, $r ) || do {
        $logger->error($tt->error());
        return $FALSE;
    };
    return $TRUE;
}

=item stash_template_vars

Sub meant to be overridden in L<pf::web::custom> to inject new variables for
consumption by the Templates.

For example, to add a helpdesk phone number variable:

  return { 'helpdesk_phone' => '514-555-1337' };

Afterwards it is available globally, in every template.

=cut
sub stash_template_vars {
    my ($portalSession, $template) = @_;
    return {};
}

sub generate_release_page {
    my ( $portalSession, $r ) = @_;

    $portalSession->stash({
        timer           => $Config{'trapping'}{'redirtimer'},
        redirect_url => $Config{'trapping'}{'redirecturl'},
        initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_INITIAL_DELAY'},
        retry_delay => $CAPTIVE_PORTAL{'NET_DETECT_RETRY_DELAY'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
        auto_redirect => $Config{'captive_portal'}{'network_detection'},
    });

    # override destination_url if we enabled the always_use_redirecturl option
    if (isenabled($Config{'trapping'}{'always_use_redirecturl'})) {
        $portalSession->stash->{'destination_url'} = $Config{'trapping'}{'redirecturl'};
    }

    render_template($portalSession, 'release.html', $r);
}

=item supports_mobileconfig_provisioning

Validating that the node supports mobile configuration provisioning, that it's configured 
and that the node's category matches the configuration.

=cut
sub supports_mobileconfig_provisioning {
    my ( $portalSession ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');

    return $FALSE if (isdisabled($Config{'provisioning'}{'autoconfig'}));

    # is this an iDevice?
    # TODO get rid of hardcoded targets like that
    my $node_attributes = node_attributes($portalSession->getClientMac);
    my @fingerprint = dhcp_fingerprint_view($node_attributes->{'dhcp_fingerprint'});
    return $FALSE if (!defined($fingerprint[0]->{'os'}) || $fingerprint[0]->{'os'} !~ /Apple iPod, iPhone or iPad/); 

    # do we perform provisioning for this category?
    my $config_category = $Config{'provisioning'}{'category'};
    my $node_cat = $node_attributes->{'category'};

    # validating that the node is under the proper category for mobile config provioning
    return $TRUE if ( $config_category eq 'any' || (defined($node_cat) && $node_cat eq $config_category));

    # otherwise
    return $FALSE;
}

=item generate_mobileconfig_provisioning_page

Offers a page that links to the proper provisioning XML.

=cut
sub generate_mobileconfig_provisioning_page {
    my ( $portalSession ) = @_;
    render_template($portalSession, 'release_with_xmlconfig.html');
}

=item generate_apple_mobileconfig_provisioning_xml

Generate the proper .mobileconfig XML to automatically configure Wireless for iOS devices.

=cut
sub generate_apple_mobileconfig_provisioning_xml {
    my ( $portalSession ) = @_;

    # if not logged in, disallow access
    if (!defined($portalSession->session->param('username'))) {
        pf::web::generate_error_page(
            $portalSession,
            i18n("You need to be authenticated to access this page.")
        );
        exit(0);
    }

    $portalSession->stash->{'username'} = $portalSession->session->param('username');
    $portalSession->stash->{'ssid'} = $Config{'provisioning'}{'ssid'};

    # Some required headers
    # http://www.rootmanager.com/iphone-ota-configuration/iphone-ota-setup-with-signed-mobileconfig.html
    print $portalSession->cgi->header('Content-type: application/x-apple-aspen-config; chatset=utf-8');
    print $portalSession->cgi->header('Content-Disposition: attachment; filename="wireless-profile.mobileconfig"');

    render_template($portalSession, 'wireless-profile.xml');
}

sub generate_scan_start_page {
    my ( $portalSession, $r ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $portalSession->stash({
        timer           => $Config{'scan'}{'duration'},
        txt_message     => sprintf(
            i18n("system scan in progress"),
            $Config{'scan'}{'duration'}
        ),
    });

    # Once the progress bar is over, try redirecting
    render_template($portalSession, 'scan.html', $r);
}

sub generate_login_page {
    my ( $portalSession, $err ) = @_;

    $portalSession->stash->{'guest_allowed'} = isenabled($portalSession->getProfile->getGuestSelfReg);
    $portalSession->stash->{'txt_auth_error'} = i18n($err) if (defined($err));

    # return login
    $portalSession->stash->{'username'} = encode_entities($portalSession->cgi->param("username"));
    # authentication
    $portalSession->stash->{'selected_auth'} = encode_entities($portalSession->cgi->param("auth"))
        || $portalSession->getProfile->getDefaultAuth;
    $portalSession->stash->{'list_authentications'} = pf::web::auth::list_enabled_auth_types();

    render_template($portalSession, $LOGIN_TEMPLATE);
}

sub generate_enabler_page {
    my ( $portalSession, $violation_id, $enable_text ) = @_;

    $portalSession->stash->{'violation_id'} = $violation_id;
    $portalSession->stash->{'enable_text'} = $enable_text;

    render_template($portalSession, 'enabler.html');
}

sub generate_redirect_page {
    my ( $portalSession, $violation_url ) = @_;

    $portalSession->stash->{'violation_url'} = $violation_url;

    render_template($portalSession, 'redirect.html');
}

=item generate_aup_standalone_page

Called when someone clicked on /aup which is the pop=up URL for mobile phones.

=cut
sub generate_aup_standalone_page {
    my ( $portalSession ) = @_;
    render_template($portalSession, 'aup.html');
}

sub generate_scan_status_page {
    my ( $portalSession, $scan_start_time, $r ) = @_;

    my $refresh_timer = 10; # page will refresh each 10 seconds

    $portalSession->stash({
        txt_message      => i18n_format('scan in progress contact support if too long', $scan_start_time),
        txt_auto_refresh => i18n_format('automatically refresh', $refresh_timer),
        refresh_timer    => $refresh_timer,
    });

    render_template($portalSession, 'scan-in-progress.html', $r);
}

sub generate_error_page {
    my ( $portalSession, $error_msg, $r ) = @_;

    $portalSession->stash->{'txt_message'} = $error_msg;

    render_template($portalSession, 'error.html', $r);
}

=item web_node_register

This sub is meant to be redefined by pf::web::custom to fit your specific needs.
See F<pf::web::custom> for examples.

=cut
sub web_node_register {
    my ( $portalSession, $pid, %info ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # FIXME quick and hackish fix for #1505. A proper, more intrusive, API changing, fix should hit devel.
    my $mac;
    if (defined($portalSession->getGuestNodeMac)) {
        $mac = $portalSession->getGuestNodeMac;
    }
    else {
        $mac = $portalSession->getClientMac;
    }

    if ( is_max_reg_nodes_reached($mac, $pid, $info{'category'}) ) {
        pf::web::generate_error_page(
            $portalSession, 
            i18n("You have reached the maximum number of devices you are able to register with this username.")
        );
        exit(0);
    }

    # we are good, push the registration
    return _sanitize_and_register($portalSession->session, $mac, $pid, %info);
}

sub _sanitize_and_register {
    my ( $session, $mac, $pid, %info ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');

    $logger->info("performing node registration MAC: $mac pid: $pid");
    node_register( $mac, $pid, %info );

    unless ( defined($session->param("do_not_deauth")) && $session->param("do_not_deauth") == $TRUE ) {
        reevaluate_access( $mac, 'manage_register' );
    }

    return $TRUE;
}

=item web_node_record_user_agent

Records User-Agent for the provided node and triggers violations.

=cut
sub web_node_record_user_agent {
    my ( $mac, $user_agent ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    
    # caching useragents, if it's the same don't bother triggering violations
    my $cached_useragent = $main::useragent_cache->get($mac);

    # Cache hit
    return if (defined($cached_useragent) && $user_agent eq $cached_useragent);

    # Caching and updating node's info
    $logger->trace("adding $mac user-agent to cache");
    $main::useragent_cache->set( $mac, $user_agent, "5 minutes");

    # Recording useragent
    $logger->info("Updating node $mac user_agent with useragent: '$user_agent'");
    node_modify($mac, ('user_agent' => $user_agent));

    # updates the node_useragent information and fires relevant violations triggers
    return pf::useragent::process_useragent($mac, $user_agent);
}

=item validate_form

    return (0, 0) for first attempt
    return (1) for valid form
    return (0, "Error string" ) on form validation problems

=cut
sub validate_form {
    my ( $portalSession ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    $logger->trace("form validation attempt");

    my $cgi = $portalSession->getCgi();
    if ( $cgi->param("username") && $cgi->param("password") && $cgi->param("auth") ) {

        # acceptable use pocliy accepted?
        if (!defined($cgi->param("aup_signed")) || !$cgi->param("aup_signed")) {
            return ( 0 , 'You need to accept the terms before proceeding any further.' );
        }

        # validates if supplied auth type is allowed by configuration
        my $auth = $cgi->param("auth");
        my @auth_choices = split( /\s*,\s*/, $portalSession->getProfile->getAuth );
        if ( grep( { $_ eq $auth } @auth_choices ) == 0 ) {
            return ( 0, 'Unable to validate credentials at the moment' );
        }

        return (1);
    }
    return (0, 'Invalid login or password');
}

=item web_user_authenticate

    return (1, pf::web::auth subclass) for successfull authentication
    return (0, undef) for inability to check credentials
    return (0, pf::web::auth subclass) otherwise (pf::web::auth can give detailed error)

=cut
sub web_user_authenticate {
    my ( $portalSession, $auth_module ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    $logger->trace("authentication attempt");

    my $authenticator = pf::web::auth::instantiate($auth_module);
    return (0, undef) if (!defined($authenticator));

    # validate login and password
    my $return = $authenticator->authenticate( 
        $portalSession->cgi->param("username"),
        $portalSession->cgi->param("password")
    );

    if (defined($return) && $return == 1) {
        #save login into session
        $portalSession->session->param( "username", $portalSession->cgi->param("username") );
        $portalSession->session->param( "authType", $auth_module );
    }
    return ($return, $authenticator);
}

sub generate_registration_page {
    my ( $portalSession, $pagenumber ) = @_;

    $pagenumber = 1 if (!defined($pagenumber));

    $portalSession->stash({
        deadline        => $Config{'registration'}{'skip_deadline'},
        reg_page_content_file => "register_$pagenumber.html",
    });

    # generate list of locales
    my $authorized_locale_txt = $Config{'general'}{'locale'};
    my @authorized_locale_array = split(/,/, $authorized_locale_txt);
    if ( scalar(@authorized_locale_array) == 1 ) {
        push @{ $portalSession->stash->{'list_locales'} },
            { name => 'locale', value => $authorized_locale_array[0] };
    } else {
        foreach my $authorized_locale (@authorized_locale_array) {
            push @{ $portalSession->stash->{'list_locales'} },
                { name => 'locale', value => $authorized_locale };
        }
    }

    if ( $pagenumber == $Config{'registration'}{'nbregpages'} ) {
        $portalSession->stash->{'button_text'} = i18n($Config{'registration'}{'button_text'});
        $portalSession->stash->{'form_action'} = '/authenticate';
    } else {
        $portalSession->stash->{'button_text'} = i18n("Next page");
        $portalSession->stash->{'form_action'} = '/authenticate?mode=next_page&page=' . ( int($pagenumber) + 1 );
    }

    render_template($portalSession, 'register.html');
}

=item generate_pending_page

Shows a page to user saying registration is pending.

=cut
sub generate_pending_page {
    my ( $portalSession ) = @_;

    $portalSession->stash({
        redirect_url => $Config{'trapping'}{'redirecturl'},
        initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_PENDING_INITIAL_DELAY'},
        retry_delay => $CAPTIVE_PORTAL{'NET_DETECT_PENDING_RETRY_DELAY'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
    });

    # override destination_url if we enabled the always_use_redirecturl option
    if (isenabled($Config{'trapping'}{'always_use_redirecturl'})) {
        $portalSession->stash->{'destination_url'} = $Config{'trapping'}{'redirecturl'};
    }

    render_template($portalSession, 'pending.html');
}

=item end_portal_session

Call after you made your changes to the user / node. 
This takes care of handling violations, bouncing back to http for portal 
network access detection or handling mobile provisionning.

This was done in several different locations making maintenance more difficult than it should.
It was regrouped here.

=cut
sub end_portal_session {
    my ( $portalSession ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # First blast at handling portalSession object
    my $mac             = $portalSession->getClientMac();
    my $destination_url = $portalSession->getDestinationUrl();

    # violation handling
    my $count = violation_count($mac);
    if ($count != 0) {
      print $portalSession->cgi->redirect('/captive-portal?destination_url=' . uri_escape($destination_url));
      $logger->info("more violations yet to come for $mac");
      exit(0);
    }

    # handle mobile provisioning if relevant
    if (pf::web::supports_mobileconfig_provisioning($portalSession)) {
        pf::web::generate_mobileconfig_provisioning_page($portalSession);
        exit(0);
    }

    # we drop HTTPS so we can perform our Internet detection and avoid all sort of certificate errors
    if ($portalSession->cgi->https()) {
        print $portalSession->cgi->redirect(
            "http://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
            .'/access?destination_url=' . uri_escape($destination_url)
        );
        exit(0);
    } 

    pf::web::generate_release_page($portalSession);
    exit(0);
}

=item generate_generic_page

Present a generic page. Template and arguments provided to template passed as arguments

=cut
# TODO we could even deprecate that since people calling this here
# could stash to portalSession first.
sub generate_generic_page {
    my ( $portalSession, $template, $template_args ) = @_;

    $portalSession->stash( $template_args );
    render_template($portalSession, $template);
}

=back

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2008-2012 Inverse inc.

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
