package pf::web;

=head1 NAME

pf::web

=cut

use strict;
use warnings;
use Date::Parse;
use File::Basename;
use POSIX;
use Template;
use Locale::gettext;
use Log::Log4perl;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT
        = qw(generate_release_page generate_login_page generate_enabler_page generate_redirect_page generate_error_page generate_status_page generate_registration_page web_node_register web_user_authenticate);
}

use pf::config;
use pf::util;
use pf::iplog qw(ip2mac);
use pf::node qw(node_view);

sub generate_release_page {
    my ( $cgi, $session, $destination_url ) = @_;
    setlocale( LC_MESSAGES, $Config{'general'}{'locale'} );
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
    if ( -r "$conf_dir/templates/release.pl" ) {
        my $include_fh;
        open $include_fh, '<', "$conf_dir/templates/release.pl";
        while (<$include_fh>) {
            eval $_;
        }
        close $include_fh;
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

sub generate_login_page {
    my ( $cgi, $session, $post_uri, $destination_url, $err ) = @_;
    setlocale( LC_MESSAGES, $Config{'general'}{'locale'} );
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
    if ( -r "$conf_dir/templates/login.pl" ) {
        my $include_fh;
        open $include_fh, '<', "$conf_dir/templates/login.pl";
        while (<$include_fh>) {
            eval $_;
        }
        close $include_fh;
    }
    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
    $template->process( "login.html", $vars );
    exit;
}

sub generate_enabler_page {
    my ( $cgi, $session, $destination_url, $violation_id, $enable_text ) = @_;
    setlocale( LC_MESSAGES, $Config{'general'}{'locale'} );
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
    if ( -r "$conf_dir/templates/enabler.pl" ) {
        my $include_fh;
        open $include_fh, '<', "$conf_dir/templates/enabler.pl";
        while (<$include_fh>) {
            eval $_;
        }
        close $include_fh;
    }
    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
    $template->process( "enabler.html", $vars );
    exit;
}

sub generate_redirect_page {
    my ( $cgi, $session, $violation_url, $destination_url ) = @_;
    setlocale( LC_MESSAGES, $Config{'general'}{'locale'} );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        violation_url   => $violation_url,
        destination_url => $destination_url,
    };

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );
    if ( -r "$conf_dir/templates/redirect.pl" ) {
        my $include_fh;
        open $include_fh, '<', "$conf_dir/templates/redirect.pl";
        while (<$include_fh>) {
            eval $_;
        }
        close $include_fh;
    }
    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
    $template->process( "redirect.html", $vars );
    exit;
}

sub generate_error_page {
    my ( $cgi, $session, $error_msg ) = @_;
    setlocale( LC_MESSAGES, $Config{'general'}{'locale'} );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        txt_page_title  => gettext('Sorry'),
        txt_page_header => gettext('Sorry'),
        txt_help        => gettext('help: provide info'),
    };
    if ( $error_msg eq 'error: only register max nodes' ) {
        my $maxnodes = 0;
        $maxnodes = $Config{'registration'}{'maxnodes'}
            if ( defined $Config{'registration'}{'maxnodes'} );
        $vars->{txt_message} = sprintf( gettext($error_msg), $maxnodes );
    } else {
        $vars->{txt_message} = gettext($error_msg);
    }

    my $ip = $cgi->remote_addr;
    push @{ $vars->{list_help_info} },
        { name => gettext('IP'), value => $ip };
    my $mac = ip2mac($ip);
    if ($mac) {
        push @{ $vars->{list_help_info} },
            { name => gettext('MAC'), value => $mac };
    }

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );
    if ( -r "$conf_dir/templates/error.pl" ) {
        my $include_fh;
        open $include_fh, '<', "$conf_dir/templates/error.pl";
        while (<$include_fh>) {
            eval $_;
        }
        close $include_fh;
    }
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
    setlocale( LC_MESSAGES, $Config{'general'}{'locale'} );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $ip   = $cgi->remote_addr;
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

    if ( -r "$conf_dir/templates/status.pl" ) {
        my $include_fh;
        open $include_fh, '<', "$conf_dir/templates/status.pl";
        while (<$include_fh>) {
            eval $_;
        }
        close $include_fh;
    }

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );
    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
    $template->process( "status.html", $vars );
    exit;
}

sub web_node_register {
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

sub web_user_authenticate {

    # return (1,0) for successfull authentication
    # return (0,2) for inability to check credentials
    # return (0,1) for wrong login/password
    # return (0,0) for first attempt

    my ( $cgi, $session ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    if ( $session->param("login") ) {
        return ( 1, 0 );    # if logged in, don't bother going further
    }
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
        use lib $conf_dir;
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
    setlocale( LC_MESSAGES, $Config{'general'}{'locale'} );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );
    my $ip   = $cgi->remote_addr;
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

    if ( $pagenumber == $Config{'registration'}{'nbregpages'} ) {
        $vars->{'button_text'} = $Config{'registration'}{'button_text'};
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

    if ( -r "$conf_dir/templates/register.pl" ) {
        my $include_fh;
        open $include_fh, '<', "$conf_dir/templates/register.pl";
        while (<$include_fh>) {
            eval $_;
        }
        close $include_fh;
    }
    my $template = Template->new(
        { INCLUDE_PATH => ["$install_dir/html/user/content/templates"], } );
    $template->process( "register.html", $vars );
    exit;
}

=head1 COPYRIGHT

Copyright 2005 David LaPorte <david@davidlaporte.org>

Copyright 2005 Kevin Amorin <kev@amorin.org>

Copyright 2008 Dominik Gehl <dgehl@inverse.ca>

See the enclosed file COPYING for license information (GPL).
If you did not receive this file, see
http://www.fsf.org/licensing/licenses/gpl.html.

=cut

1;
