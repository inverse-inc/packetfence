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

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw();
}

use pf::config;
use pf::iplog qw(ip2mac);
use pf::person qw(person_modify);
use pf::temporary_password 1.10;
use pf::util;
use pf::web qw(i18n ni18n);
use pf::web::auth;
use pf::web::util;
use pf::sms_activation;

our $VERSION = 1.30;

our $LOGIN_TEMPLATE = "login.html";
our $SELF_REGISTRATION_TEMPLATE = "guest.html";

our $REGISTRATION_TEMPLATE = "guest/register_guest.html";
our $REGISTRATION_CONFIRMATION_TEMPLATE = "guest/registration_confirmation.html";
our $REGISTRATION_CONTINUE = 10;

our $EMAIL_FROM = undef;
our $EMAIL_CC = undef;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

=item generate_selfregistration_page

Sub to present to a guest so that it can self-register (guest.html).

=cut
sub generate_selfregistration_page {
    my ( $cgi, $session, $post_uri, $destination_url, $mac, $error_code, $error_args_ref ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');
    $logger->info('generate_selfregistration_page');

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
        destination_url => encode_entities($destination_url),
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ],
        post_uri => $post_uri,
    };

    # put seperately because of side effects in anonymous hashref
    $vars->{'firstname'} = $cgi->param("firstname");
    $vars->{'lastname'} = $cgi->param("lastname");

    $vars->{'organization'} = $cgi->param("organization");
    $vars->{'phone'} = $cgi->param("phone");
    $vars->{'mobileprovider'} = $cgi->param("mobileprovider");
    $vars->{'email'} = $cgi->param("email");

    $vars->{'sponsor_email'} = $cgi->param("sponsor_email");

    $vars->{'sms_carriers'} = sms_carrier_view_all();

    $vars->{'email_guest_allowed'} = defined($guest_self_registration{$SELFREG_MODE_EMAIL});
    $vars->{'sms_guest_allowed'} = defined($guest_self_registration{$SELFREG_MODE_SMS});
    $vars->{'sponsored_guest_allowed'} = defined($guest_self_registration{$SELFREG_MODE_SPONSOR});

    # Error management
    if (defined($error_code) && $error_code != 0) {
        # ideally we'll set the array_ref always and won't need the following
        $error_args_ref = [] if (!defined($error_args_ref)); 
        $vars->{'txt_validation_error'} = sprintf(i18n($GUEST::ERRORS{$error_code}), @$error_args_ref);
    }

    my $template = Template->new({INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],});
    $template->process($pf::web::guest::SELF_REGISTRATION_TEMPLATE, $vars);
    exit;
}

=item generate_registration_page

Sub to present a guest registration form where we create the guest accounts.

=cut
sub generate_registration_page {
    my ( $cgi, $session, $post_uri, $err, $section ) = @_;
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
    $vars->{'firstname'} = $cgi->param("firstname");
    $vars->{'lastname'} = $cgi->param("lastname");
    $vars->{'company'} = $cgi->param("company");
    $vars->{'phone'} = $cgi->param("phone");
    $vars->{'email'} = $cgi->param("email");
    $vars->{'address'} = $cgi->param("address");
    $vars->{'arrival_date'} = $cgi->param("arrival_date") || POSIX::strftime("%Y-%m-%d", localtime(time));
    $vars->{'notes'} = $cgi->param("notes");

    # access duration
    $vars->{'default_duration'} = $cgi->param("access_duration")
        || $Config{'guests_pre_registration'}{'default_access_duration'};

    $vars->{'duration'} = pf::web::util::get_translated_time_hash(
        [ split (/\s*,\s*/, $Config{'guests_pre_registration'}{'access_duration_choices'}) ], 
        pf::web::web_get_locale($cgi, $session)
    );

    # multiple section
    $vars->{'prefix'} = $cgi->param("prefix");
    $vars->{'quantity'} = $cgi->param("quantity");
    $vars->{'columns'} = $cgi->param("columns");

    # import section
    $vars->{'delimiter'} = $cgi->param("delimiter");
    $vars->{'columns'} = $cgi->param("columns"); 

    $vars->{'username'} = $session->param("username") || "unknown";

    # showing errors
    if ( defined($err) ) {
        if ( $err == 1 ) {
            $vars->{'txt_error'} = i18n("Missing mandatory parameter or malformed entry.");
        } elsif ( $err == 2 ) {
            $vars->{'txt_error'} = i18n("Access duration is not of an allowed value.");
        } elsif ( $err == 3 ) {
            $vars->{'txt_error'} = i18n("Arrival date is not of expected format.");
        } elsif ( $err == 4 ) {
            $vars->{'txt_error'} = i18n("The uploaded file was corrupted. Please try again.");
        } elsif ( $err == 5 ) {
            $vars->{'txt_error'} = i18n("Can't open uploaded file.");
        } elsif ( $err == 6 ) {
            $vars->{'txt_error'} = i18n("Usernames must only contain alphanumeric characters.");
        } elsif ( $err == $REGISTRATION_CONTINUE ) {
            $vars->{'txt_error'} = i18n("Guest successfully registered. An email with the username and password has been sent.");
        } else {
            $vars->{'txt_error'} = $err;
        }
    }

    $vars->{'section'} = $section if ($section);

    my $template = Template->new({ INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], });
    $template->process($pf::web::guest::REGISTRATION_TEMPLATE, $vars) || $logger->error($template->error());
    exit;
}

