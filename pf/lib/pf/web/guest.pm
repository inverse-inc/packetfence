package pf::web::guest;

=head1 NAME

pf::web::guest - module to handle guest portions of the captive portal

=cut

=head1 DESCRIPTION

pf::web::guest contains the functions necessary to generate different guest-related web pages:
based on pre-defined templates: login, registration, release, error, status.  

It is possible to customize the behavior of this module by redefining its subs in pf::web::custom.
See F<pf::web::custom> for details.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following template files: F<release.html>, 
F<login.html>, F<enabler.html>, F<error.html>, F<status.html>, 
F<register.html>.

=cut

use strict;
use warnings;
use Date::Parse;
use File::Basename;
use HTML::Entities;
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
use pf::web;

our $VERSION = 1.10;

our $LOGIN_TEMPLATE = "guest_login.html";
our $REGISTRATION_TEMPLATE = "guest.html";

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

=item generate_selfregistration_page

Sub to present a guest registration page (guest.html), this is not hooked-up by default

=cut
sub generate_selfregistration_page {
    my ( $cgi, $session, $post_uri, $destination_url, $mac, $err ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');
    setlocale( LC_MESSAGES, pf::web::web_get_locale($cgi, $session) );
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
        post_uri => $post_uri,
    };

    # put seperately because of side effects in anonymous hashref
    $vars->{'firstname'} = encode_entities($cgi->param("firstname"));
    $vars->{'lastname'} = encode_entities($cgi->param("lastname"));
    $vars->{'phone'} = encode_entities($cgi->param("phone"));
    $vars->{'email'} = encode_entities($cgi->param("email"));

    # showing errors
    if ( defined($err) ) {
        if ( $err == 1 ) {
            $vars->{'txt_regist_auth_error'} = "Missing mandatory parameter or malformed entry.";
        } elsif ( $err == 2 ) {
            my $localdomain = $Config{'general'}{'domain'};
            $vars->{'txt_regist_auth_error'} = "You can't register as a guest with a $localdomain email address. "
                . "Please register as a regular user using your email address instead.";
        }
    }

    # TODO: make localizable
    # generate list of locales
    #my $authorized_locale_txt = $Config{'general'}{'locale'};
    #my @authorized_locale_array = split(/,/, $authorized_locale_txt);
    #if ( scalar(@authorized_locale_array) == 1 ) {
    #    push @{ $vars->{list_locales} },
    #        { name => 'locale', value => $authorized_locale_array[0] };
    #} else {
    #    foreach my $authorized_locale (@authorized_locale_array) {
    #        push @{ $vars->{list_locales} },
    #            { name => 'locale', value => $authorized_locale };
    #    }
    #}

    my $template = Template->new({INCLUDE_PATH => ["$install_dir/html/user/content/templates"],});
    $template->process($pf::web::guest::REGISTRATION_TEMPLATE, $vars);
    exit;
}

=item validate

Sub to validate guests, this is not hooked-up by default

=cut
sub validate {
    
    # return (1,0) for successfull validation
    # return (0,1) for wrong guest info
    # return (0,2) for invalid domain for guests
    # return (0,0) for first attempt
            
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');
    if ($cgi->param("firstname") || $cgi->param("lastname") || $cgi->param("phone") || $cgi->param("email")) {
                
        my $valid_email = ($cgi->param('email') =~ /^[A-z0-9_.-]+@[A-z0-9_-]+(\.[A-z0-9_-]+)*\.[A-z]{2,6}$/);
        my $valid_name = ($cgi->param("firstname") =~ /\w/ && $cgi->param("lastname") =~ /\w/);

        if ($valid_email && $valid_name && $cgi->param("phone") ne '') {

            # make sure that they are not local users
            # You should not register as a guest if you are part of the local network
            my $localdomain = $Config{'general'}{'domain'};
            if ($cgi->param('email') =~ /[@.]$localdomain$/i) {
                return (0, 4);
            }

            # auth accepted, save login information in session (we will use them to put the guest in the db)
            $session->param("firstname", $cgi->param("firstname"));
            $session->param("lastname", $cgi->param("lastname"));
            $session->param("email", $cgi->param("email")); 
            $session->param("login", $cgi->param("email"));
            $session->param("phone", $cgi->param("phone"));
            return (1, 0);
        } else {
            return (0, 3);
        }
    }
    return ( 0, 0 );
}

=item generate_activation_confirmation_page

Sub to present the activation confirmation. 
This is not hooked-up by default.

