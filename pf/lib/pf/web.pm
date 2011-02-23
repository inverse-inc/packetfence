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
use JSON;
use POSIX;
use Template;
use Locale::gettext;
use Log::Log4perl;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw();
}

use pf::config;
use pf::util;
use pf::iplog qw(ip2mac);
use pf::node qw(node_view node_modify);
use pf::useragent;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

sub web_get_locale {
    my ($cgi,$session) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    my $authorized_locale_txt = $Config{'general'}{'locale'};
    my @authorized_locale_array = split(/,/, $authorized_locale_txt);
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
    my ( $cgi, $session, $destination_url ) = @_;
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        timer           => $Config{'trapping'}{'redirtimer'},
        destination_url => $destination_url,
        txt_page_title  => gettext("release: enabling network"),
        txt_message     => sprintf(
            gettext("network access is being enabled"),
            $Config{'trapping'}{'redirtimer'}
        ),
        txt_enabling => gettext("Enabling ..."),
    };
    if ( $Config{'network'}{'mode'} =~ /vlan/i ) {
        $vars->{js_action} = "var action = function()
{
  hidebar();
  var toReplace=document.getElementById('toReplace');
  toReplace.innerHTML = '<font face=\"Arial\">"
            . gettext("release: reopen browser")
            . "</font>';
}";
    } else {
        $vars->{js_action} = <<EOT;
var action = function() 
{
  hidebar();
  top.location.href=destination_url;
}
EOT
    }
    my $html_txt;
    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
    $template->process( "release.html", $vars, \$html_txt );
    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header(
        -cookie         => $cookie,
        -Content_length => length($html_txt),
        -Connection     => 'Close'
    );
    print STDOUT $html_txt;
    exit;
}

sub generate_scan_start_page {
    my ( $cgi, $session, $destination_url ) = @_;
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        timer           => $Config{'scan'}{'duration'},
        destination_url => $destination_url,
        txt_page_title  => gettext("scan: scan in progress"),
        txt_message     => sprintf(
            gettext("system scan in progress"),
            $Config{'scan'}{'duration'}
        ),
        txt_enabling => gettext("Scanning ..."),
    };
    # Once the progress bar is over, try redirecting
    $vars->{js_action} = "var action = function() { top.location.href=destination_url; }";
    my $html_txt;
    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
    $template->process( "release.html", $vars, \$html_txt );
    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header(
        -cookie         => $cookie,
        -Content_length => length($html_txt),
        -Connection     => 'Close'
    );
    print STDOUT $html_txt;
    exit;
}


sub generate_login_page {
    my ( $cgi, $session, $post_uri, $destination_url, $err ) = @_;
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        destination_url => $destination_url,
        post_uri        => $post_uri,
        txt_username    => gettext('Username'),
        txt_login       => gettext('Login'),
        txt_password    => gettext('Password'),
        txt_page_title  => gettext('Login'),
        txt_select_authentications =>
            gettext("register: select authentications"),
        txt_page_header => gettext('Login')
    };
    if ( defined($err) ) {
        if ( $err == 2 ) {
            $vars->{'txt_auth_error'} = gettext(
                'error: unable to validate credentials at the moment');
        } elsif ( $err == 1 ) {
            $vars->{'txt_auth_error'}
                = gettext('error: invalid login or password');
        }
    }

    my @auth = split( /\s*,\s*/, $Config{'registration'}{'auth'} );

    #
    # if no skip and one Auth type you don't need a pull down...
    if ( scalar(@auth) == 1 ) {
        push @{ $vars->{list_authentications} },
            { name => 'auth', value => $auth[0] };
    } else {
        foreach my $auth (@auth) {
            my $auth_name = $auth;
            push @{ $vars->{list_authentications} },
                { name => $auth, value => $auth };
        }
    }

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
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
        destination_url => $destination_url,
        violation_id    => $violation_id,
        enable_text     => $enable_text,
        txt_print       => gettext('Print this page'),
    };

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
    $template->process( "enabler.html", $vars );
    exit;
}

sub generate_redirect_page {
    my ( $cgi, $session, $violation_url, $destination_url ) = @_;
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        violation_url   => $violation_url,
        destination_url => $destination_url,
    };

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
    $template->process( "redirect.html", $vars );
    exit;
}

sub generate_scan_status_page {
    my ( $cgi, $session, $scan_start_time, $destination_url ) = @_;
    my $refresh_timer = 10; # page will refresh each 10 seconds
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $vars = {
        logo             => $Config{'general'}{'logo'},
        txt_page_title   => gettext('scan: scan in progress'),
        txt_page_header  => gettext('scan: scan in progress'),
        txt_message      => sprintf(gettext('scan in progress contact support if too long'), $scan_start_time),
        txt_auto_refresh => sprintf(gettext('automatically refresh'), $refresh_timer),
        destination_url  => $destination_url,
        refresh_timer    => $refresh_timer
    };

    my $ip = get_client_ip($cgi);
    push @{ $vars->{list_help_info} },
        { name => gettext('IP'), value => $ip };
    my $mac = ip2mac($ip);
    if ($mac) {
        push @{ $vars->{list_help_info} },
            { name => gettext('MAC'), value => $mac };
    }

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
    $template->process( "scan-in-progress.html", $vars );
    exit;
}