=item valid_access_duration

Sub to validate that access duration provided is allowed by configuration. 
We are doing this because we can't trust what comes from the client.

=cut
sub valid_access_duration {
    my ($value) = @_;
    foreach my $allowed_duration (split (/\s*,\s*/, $Config{'guests_pre_registration'}{'access_duration_choices'})) {
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
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # mandatory parameters are defined in config
    my @mandatory_fields = split( /\s*,\s*/, $Config{'guests_self_registration'}{'mandatory_fields'} );

    # no matter what is defined as mandatory, these are the minimum fields required per mode
    push @mandatory_fields, ('email') if (defined($cgi->param('by_email')));
    push @mandatory_fields, ('sponsor_email') if (defined($cgi->param('by_sponsor')));
    push @mandatory_fields, ('phone', 'mobileprovider') if (defined($cgi->param('by_sms')));

    # build hashlookup (collapses redundant checks together)
    my %mandatory_fields = map { $_ => $TRUE } @mandatory_fields;

    my @missing_fields;
    foreach my $required_field (keys %mandatory_fields) {
        # mandatory must be non-empty
        push @missing_fields, $required_field if ( !$cgi->param($required_field) );
    }

    # some mandatory fields are missing
    if (@missing_fields) {
        return ( $FALSE, $GUEST::ERROR_MISSING_MANDATORY_FIELDS, [ join(", ", map { i18n($_) } @missing_fields) ] );
    }

    if ( $mandatory_fields{'email'} && !pf::web::util::is_email_valid($cgi->param('email')) ) {
        return ($FALSE, $GUEST::ERROR_ILLEGAL_EMAIL);
    }

    if ( $mandatory_fields{'phone'} && !pf::web::util::validate_phone_number($cgi->param('phone')) ) {
        return ($FALSE, $GUEST::ERROR_ILLEGAL_PHONE);
    }

    if (!length($cgi->param("aup_signed"))) {
        return ($FALSE, $GUEST::ERROR_AUP_NOT_ACCEPTED);
    }

    unless (isenabled($Config{'guests_self_registration'}{'allow_localdomain'})) {
        # You should not register as a guest if you are part of the local network
        my $localdomain = $Config{'general'}{'domain'};
        if ($cgi->param('email') =~ /[@.]$localdomain$/i) {
            return ($FALSE, $GUEST::ERROR_EMAIL_UNAUTHORIZED_AS_GUEST, [ $localdomain ]);
        }
    }

    # auth accepted, save login information in session (we will use them to put the guest in the db)
    $session->param("firstname", $cgi->param("firstname"));
    $session->param("lastname", $cgi->param("lastname"));
    $session->param("company", $cgi->param("organization")); 
    $session->param("phone", pf::web::util::validate_phone_number($cgi->param("phone")));
    $session->param("email", $cgi->param("email")); 
    $session->param("sponsor", $cgi->param("sponsor_email")); 
    # by general policy email is the username
    $session->param("login", $cgi->param("email"));
    return ($TRUE, 0);
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

    if (!$valid_email) {
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
    $session->param("company", $cgi->param("company"));
    $session->param("email", $cgi->param("email")); 
    $session->param("phone", $cgi->param("phone"));
    $session->param("address", $cgi->param("address"));
    $session->param("arrival_date", $cgi->param("arrival_date"));
    $session->param("access_duration", $cgi->param("access_duration"));
    $session->param("notes", $cgi->param("notes"));
    return (1, 0);
}

sub validate_registration_multiple {

    # return (1,0) for successfull validation
    # return (0,1) for missing info
    # return (0,2) for invalid access duration
    # return (0,3) for invalid arrival date
    # return (0,6) for invalid username (prefix)
  
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');

    my $prefix = $cgi->param('prefix');
    my $quantity = $cgi->param('quantity');

    unless ($prefix && int($quantity) > 0) {
        return (0, 1);
    }

    if (!valid_access_duration($cgi->param('access_duration'))) {
        return (0, 2);
    }

    if (!valid_arrival_date($cgi->param('arrival_date'))) {
        return (0, 3);
    }

    if ($prefix =~ m/[^a-zA-Z0-9_\-\@]/) {
        return (0, 6);
    }

    $session->param("fistname", $cgi->param("firstname"));
    $session->param("lastname", $cgi->param("lastname"));
    $session->param("company", $cgi->param("company"));
    $session->param("email", $cgi->param("email"));
    $session->param("phone", $cgi->param("phone"));
    $session->param("address", $cgi->param("address"));
    $session->param("arrival_date", $cgi->param("arrival_date"));
    $session->param("access_duration", $cgi->param("access_duration"));
    $session->param("notes", $cgi->param("notes"));
   
    return (1, 0);
}

sub validate_registration_import {

    # return (1,0) for successfull validation
    # return (0,1) for missing info
    # return (0,2) for invalid access duration
    # return (0,3) for invalid arrival date
    # return (0,4) for corrupted input file
  
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');

    my $filename = $cgi->param('users_file');
    my $delimiter = $cgi->param('delimiter');
    my $columns = $cgi->param('columns');

    unless ($filename && $delimiter && $columns) {
        return (0, 1);
    }

    if (!valid_access_duration($cgi->param('access_duration'))) {
        return (0, 2);
    }

    if (!valid_arrival_date($cgi->param('arrival_date'))) {
        return (0, 3);
    }

    my $file = $cgi->upload('users_file');
    if (!$file && $cgi->cgi_error) {
        $logger->warn("Import: Received corrupted file: " . $cgi->cgi_error);
        return (0, 4);
    }

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

=item generate_custom_login_page

Sub to present a login form. Template is provided as a parameter.

=cut
sub generate_custom_login_page {
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

    $vars->{'txt_auth_error'} = i18n($err) if (defined($err));

    # return login
    $vars->{'username'} = encode_entities($cgi->param("username"));

    my $template = Template->new({INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],});
    $template->process($html_template, $vars);
    exit;
}

=item preregister

=cut
sub preregister {
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');

    setlocale( LC_MESSAGES, pf::web::web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    # by default guest identifier is their email address
    my $pid = $session->param("email");
    $session->param("pid", $pid);

    # Login successful, adding person (using modify in case person already exists)
    person_modify($pid, (
        'firstname' => $session->param("firstname"),
        'lastname' => $session->param("lastname"),
        'email' => $session->param("email"),
        'telephone' => $session->param("phone"),
        'company' => $session->param("company"),
        'address' => $session->param("address"),
        'notes' => $session->param("notes").". ".sprintf(i18n("Expected on %s"), $session->param("arrival_date")),
        'sponsor' => $session->param("username")
    ));
    $logger->info("Adding guest person " . $pid);

    # expiration is arrival date + access duration + a tolerance window of 24 hrs
    my $expiration = POSIX::strftime("%Y-%m-%d %H:%M:%S", 
        localtime(str2time($session->param("arrival_date")) + $session->param("access_duration") + 24*60*60)
    );

    # we create temporary password with the expiration and a 'not valid before' value
    my $password = pf::temporary_password::generate(
        $pid, $expiration, $session->param("arrival_date"), 
        valid_access_duration($session->param("access_duration"))
    );

    # failure, redirect to error page
    if (!defined($password)) {
        pf::web::generate_error_page( $cgi, $session, "error: something went wrong creating the guest" );
    }

    # on success
    return $password;
}

=item preregister_multiple

=cut
sub preregister_multiple {
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');

    setlocale( LC_MESSAGES, pf::web::web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    my $prefix = $cgi->param('prefix');
    my $quantity = int($cgi->param('quantity'));
    my $expiration = POSIX::strftime("%Y-%m-%d %H:%M:%S", 
                                     localtime(str2time($session->param("arrival_date")) + $session->param("access_duration") + 24*60*60));
    my %users = ();
    my $count = 0;

    for (my $i = 1; $i <= $quantity; $i++) {
      my $pid = "$prefix$i";
      # Create/modify person
      my $notes = $session->param("notes").". ".sprintf(i18n("Expected on %s"), $session->param("arrival_date"));
      my $result = person_modify($pid, ('firstname' => $session->param("firstname"),
                                        'lastname' => $session->param("lastname"),
                                        'email' => $session->param("email"),
                                        'telephone' => $session->param("phone"),
                                        'company' => $session->param("company"),
                                        'address' => $session->param("address"),
                                        'notes' => $notes,
                                        'sponsor' => $session->param("username")));
      if ($result) {
        # Create/update password
        my $password = pf::temporary_password::generate($pid,
                                                        $expiration,
                                                        $session->param("arrival_date"), 
                                                        valid_access_duration($session->param("access_duration")));
        if ($password) {
          $users{$pid} = $password;
          $count++;
        }
      }
    }
    $logger->info("Created $count guest accounts: $prefix"."[1-$quantity]. Sponsor by ".$session->param("username"));

    # failure, redirect to error page
    if ($count == 0) {
        pf::web::generate_error_page( $cgi, $session, "error: something went wrong creating the guest" );
        return;
    }

    # on success
    return {'valid_from' => $session->param("arrival_date"),
            'duration' => pf::web::guest::valid_access_duration($session->param("access_duration")),
            'users' => \%users};
}

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

    # admin username
    $vars->{'username'} = $session->param("username"); 

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
    my ( $cgi, $session, $post_uri, $destination_url, $error_code, $error_args_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    setlocale( LC_MESSAGES, $Config{'general'}{'locale'} );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    my $ip   = $cgi->remote_addr;
    my $mac  = ip2mac($ip);
    my $vars = {
        logo            => $Config{'general'}{'logo'},
        i18n            => \&i18n,
        destination_url => encode_entities($destination_url),
        post_uri        => $post_uri,
        list_help_info  => [
            { name => i18n('IP'),  value => $ip },
            { name => i18n('MAC'), value => $mac }
        ]
    };

    # Error management
    if (defined($error_code) && $error_code != 0) {
        $vars->{'txt_auth_error'} = sprintf(i18n($GUEST::ERRORS{$error_code}), @$error_args_ref);
    }

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $template = Template->new({INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],});
    $template->process( 'guest/sms_confirmation.html' , $vars );
    exit;
}

sub web_sms_validation {

    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # no form was submitted, assume first time
    if ($cgi->param("pin")) {
        $logger->info("Mobile phone number validation attempt");
        if (validate_code($cgi->param("pin"))) {
            return ( $TRUE, 0 );
        } else {
            return ( $FALSE, $GUEST::ERROR_INVALID_PIN );
        }
    } else {
        # this won't display an error
        return ( $FALSE, 0 );
    }
}

sub import_csv {
  my ($filename, $delimiter, $columns, $session) = @_;
  my $logger = Log::Log4perl::get_logger('pf::web::guest');

  # Expiration is arrival date + access duration + a tolerance window of 24 hrs
  my $expiration = POSIX::strftime("%Y-%m-%d %H:%M:%S", 
                                   localtime(str2time($session->param("arrival_date")) + $session->param("access_duration") + 24*60*60));

  # Build hash table for columns order
  my $count = 0;
  my $skipped = 0;
  my @order = split(",", $columns);
  my %index = ();
  for (my $i = 0; $i < scalar @order; $i++) {
    $index{$order[$i]} = $i;
  }

  # Map delimiter to its actual character
  if ($delimiter eq 'comma') {
    $delimiter = ',';
  } elsif ($delimiter eq 'semicolon') {
    $delimiter = ';';
  } elsif ($delimiter eq 'colon') {
    $delimiter = ':';
  } elsif ($delimiter eq 'tab') {
    $delimiter = "\t";
  }

  # Read CSV file
  if (open (my $import_fh, "<", $filename)) {
    while (my $line = <$import_fh>) {
      chomp $line;
      my @fields = split($delimiter, $line);
      my $pid = $fields[$index{'c_username'}];
      if ($pid =~ m/[^a-zA-Z0-9_\-\@]/) {
        $skipped++;
        next;
      }
      # Create/modify person
      my %data = ('firstname' => $index{'c_firstname'} ? $fields[$index{'c_firstname'}] : undef,
                  'lastname'  => $index{'c_lastname'}  ? $fields[$index{'c_lastname'}]  : undef,
                  'email'     => $index{'c_email'}     ? $fields[$index{'c_email'}]     : undef,
                  'telephone' => $index{'c_phone'}     ? $fields[$index{'c_phone'}]     : undef,
                  'company'   => $index{'c_company'}   ? $fields[$index{'c_company'}]   : undef,
                  'address'   => $index{'c_address'}   ? $fields[$index{'c_address'}]   : undef,
                  'notes'     => $index{'c_note'}      ? $fields[$index{'c_note'}]      : undef,
                  'sponsor'   => $session->param("username"));
      if ($data{'email'} && $data{'email'} !~ /^[A-z0-9_.-]+@[A-z0-9_-]+(\.[A-z0-9_-]+)*\.[A-z]{2,6}$/) {
        $skipped++;
        next;
      }
      my $result = person_modify($pid, %data);
      if ($result) {
        # Create/update password
        my $success = pf::temporary_password::generate($pid,
                                                       $expiration,
                                                       $session->param("arrival_date"), 
                                                       valid_access_duration($session->param("access_duration")),
                                                       $fields[$index{'c_password'}]);
        $count++ if ($success);
      }
    }
    close $import_fh;

    return (1, "$count,$skipped");
  }
  else {
    $logger->warn("Can't open CSV file $filename: $@");
    return (0, 5);
  }
}

=back

=head1 ERROR STRINGS

=over

=cut
package GUEST;

=item error_code 

PacketFence error codes regarding guests.

=cut
Readonly::Scalar our $ERROR_INVALID_FORM => 1;
Readonly::Scalar our $ERROR_EMAIL_UNAUTHORIZED_AS_GUEST => 2;
Readonly::Scalar our $ERROR_CONFIRMATION_EMAIL => 3;
Readonly::Scalar our $ERROR_CONFIRMATION_SMS => 4;
Readonly::Scalar our $ERROR_MISSING_MANDATORY_FIELDS => 5;
Readonly::Scalar our $ERROR_ILLEGAL_EMAIL => 6;
Readonly::Scalar our $ERROR_ILLEGAL_PHONE => 7;
Readonly::Scalar our $ERROR_AUP_NOT_ACCEPTED => 8;

=item errors 

An hash mapping error codes to error messages.

=cut
Readonly::Hash our %ERRORS => (
    $ERROR_INVALID_FORM => 'Missing mandatory parameter or malformed entry',
    $ERROR_EMAIL_UNAUTHORIZED_AS_GUEST => q{You can't register as a guest with a %s email address. Please register as a regular user using your email address instead.},
    $ERROR_CONFIRMATION_EMAIL => 'An error occured while sending the confirmation email.',
    $ERROR_CONFIRMATION_SMS => 'An error occured while sending the PIN by SMS.',
    $ERROR_MISSING_MANDATORY_FIELDS => 'Missing mandatory parameter(s): %s',
    $ERROR_ILLEGAL_EMAIL => 'Illegal email address provided',
    $ERROR_ILLEGAL_PHONE => 'Illegal phone number provided',
    $ERROR_AUP_NOT_ACCEPTED => 'Acceptable Use Policy (AUP) was not accepted',
);

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
