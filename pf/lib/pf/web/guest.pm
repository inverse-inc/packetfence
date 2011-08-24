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
use Encode;
use File::Basename;
use HTML::Entities;
use Locale::gettext;
use Log::Log4perl;
use MIME::Lite::TT;
use Net::LDAP;
use POSIX;
use Template;
use Try::Tiny;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw();
}

use pf::config;
use pf::iplog qw(ip2mac);
use pf::temporary_password 1.10;
use pf::util;
use pf::web qw(i18n ni18n);
use pf::web::auth;
use pf::web::util;
use pf::sms_activation;

our $VERSION = 1.10;

our $LOGIN_TEMPLATE = "login.html";
our $SELF_REGISTRATION_TEMPLATE = "guest.html";

our $REGISTRATION_TEMPLATE = "guest/register_guest.html";
our $REGISTRATION_CONFIRMATION_TEMPLATE = "guest/registration_confirmation.html";
our $DEFAULT_REGISTRATION_DURATION = "12h";
our @REGISTRATION_DURATIONS = ( "1h", "3h", "12h", "1d", "2d", "3d", "5d" );
our $REGISTRATION_CATEGORY = "guest";
our $REGISTRATION_CONTINUE = 4;

our $EMAIL_FROM = undef;
our $EMAIL_CC = undef;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

=item generate_selfregistration_page

Sub to present to a guest so that it can self-register (guest.html), this is not hooked-up by default

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
        i18n            => \&i18n,
        deadline        => $Config{'registration'}{'skip_deadline'},
        destination_url => $destination_url,
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
        post_uri => $post_uri,
    };

    # put seperately because of side effects in anonymous hashref
    $vars->{'firstname'} = encode_entities($cgi->param("firstname"));
    $vars->{'lastname'} = encode_entities($cgi->param("lastname"));
    $vars->{'phone'} = encode_entities($cgi->param("phone"));
    $vars->{'email'} = encode_entities($cgi->param("email"));

    $vars->{'sms_carriers'} = sms_carrier_view_all();
    $logger->info('generate_selfregistration_page');

    # showing errors
    if ( defined($err) ) {
        if ( $err == 1 ) {
            $vars->{'txt_error'} = i18n("Missing mandatory parameter or malformed entry.");
        } elsif ( $err == 2 ) {
            my $localdomain = $Config{'general'}{'domain'};
            $vars->{'txt_error'} = sprintf(i18n("You can't register as a guest with a %s email address. Please register as a regular user using your email address instead."), $localdomain);
        } elsif ( $err == 3 ) {
            $vars->{'txt_error'} = i18n("An error occured while sending the confirmation email.");
        } elsif ( $err == 4 ) {
            $vars->{'txt_error'} = i18n("An error occured while sending the PIN by SMS.");
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

    my $template = Template->new({INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],});
    $template->process($pf::web::guest::SELF_REGISTRATION_TEMPLATE, $vars);
    exit;
}

=item generate_registration_page

Sub to present a guest registration form. 
This is not hooked-up by default

=cut
sub generate_registration_page {
    my ( $cgi, $session, $post_uri, $err ) = @_;
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
        i18n            => \&i18n,
        post_uri => $post_uri,
    };

    # put seperately because of side effects in anonymous hashref
    $vars->{'firstname'} = encode_entities($cgi->param("firstname"));
    $vars->{'lastname'} = encode_entities($cgi->param("lastname"));
    $vars->{'phone'} = encode_entities($cgi->param("phone"));
    $vars->{'email'} = encode_entities($cgi->param("email"));
    $vars->{'arrival_date'} = 
        encode_entities($cgi->param("arrival_date")) || POSIX::strftime("%Y-%m-%d", localtime(time))
    ;

    # access duration
    $vars->{'default_duration'} = normalize_time($pf::web::guest::DEFAULT_REGISTRATION_DURATION);
    $vars->{'duration'} = pf::web::util::get_translated_time_hash(
        \@pf::web::guest::REGISTRATION_DURATIONS, pf::web::web_get_locale($cgi, $session)
    );

    $vars->{'login'} = $session->param("login") || "unknown";

    # showing errors
    if ( defined($err) ) {
        if ( $err == 1 ) {
            $vars->{'txt_error'} = i18n("Missing mandatory parameter or malformed entry.");
        } elsif ( $err == 2 ) {
            $vars->{'txt_error'} = i18n("Access duration is not of an allowed value.");
        } elsif ( $err == 3 ) {
            $vars->{'txt_error'} = i18n("Arrival date is not of expected format.");
        } elsif ( $err == 4 ) {
            $vars->{'txt_error'} = i18n(
                "Guest successfully registered. An email with the username and password has been sent."
            );
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

    my $template = Template->new({ INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], });
    $template->process($pf::web::guest::REGISTRATION_TEMPLATE, $vars); 
    exit;
}