sub generate_error_page {
    my ( $cgi, $session, $error_msg ) = @_;
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        txt_page_title  => gettext('Sorry'),
        txt_page_header => gettext('Sorry'),
        txt_help        => gettext('help: provide info'),
    };
    # TODO: this is ugly, we shouldn't do something based on error message provided
    if ( $error_msg eq 'error: only register max nodes' ) {
        my $maxnodes = 0;
        $maxnodes = $Config{'registration'}{'maxnodes'}
            if ( defined $Config{'registration'}{'maxnodes'} );
        $vars->{txt_message} = sprintf( gettext($error_msg), $maxnodes );
    } else {
        $vars->{txt_message} = gettext($error_msg);
    }

    my $ip = get_client_ip($cgi);
    push @{ $vars->{list_help_info} },
        { name => gettext('IP'), value => $ip };
    my $mac = ip2mac($ip);
    if ($mac) {
        push @{ $vars->{list_help_info} },
            { name => gettext('MAC'), value => $mac };
    }

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
    $template->process( "error.html", $vars );
    exit;
}

# ugly hack - fix me!
sub generate_status_page {
    my ( $cgi, $session, $mac ) = @_;
    my ( $auth_return, $err ) = web_user_authenticate( $cgi, $session );
    if ( $auth_return != 1 ) {
        generate_login_page( $cgi, $session, $ENV{REQUEST_URI}, '', $err );
        exit(0);
    }
    my $node_info = node_view($mac);
    if ( $session->param("login") ne $node_info->{'pid'} ) {
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
        txt_page_title  => gettext('Status'),
        txt_page_header => gettext('Status'),
        txt_addresses   => gettext('Addresses'),
        txt_violations  => gettext('Violations'),
        txt_print       => gettext('Print this page'),
        txt_deregister  => gettext('De-register node'),
        txt_node        => gettext('Node')
    };
    $vars->{list_addresses} = [
        { name => gettext('IP'),  value => $ip },
        { name => gettext('MAC'), value => $mac },
        {   name  => gettext('Hostname'),
            value => $node_info->{'computername'}
        },
        {   name  => gettext('Gateway') . ' (' . gettext('IP') . ')',
            value => ip2gateway($ip)
        },
        {   name  => gettext('Gateway') . ' (' . gettext('MAC') . ')',
            value => ip2mac( ip2gateway($ip) )
        },
    ];
    $vars->{list_node_info} = [
        {   name  => gettext('Status'),
            value => gettext( $node_info->{'status'} )
        },
        { name => gettext('PID'), value => $node_info->{'pid'} },
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
    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
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
    return _sanitize_and_register($mac, $pid, %info);
}

sub _sanitize_and_register {
    my ( $mac, $pid, %info ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    my $info;

    foreach my $key ( keys %info ) {
        $info{$key} =~ s/[^0-9a-zA-Z_\*\.\-\:_\;\@\ ]/ /g;
        $info .= $key . '="' . $info{$key} . '",';
    }
    chop($info);
    $logger->info(
        "calling $bin_dir/pfcmd 'manage register $mac \"$pid\" $info'");
    my $cmd    = $bin_dir . "/pfcmd 'manage register $mac \"$pid\" $info'";
    my $output = qx/$cmd/;
    return 1;
}

sub web_node_record_user_agent {
    my ( $mac, $user_agent ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    
    # Recording useragent
    $logger->info("Updating node $mac user_agent with useragent: '$user_agent'");
    # call node_modify directly instead of pfcmd node edit. it's more performant and it'll avoid trying to adjust vlan 
    node_modify($mac, ('user_agent' => $user_agent));

    # match provided useragent in useragent database
    my @user_agent_info = useragent_match($user_agent);
    if ( scalar(@user_agent_info) && ( ref( $user_agent_info[0] ) eq 'HASH' ) ) {

        # is there a violation on this user agent?
        $logger->debug(
            "sending USERAGENT::".$user_agent_info[0]->{'useragent_id'}
            ." (".$user_agent_info[0]->{'useragent'}.") trigger"
        );
        require pf::violation;
        # TODO we should also trigger the broader class (ex: 101 and 1 for a useragent id 101 which is part of class 1)
        # issue #1192
        pf::violation::violation_trigger( $mac, $user_agent_info[0]->{'useragent_id'}, "USERAGENT" );

    } else {
        $logger->info("unknown User-Agent: " . $user_agent);
        # TODO: record unknown useragents here? (how does dhcp fingerprint does it?)
    }

    return 1;
}

sub web_user_authenticate {

    # TODO extract these magic digits in constants
    # return (1,0) for successfull authentication
    # return (0,2) for inability to check credentials
    # return (0,1) for wrong login/password
    # return (0,0) for first attempt

    my ( $cgi, $session ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    if (   $cgi->param("login")
        && $cgi->param("password")
        && $cgi->param("auth") )
    {
        my $auth = $cgi->param("auth");
        my @auth_choices
            = split( /\s*,\s*/, $Config{'registration'}{'auth'} );
        if ( grep( { $_ eq $auth } @auth_choices ) == 0 ) {
            return ( 0, 2 );
        }

        #validate login and password
        eval "use authentication::$auth";
        if ($@) {
            $logger->error("ERROR loading authentication::$auth $@");
            return ( 0, 2 );
        }
        my ( $authReturn, $err )
            = authenticate( $cgi->param("login"), $cgi->param("password") );
        if ( $authReturn == 1 ) {

            #save login into session
            $session->param( "login",    $cgi->param("login") );
            $session->param( "authType", $auth );
        }
        return ( $authReturn, $err );
    }
    return ( 0, 0 );
}

sub generate_registration_page {
    my ( $cgi, $session, $destination_url, $mac, $pagenumber ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    setlocale( LC_MESSAGES, web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );
    my $ip   = get_client_ip($cgi);
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        deadline        => $Config{'registration'}{'skip_deadline'},
        destination_url => $destination_url,
        txt_page_title  => gettext("PacketFence Registration System"),
        txt_page_header => gettext("PacketFence Registration System"),
        txt_help        => gettext("help: provide info"),
        txt_aup         => gettext("Acceptable Use Policy"),
        txt_all_systems_must_be_registered =>
            gettext("register: all systems must be registered"),
        txt_to_complete => gettext("register: to complete"),
        txt_msg_aup     => gettext("register: aup"),
        list_help_info  => [
            { name => gettext('IP'),  value => $ip },
            { name => gettext('MAC'), value => $mac }
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
        $vars->{'button_text'} = gettext($Config{'registration'}{'button_text'});
        $vars->{'form_action'} = '/cgi-bin/register.cgi?mode=register';
    } else {
        $vars->{'button_text'} = ( int($pagenumber) + 1 ) . " / "
            . $Config{'registration'}{'nbregpages'};
        $vars->{'form_action'} = '/cgi-bin/register.cgi?mode=next_page&page='
            . ( int($pagenumber) + 1 );
    }

    # check to see if node can skip reg
    if ( ( $pagenumber == $Config{'registration'}{'nbregpages'} )
        && !( $Config{'network'}{'mode'} =~ /vlan/i ) )
    {
        my $node_info         = node_view($mac);
        my $detect_date       = str2time( $node_info->{'detect_date'} );
        my $registration_mode = $Config{'registration'}{'skip_mode'};

        my $skip_allowed_until = 0;
        if ( isdisabled($registration_mode) ) {
            $skip_allowed_until = 0;
            $logger->info( $node_info->{'mac'}
                    . " is not allowed to skip registration - skip_mode is disabled"
            );
        } else {
            if ( $registration_mode eq "deadline" ) {
                $skip_allowed_until
                    = $Config{'registration'}{'skip_deadline'};
            } elsif ( $registration_mode eq "window" ) {
                $skip_allowed_until
                    = $detect_date + $Config{'registration'}{'skip_window'};
            }

            my $skip_until = POSIX::strftime( "%Y-%m-%d %H:%M:%S",
                POSIX::localtime($skip_allowed_until) );
            if ( time < $skip_allowed_until ) {
                $logger->info( $node_info->{'mac'}
                        . " allowed to skip registration until $skip_until" );
                $vars->{'txt_skip_registration'}
                    = gettext("register: skip registration");
            } else {
                $logger->info( $node_info->{'mac'}
                        . " is not allowed to skip registration - deadline passed at $skip_until - "
                );
            }
        }
    }

    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
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
        txt_page_title  => "Registration pending",
        txt_page_header => "Registration pending",
        txt_help        => gettext('help: provide info'),
        list_help_info  => [
            { name => gettext('IP'),  value => $ip },
            { name => gettext('MAC'), value => $mac }
        ],
        destination_url => $destination_url,
        initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_INITIAL_DELAY'},
        retry_delay => $CAPTIVE_PORTAL{'NET_DETECT_RETRY_DELAY'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
    };

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
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
    if ($directly_connected_ip ne LOOPBACK_IPV4) {
        return $directly_connected_ip;
    }

    # proxied?
    if (defined($ENV{'HTTP_X_FORWARDED_FOR'})) {
        my $proxied_ip = $ENV{'HTTP_X_FORWARDED_FOR'};
        $logger->debug(
            "Remote Address is ".LOOPBACK_IPV4.". Client is proxied? "
            . "Returning: $proxied_ip according to HTTP Headers"
        );
        return $proxied_ip;
    }

    $logger->debug("Remote Address is ".LOOPBACK_IPV4." but no further hints of client IP in HTTP Headers");
    return $directly_connected_ip;
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

Copyright (C) 2008-2010 Inverse inc.

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
