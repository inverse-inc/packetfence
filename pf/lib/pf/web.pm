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
use Locale::gettext;
use Log::Log4perl;
use POSIX;
use Readonly;
use Template;
use URI::Escape qw(uri_unescape);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw(i18n ni18n);
}

use pf::config;
use pf::enforcement qw(reevaluate_access);
use pf::iplog qw(ip2mac);
use pf::node qw(node_attributes node_modify node_register node_view);
use pf::os qw(dhcp_fingerprint_view);
use pf::useragent;
use pf::util;
use pf::web::auth; 

Readonly our $LOOPBACK_IPV4 => '127.0.0.1';

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

sub web_get_locale {
    my ($cgi,$session) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    my $authorized_locale_txt = $Config{'general'}{'locale'};
    my @authorized_locale_array = split(/\s*,\s*/, $authorized_locale_txt);
    if ( defined($cgi->url_param('lang')) ) {
        $logger->info("url_param('lang') is " . $cgi->url_param('lang'));
        my $user_chosen_language = $cgi->url_param('lang');
        if (grep(/^$user_chosen_language$/, @authorized_locale_array) == 1) {
            $logger->info("setting language to user chosen language "
                 . $user_chosen_language);
            $session->param("lang", $user_chosen_language);
            return $user_chosen_language;
        }
    }
    if ( defined($session->param("lang")) ) {
        $logger->info("returning language " . $session->param("lang")
            . " from session");
        return $session->param("lang");
    }
    return $authorized_locale_array[0];
}

sub generate_release_page {
    my ( $cgi, $session, $destination_url, $mac, $r ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $ip = get_client_ip($cgi);
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        timer           => $Config{'trapping'}{'redirtimer'},
        destination_url => encode_entities($destination_url),
        redirect_url => $Config{'trapping'}{'redirecturl'},
        i18n => \&i18n,
        initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_INITIAL_DELAY'},
        retry_delay => $CAPTIVE_PORTAL{'NET_DETECT_RETRY_DELAY'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
        auto_redirect => $Config{'captive_portal'}{'network_detection'},
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
    };

    # override destination_url if we enabled the always_use_redirecturl option
    if (isenabled($Config{'trapping'}{'always_use_redirecturl'})) {
        $vars->{'destination_url'} = $Config{'trapping'}{'redirecturl'};
    }

    my $html_txt;
    my $template = Template->new({ INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], });
    $template->process( "release.html", $vars, \$html_txt ) || $logger->error($template->error());
    
    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header(
        -cookie         => $cookie,
        -Content_length => length($html_txt),
        -Connection     => 'Close'
    );
    if ($r) { print $r->print($html_txt); }
    else    { print STDOUT $html_txt; }
}

=item supports_mobileconfig_provisioning

Validating that the node supports mobile configuration provisioning, that it's configured 
and that the node's category matches the configuration.

=cut
sub supports_mobileconfig_provisioning {
    my ( $cgi, $session, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');

    return $FALSE if (isdisabled($Config{'provisioning'}{'autoconfig'}));

    # is this an iDevice?
    # TODO get rid of hardcoded targets like that
    my $node_attributes = node_attributes($mac);
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
    my ( $cgi, $session, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');

    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    my $ip = get_client_ip($cgi);
    my $vars = {
        logo => $Config{'general'}{'logo'},
        i18n => \&i18n,
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
    };

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new( { INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], } );
    $template->process( "release_with_xmlconfig.html", $vars ) || $logger->error($template->error());
}

=item generate_apple_mobileconfig_provisioning_xml

Generate the proper .mobileconfig XML to automatically configure Wireless for iOS devices.

=cut
sub generate_apple_mobileconfig_provisioning_xml {
    my ( $cgi, $session ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');

    # if not logged in, disallow access
    return if (!defined($session->param('username')));

    my $vars = {
        username => $session->param('username'),
        ssid => $Config{'provisioning'}{'ssid'},
    };

    # Some required headers
    # http://www.rootmanager.com/iphone-ota-configuration/iphone-ota-setup-with-signed-mobileconfig.html
    print $cgi->header( 'Content-type: application/x-apple-aspen-config; chatset=utf-8' );
    print $cgi->header( 'Content-Disposition: attachment; filename="wireless-profile.mobileconfig"' );

    # Using TT to render the XML with correct variables populated
    my $template = Template->new( { INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], } );
    $template->process( "wireless-profile.xml", $vars ) || $logger->error($template->error());
}

sub generate_scan_start_page {
    my ( $cgi, $session, $destination_url, $r ) = @_;

    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    my $ip = get_client_ip($cgi);
    my $mac = ip2mac($ip);
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        timer           => $Config{'scan'}{'duration'},
        destination_url => encode_entities($destination_url),
        i18n => \&i18n,
        txt_message     => sprintf(
            i18n("system scan in progress"),
            $Config{'scan'}{'duration'}
        ),
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
    };
    # Once the progress bar is over, try redirecting
    my $html_txt;
    my $template = Template->new({ INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], } );
    $template->process( "scan.html", $vars, \$html_txt );
    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header(
        -cookie         => $cookie,
        -Content_length => length($html_txt),
        -Connection     => 'Close'
    );
    if ($r) { $r->print($html_txt); }
    else    { print STDOUT $html_txt; }
}