=item valid_access_duration

Sub to validate that access duration provided is allowed by configuration. 
We are doing this because we can't trust what comes from the client.

=cut
sub valid_access_duration {
    my ($value) = @_;
    foreach my $allowed_duration (@REGISTRATION_DURATIONS) {
        return $allowed_duration if ($value == normalize_time($allowed_duration));
    }
    return $FALSE;
}

=item valid_arrival_date

Validate arrival date

=cut
sub valid_arrival_date {
    my ($value) = @_;

    return $TRUE if ($value =~ /^\d{4}-\d{2}-\d{2}$/);
    # otherwise
    return $FALSE;
}

=item validate_selfregistration

Sub to validate self-registering guests, this is not hooked-up by default

=cut
sub validate_selfregistration {

    # return (1,0) for successfull validation
    # return (0,1) for wrong guest info
    # return (0,2) for invalid domain for guests
    # return (0,0) for first attempt
            
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');
    if ($cgi->param("firstname") || $cgi->param("lastname") || $cgi->param("phone") || $cgi->param("email")) {
                
        my $valid_email = ($cgi->param('email') =~ /^[A-z0-9_.-]+@[A-z0-9_-]+(\.[A-z0-9_-]+)*\.[A-z]{2,6}$/);
        my $valid_name = ($cgi->param("firstname") =~ /\w/ && $cgi->param("lastname") =~ /\w/);

        if ($valid_email && $valid_name && $cgi->param("phone") ne '' && length($cgi->param("aup_signed"))) {

            # make sure that they are not local users
            # You should not register as a guest if you are part of the local network
            my $localdomain = $Config{'general'}{'domain'};
            if ($cgi->param('email') =~ /[@.]$localdomain$/i) {
                return (0, 2);
            }

            # auth accepted, save login information in session (we will use them to put the guest in the db)
            $session->param("firstname", $cgi->param("firstname"));
            $session->param("lastname", $cgi->param("lastname"));
            $session->param("email", $cgi->param("email")); 
            $session->param("login", $cgi->param("email"));
            $session->param("phone", $cgi->param("phone"));
            return (1, 0);
        } else {
            return (0, 1);
        }
    }
    return (0, 1);
}

=item validate_registration

Sub to validate guests registration, this is not hooked-up by default

=cut
sub validate_registration {

    # return (1,0) for successfull validation
    # return (0,1) for wrong guest info
    # return (0,2) for invalid access duration
            
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');

    $logger->info("duration: " . $cgi->param('access_duration'));
    my $valid_email = ($cgi->param('email') =~ /^[A-z0-9_.-]+@[A-z0-9_-]+(\.[A-z0-9_-]+)*\.[A-z]{2,6}$/);
    my $valid_name = ($cgi->param("firstname") =~ /\w/ && $cgi->param("lastname") =~ /\w/);

    if (!$valid_email || !$valid_name || $cgi->param("phone") eq '') {
        return (0, 1);
    }

    if (!valid_access_duration($cgi->param('access_duration'))) {
        return (0, 2);
    }

    if (!valid_arrival_date($cgi->param('arrival_date'))) {
        return (0, 3);
    }

    $session->param("firstname", $cgi->param("firstname"));
    $session->param("lastname", $cgi->param("lastname"));
    $session->param("email", $cgi->param("email")); 
    $session->param("phone", $cgi->param("phone"));
    $session->param("arrival_date", $cgi->param("arrival_date"));
    $session->param("access_duration", $cgi->param("access_duration"));
    return (1, 0);
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
        i18n            => \&i18n,
        txt_message     => sprintf(i18n('Access to the guest network has been granted until %s.'), $expiration)
    };

    my $template = Template->new({INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],});
    $template->process("activated.html", $vars);
    exit;
}

=item generate_activation_login_page

Sub to present the a login form before activation. 
This is not hooked-up by default.