=cut
sub generate_activation_confirmation_page {
    my ( $cgi, $session, $expiration ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');
    setlocale( LC_MESSAGES, pf::web::web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );
    my $ip   = $cgi->remote_addr;
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        deadline        => $Config{'registration'}{'skip_deadline'},
        txt_page_title  => "Access to the guest network granted",
        txt_page_header => gettext("PacketFence Registration System"),
        txt_help        => gettext("help: provide info"),
        txt_aup         => gettext("Acceptable Use Policy"),
        txt_all_systems_must_be_registered =>
            gettext("register: all systems must be registered"),
        txt_to_complete => gettext("register: to complete"),
        txt_msg_aup     => gettext("register: aup"),
        expiration      => $expiration,
    };

    my $template = Template->new({INCLUDE_PATH => ["$install_dir/html/user/content/templates"],});
    $template->process("activated.html", $vars);
    exit;
}

=item generate_activation_login_page
        
Sub to present the a login form before activation. 
This is not hooked-up by default.
                
=cut    
sub generate_activation_login_page {
    my ( $cgi, $session, $err ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');
    setlocale( LC_MESSAGES, pf::web::web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );
    my $ip   = $cgi->remote_addr;
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        deadline        => $Config{'registration'}{'skip_deadline'},
        txt_page_title  => "Access to the guest network granted",
        txt_page_header => gettext("PacketFence Registration System"),
        txt_help        => gettext("help: provide info"),
        txt_aup         => gettext("Acceptable Use Policy"),
        txt_all_systems_must_be_registered =>
            gettext("register: all systems must be registered"),
        txt_to_complete => gettext("register: to complete"),
        txt_msg_aup     => gettext("register: aup"),
    };

    $vars->{'login'} = encode_entities($cgi->param("login"));

    # showing errors
    if ( defined($err) ) {
        if ( $err == 1 ) {
            $vars->{'txt_auth_error'} = gettext('error: invalid login or password');
        } elsif ( $err == 2 ) {
            $vars->{'txt_auth_error'} = gettext('error: unable to validate credentials at the moment');
        }
    }

    my $template = Template->new({INCLUDE_PATH => ["$install_dir/html/user/content/templates"],});
    $template->process("activation.html", $vars);
    exit;
}

=item generate_login_page  

Generates a guest login page.
This is not hooked-up by default.

=cut
sub generate_login_page {
    my ( $cgi, $session, $post_uri, $destination_url, $mac, $err ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');
    setlocale( LC_MESSAGES, pf::web::web_get_locale($cgi, $session) );
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
        txt_username    => gettext('Username'),
        txt_login       => gettext('Login'),
        txt_password    => gettext('Password'),
        txt_page_title  => gettext('Login'),
        txt_all_systems_must_be_registered =>
            gettext("register: all systems must be registered"),
        txt_to_complete => gettext("register: to complete"),
        txt_msg_aup     => gettext("register: aup"),
        list_help_info  => [
            { name => gettext('IP'),  value => $ip },
            { name => gettext('MAC'), value => $mac }
        ],
        post_uri => $post_uri,
    };

    $vars->{'login'} = encode_entities($cgi->param("login"));

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

    # showing errors
    if ( defined($err) ) {
        if ( $err == 1 ) {
            $vars->{'txt_auth_error'} = gettext('error: invalid login or password');
        } elsif ( $err == 2 ) {
            $vars->{'txt_auth_error'} = gettext('error: unable to validate credentials at the moment');
        }
    }

    # TODO: make localizable
    # generate list of locales
    #my $authorized_locale_txt = $Config{'general'}{'locale'};
    #my @authorized_locale_array = split(/,/, $authorized_locale_txt);
    #if ( scalar(@authorized_locale_array) == 1 ) {
    #    push @{ $vars->{list_locales} },
    #        { name => 'locale', value => $authorized_locale_array[0] };
    #} else {
    #    foreach my $authorized_locale (@authorized_locale_array) {
    #        push @{ $vars->{list_locales} },
    #            { name => 'locale', value => $authorized_locale };
    #    }
    #}

    my $template = Template->new({INCLUDE_PATH => ["$install_dir/html/user/content/templates"],});
    $template->process($pf::web::guest::LOGIN_TEMPLATE, $vars);
    exit;
}

=item auth 

Sub to authenticate guests.
This is not hooked-up by default.

=cut
sub auth {

    # return (1,0) for successfull authentication
    # return (0,2) for inability to check credentials
    # return (0,1) for wrong login/password
    # return (0,0) for first attempt

    my ( $cgi, $session ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');
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
=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010 Inverse inc.

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