sub generate_login_page {
    my ( $cgi, $session, $destination_url, $mac, $err ) = @_;
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $ip = get_client_ip($cgi);
    my $vars = {
        i18n            => \&i18n,
        logo            => $Config{'general'}{'logo'},
        destination_url => encode_entities($destination_url),
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
    };

    $vars->{'guest_allowed'} = isenabled($Config{'registration'}{'guests_self_registration'});
    $vars->{'txt_auth_error'} = i18n($err) if (defined($err)); 

    # return login
    $vars->{'username'} = encode_entities($cgi->param("username"));

    # authentication
    $vars->{selected_auth} = encode_entities($cgi->param("auth")) || $Config{'registration'}{'default_auth'}; 
    $vars->{list_authentications} = pf::web::auth::list_enabled_auth_types();

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new( { INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], } );
    $template->process( "login.html", $vars );
    exit;
}

sub generate_enabler_page {
    my ( $cgi, $session, $destination_url, $violation_id, $enable_text ) = @_;
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        destination_url => encode_entities($destination_url),
        violation_id    => $violation_id,
        enable_text     => $enable_text,
        i18n            => \&i18n
    };

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new({ INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], });
    $template->process( "enabler.html", $vars );
    exit;
}

sub generate_redirect_page {
    my ( $cgi, $session, $violation_url, $destination_url ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');

    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    my $vars = {
        logo            => $Config{'general'}{'logo'},
        violation_url   => $violation_url,
        destination_url => encode_entities($destination_url),
        i18n            => \&i18n,
    };

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new( { INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], } );
    $template->process( "redirect.html", $vars ) || $logger->error($template->error());
    exit;
}

=item generate_aup_standalone_page

Called when someone clicked on /aup which is the pop=up URL for mobile phones.

=cut
sub generate_aup_standalone_page {
    my ( $cgi, $session, $mac ) = @_;
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $ip = get_client_ip($cgi);
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        i18n            => \&i18n,
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
    };

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new( { INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], }
    );
    $template->process( "aup.html", $vars );
    exit;
}

sub generate_scan_status_page {
    my ( $cgi, $session, $scan_start_time, $destination_url, $r ) = @_;
    my $refresh_timer = 10; # page will refresh each 10 seconds

    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    my $ip = get_client_ip($cgi);
    my $mac = ip2mac($ip);
    my $vars = {
        logo             => $Config{'general'}{'logo'},
        i18n             => \&i18n,
        txt_message      => sprintf(i18n('scan in progress contact support if too long'), $scan_start_time),
        txt_auto_refresh => sprintf(i18n('automatically refresh'), $refresh_timer),
        destination_url  => encode_entities($destination_url),
        refresh_timer    => $refresh_timer,
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
    };

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new( { INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], } );
    $template->process( "scan-in-progress.html", $vars, $r );
}