=cut
sub generate_activation_login_page {
    my ( $cgi, $session, $err, $html_template ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');
    setlocale( LC_MESSAGES, pf::web::web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );
    my $ip   = $cgi->remote_addr;
    my $vars = {
        logo => $Config{'general'}{'logo'},
        i18n => \&i18n
    };

    $vars->{'login'} = encode_entities($cgi->param("login"));

    # showing errors
    if ( defined($err) ) {
        if ( $err == 1 ) {
            $vars->{'txt_auth_error'} = i18n('error: invalid login or password');
        } elsif ( $err == 2 ) {
            $vars->{'txt_auth_error'} = i18n('error: unable to validate credentials at the moment');
        }
    }

    my $template = Template->new({INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],});
    $template->process($html_template, $vars);
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
        i18n            => \&i18n,
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
        post_uri => $post_uri
    };

    $vars->{'login'} = encode_entities($cgi->param("login"));

    $vars->{list_authentications} = pf::web::auth::list_enabled_auth_types();

    # showing errors
    if ( defined($err) ) {
        if ( $err == 1 ) {
            $vars->{'txt_auth_error'} = i18n('error: invalid login or password');
        } elsif ( $err == 2 ) {
            $vars->{'txt_auth_error'} = i18n('error: unable to validate credentials at the moment');
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

    my $template = Template->new({INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],});
    $template->process($pf::web::guest::LOGIN_TEMPLATE, $vars);
    exit;
}

=item auth 

Sub to authenticate guests.
This is not hooked-up by default.

=cut
sub auth {

    # return ( 1, 0, module specific parameters ) for successful authentication
    # return (0,2) for inability to check credentials
    # return (0,1) for wrong login/password
    # return (0,0) for first attempt

    my ( $cgi, $session, $auth_module ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');
    if ( $cgi->param("login") && $cgi->param("password") ) {

        my ($authenticator, $authReturn, $err, $params);
        try {
            $authenticator = pf::web::auth::get_instance($auth_module);
            # validate login and password
            ($authReturn, $err, $params) = $authenticator->authenticate($cgi->param("login"), $cgi->param("password"));
        } catch {
            $logger->error("Authentication module authentication::$auth_module failed. $_");
        };
        if (!defined($authReturn)) {
            return ( 0, 2 );
        } elsif( $authReturn == 1 ) {
            #save login into session
            $session->param( "login", $cgi->param("login") );
        }
        return ( $authReturn, $err, $params );
    }
    return ( 0, 0 );
}

=item preregister

=cut
sub preregister {
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');

    setlocale( LC_MESSAGES, pf::web::web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    # Login successful, adding person (using edit in case person already exists)
    my $person_add_cmd = "$bin_dir/pfcmd 'person edit \""
        . $session->param("email")."\" "
        . "firstname=\"" . $session->param("firstname") . "\","
        . "lastname=\"" . $session->param("lastname") . "\","
        . "email=\"" . $session->param("email") . "\","
        . "telephone=\"" . $session->param("phone") . "\","
        . "notes=\"".sprintf(i18n("Expected on %s"), $session->param("arrival_date"))."\"'"
    ;
    $logger->info("Adding guest person with command: $person_add_cmd");
    pf_run("$person_add_cmd");

    # expiration is arrival date + access duration + a tolerance window of 24 hrs
    my $expiration = POSIX::strftime("%Y-%m-%d %H:%M:%S", 
        localtime(str2time($session->param("arrival_date")) + $session->param("access_duration") + 24*60*60)
    );

    # we create temporary password with the expiration and a 'not valid before' value
    my $password = pf::temporary_password::generate(
        $session->param("email"), $expiration, $session->param("arrival_date"), 
        valid_access_duration($session->param("access_duration"))
    );

    # failure, redirect to error page
    if (!defined($password)) {
        pf::web::generate_error_page( $cgi, $session, "error: something went wrong creating the guest" );
    }

    # on sucess
    return $password;
}

=item self_preregister

=cut
# TODO
#sub self_preregister {
#}

=item generate_registration_confirmation_page

=cut
sub generate_registration_confirmation_page {
    my ( $cgi, $session, $info ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');

    setlocale( LC_MESSAGES, pf::web::web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    my $vars = {
        logo            => $Config{'general'}{'logo'},
        i18n            => \&i18n
    };

    # add the whole info hashref to the information available in the template
    $vars->{'info'} = $info;

    $vars->{'txt_valid_from'} = sprintf(
        i18n("This username and password will be valid starting %s."),
        $info->{'valid_from'}
    );

    my ($singular, $plural, $value) = get_translatable_time($info->{'duration'});
    $vars->{'txt_duration'} = sprintf(
        i18n("Once authenticated the access will be valid for %d %s."),
        $value, ni18n($singular, $plural, $value)
    );

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );
    my $template = Template->new({INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],});
    $template->process($pf::web::guest::REGISTRATION_CONFIRMATION_TEMPLATE, $vars);
    exit;
}

=item send_registration_confirmation_email

=cut
sub send_registration_confirmation_email {
    my ($info) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');

    my $smtpserver = $Config{'alerting'}{'smtpserver'};
    # local override (EMAIL_FROM) or pf.conf's value or root@domain
    my $from = $pf::web::guest::EMAIL_FROM || $Config{'alerting'}{'fromaddr'} || 'root@' . $fqdn;

    # translate 3d into 3 days with proper plural form handling
    my ($singular, $plural, $value) = get_translatable_time($info->{'duration'});
    $info->{'duration'} = "$value " . ni18n($singular, $plural, $value);

    my $msg = MIME::Lite::TT->new(
        From        =>  $from,
        To          =>  $info->{'email'},
        Cc          =>  $pf::web::guest::EMAIL_CC,
        Subject     =>  encode("MIME-Q", i18n("Guest Network Access Information")),
        Template    =>  "emails-guest_registration.txt.tt",
        TmplOptions =>  { INCLUDE_PATH => "$conf_dir/templates/" },
        TmplParams  =>  $info,
        TmplUpgrade =>  1,
    );

    $msg->send('smtp', $smtpserver, Timeout => 20) 
        or $logger->warn("problem sending guest registration email");
}

=item validate_sponsor_group

Validate that the sponsor email entered is an authorized sponsor in LDAP.

Returns 1 if sponsor is member of proper groups and 0 if not.
On error will return undef and log an error.

This check is not integrated by default.

=cut
sub validate_sponsor_group {
  my ($sponsor_email) = @_;
  my $logger = Log::Log4perl::get_logger("pf::web::guest");

  # TODO externalize this in conf/pf.conf (along with authentication::ldap)
  my $LDAPUserBase = "";
  my $LDAPUserKey = "cn";
  my $LDAPUserScope = "sub";
  my $LDAPBindDN = "";
  my $LDAPBindPassword = "";
  my $LDAPServer = "";
  my $LDAPGroupFilter = '|(memberOf=OU=Group1,DC=packetfence,DC=org)(memberOf=OU=Group2,DC=packetfence,DC=org)'; 

  my $connection = Net::LDAP->new($LDAPServer);
  if (!defined($connection)) {
      $logger->error("Unable to connect to '$LDAPServer'");
      return;
  }

  my $result = $connection->bind($LDAPBindDN, password => $LDAPBindPassword);
  if ($result->is_error) {
      $logger->error("Unable to bind with '$LDAPBindDN'");
      return;
  }

  $result = $connection->search(
      base => $LDAPUserBase,
      filter => "(&($LDAPUserKey=$sponsor_email)($LDAPGroupFilter))",
      scope => $LDAPUserScope,
  );

  if ($result->is_error) {
      $logger->error("Unable to execute search");
      return;
  }

  if ($result->count != 1) {
    return 0;
  }

  my $user = $result->entry(0);

  $connection->unbind;
  return 1;
}

sub generate_sms_confirmation_page {
    my ( $cgi, $session, $post_uri, $destination_url, $err ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    setlocale( LC_MESSAGES, $Config{'general'}{'locale'} );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $ip   = $cgi->remote_addr;
    my $mac  = ip2mac($ip);
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        i18n            => \&i18n,
        destination_url => $destination_url,
        post_uri        => $post_uri,
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ]
    };

    if ( defined($err) ) {
        if ( $err == 1 ) {
            $vars->{'txt_auth_error'} = 'Invalid PIN';
        }
    }

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new({INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],});
    $template->process( 'guest/sms_confirmation.html' , $vars );
    exit;
}

sub web_sms_validation {
    # return (1,0) for successfull authentication
    # return (0,1) for invalid PIN
    # return (0,0) for first attempt
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # no form was submitted, assume first time
    if ($cgi->param("pin")) {
        $logger->info("Mobile phone number validation attempt");
        if (validate_code($cgi->param("pin"))) {
            return (1, 0);
        } else {
            return ( 0, 1 ); #invalid PIN
        }
    } else {
        return ( 0, 0 );
    }
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010,2011 Inverse inc.

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