sub generate_error_page {
    my ( $cgi, $session, $error_msg, $r ) = @_;
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        i18n            => \&i18n,
    };
    # TODO: this is ugly, we shouldn't do something based on error message provided
    if ( $error_msg eq 'error: only register max nodes' ) {
        my $maxnodes = 0;
        $maxnodes = $Config{'registration'}{'maxnodes'}
            if ( defined $Config{'registration'}{'maxnodes'} );
        $vars->{txt_message} = sprintf( i18n($error_msg), $maxnodes );
    } else {
        $vars->{txt_message} = i18n($error_msg);
    }

    my $ip = get_client_ip($cgi);
    push @{ $vars->{list_help_info} },
        { name => i18n('IP'), value => $ip };
    my $mac = ip2mac($ip);
    if ($mac) {
        push @{ $vars->{list_help_info} },
            { name => i18n('MAC'), value => $mac };
    }

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new( { INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], } );
    $template->process( "error.html", $vars, $r );
}

# ugly hack - fix me!
sub generate_status_page {
    my ( $cgi, $session, $mac ) = @_;

    my $node_info = node_attributes($mac);
    if ( $session->param("username") ne $node_info->{'pid'} ) {
        generate_error_page( $cgi, $session,
            "error: access denied not owner" );
        exit(0);
    }

    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    my $ip   = get_client_ip($cgi);
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        i18n            => \&i18n,
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
    };
    $vars->{list_addresses} = [
        { name => i18n('IP'),  value => $ip },
        { name => i18n('MAC'), value => $mac },
        {   name  => i18n('Hostname'),
            value => $node_info->{'computername'}
        },
        {   name  => i18n('Gateway') . ' (' . i18n('IP') . ')',
            value => ip2gateway($ip)
        },
        {   name  => i18n('Gateway') . ' (' . i18n('MAC') . ')',
            value => ip2mac( ip2gateway($ip) )
        },
    ];
    $vars->{list_node_info} = [
        {   name  => i18n('Status'),
            value => i18n( $node_info->{'status'} )
        },
        { name => i18n('PID'), value => $node_info->{'pid'} },
    ];
    require pf::violation;
    require pf::class;
    my @violations = pf::violation::violation_view_open($mac);

    foreach my $violation (@violations) {
        my $class_info = pf::class::class_view( $violation->{'vid'} );
        push @{ $vars->{list_violations} },
            {
            name  => $class_info->{'description'},
            value => $violation->{'status'}
            };
    }

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );
    my $template = Template->new( { INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], } );
    $template->process( "status.html", $vars );
    exit;
}

=item generate_status_json

Gives information about current node in JSON format

=cut
sub generate_status_json {
    my ( $cgi, $session, $mac ) = @_;

    my $node_info = node_view($mac);
    my $ip = pf::web::get_client_ip($cgi);

    print $cgi->header( 'application/json' );
    print objToJson({
        'mac' => $mac,
        'ip' => $ip,
        'hostname' => $node_info->{'computername'},
        'status' => $node_info->{'status'},
        'pid' => $node_info->{'pid'},
        'nbopenviolations' => $node_info->{'nbopenviolations'}
    });

    exit;
}

=item web_node_register

This sub is meant to be redefined by pf::web::custom to fit your specific needs.
See F<pf::web::custom> for examples.

=cut
sub web_node_register {
    my ( $cgi, $session, $mac, $pid, %info ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');

    # we are good, push the registration
    return _sanitize_and_register($session, $mac, $pid, %info);
}

sub _sanitize_and_register {
    my ( $session, $mac, $pid, %info ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');

    $logger->info("performing node registration MAC: $mac pid: $pid");
    node_register( $mac, $pid, %info );

    unless ( $session->param("do_not_deauth") == $TRUE ) {
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
    my ( $cgi, $session ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    $logger->trace("form validation attempt");

    if ( $cgi->param("username") && $cgi->param("password") && $cgi->param("auth") ) {

        # acceptable use pocliy accepted?
        if (!defined($cgi->param("aup_signed")) || !$cgi->param("aup_signed")) {
            return ( 0 , 'You need to accept the terms before proceeding any further.' );
        }

        # validates if supplied auth type is allowed by configuration
        my $auth = $cgi->param("auth");
        my @auth_choices = split( /\s*,\s*/, $Config{'registration'}{'auth'} );
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
    my ( $cgi, $session, $auth_module ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    $logger->trace("authentication attempt");

    my $authenticator = pf::web::auth::instantiate($auth_module);
    return (0, undef) if (!defined($authenticator));

    # validate login and password
    my $return = $authenticator->authenticate( $cgi->param("username"), $cgi->param("password") );

    if (defined($return) && $return == 1) {
        #save login into session
        $session->param( "username", $cgi->param("username") );
        $session->param( "authType", $auth_module );
    }
    return ($return, $authenticator);
}

sub generate_registration_page {
    my ( $cgi, $session, $destination_url, $mac, $pagenumber ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    $pagenumber = 1 if (!defined($pagenumber));

    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );
    my $ip   = get_client_ip($cgi);
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        deadline        => $Config{'registration'}{'skip_deadline'},
        destination_url => encode_entities($destination_url),
        i18n            => \&i18n,
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
        reg_page_content_file => "register_$pagenumber.html",
    };

    # generate list of locales
    my $authorized_locale_txt = $Config{'general'}{'locale'};
    my @authorized_locale_array = split(/,/, $authorized_locale_txt);
    if ( scalar(@authorized_locale_array) == 1 ) {
        push @{ $vars->{list_locales} },
            { name => 'locale', value => $authorized_locale_array[0] };
    } else {
        foreach my $authorized_locale (@authorized_locale_array) {
            push @{ $vars->{list_locales} },
                { name => 'locale', value => $authorized_locale };
        }
    }

    if ( $pagenumber == $Config{'registration'}{'nbregpages'} ) {
        $vars->{'button_text'} = i18n($Config{'registration'}{'button_text'});
        $vars->{'form_action'} = '/authenticate';
    } else {
        $vars->{'button_text'} = i18n("Next page");
        $vars->{'form_action'} = '/authenticate?mode=next_page&page=' . ( int($pagenumber) + 1 );
    }

    my $template = Template->new( { INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], } );
    $template->process( "register.html", $vars );
    exit;
}

=item generate_pending_page

Shows a page to user saying registration is pending.

=cut
sub generate_pending_page {
    my ( $cgi, $session, $destination_url, $mac ) = @_;
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $ip = $cgi->remote_addr;
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        i18n => \&i18n,
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
        destination_url => encode_entities($destination_url),
        redirect_url => $Config{'trapping'}{'redirecturl'},
        initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_PENDING_INITIAL_DELAY'},
        retry_delay => $CAPTIVE_PORTAL{'NET_DETECT_PENDING_RETRY_DELAY'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
    };

    # override destination_url if we enabled the always_use_redirecturl option
    if (isenabled($Config{'trapping'}{'always_use_redirecturl'})) {
        $vars->{'destination_url'} = $Config{'trapping'}{'redirecturl'};
    }

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new( { INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], } );
    $template->process("pending.html", $vars);
    exit;
}

=item get_client_ip

Returns IP address of the client reaching the captive portal. 
Either directly connected or through a proxy.

=cut
sub get_client_ip {
    my ($cgi) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');

    $logger->trace("request for client IP");

    # we fetch CGI's remote address
    # if user is behind a proxy it's not sufficient since we'll get the proxy's IP
    my $directly_connected_ip = $cgi->remote_addr();

    # handling most common case first
    if ($directly_connected_ip ne $LOOPBACK_IPV4) {
        return $directly_connected_ip;
    }

    # proxied?
    if (defined($ENV{'HTTP_X_FORWARDED_FOR'})) {
        my $proxied_ip = $ENV{'HTTP_X_FORWARDED_FOR'};
        $logger->debug(
            "Remote Address is $LOOPBACK_IPV4. Client is proxied? "
            . "Returning: $proxied_ip according to HTTP Headers"
        );
        return $proxied_ip;
    }

    $logger->debug("Remote Address is $LOOPBACK_IPV4 but no further hints of client IP in HTTP Headers");
    return $directly_connected_ip;
}

=item get_destination_url

Returns destination_url properly parsed, defended against XSS and with configured value if not defined.

=cut
sub get_destination_url {
    my ($cgi) = @_;

    # set default if destination_url not set
    return $Config{'trapping'}{'redirecturl'} if (!defined($cgi->param("destination_url")));

    return decode_entities(uri_unescape($cgi->param("destination_url")));
}

=back

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2008-2011 Inverse inc.

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
