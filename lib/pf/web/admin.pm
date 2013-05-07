package pf::web::admin;

=head1 NAME

pf::web::admin - module to handle web admin portions of the captive portal

=cut

=head1 DESCRIPTION

pf::web::admin contains the functions necessary to generate different admin-related web pages:
based on pre-defined templates: login, registration, error, etc.

It is possible to customize the behavior of this module by redefining its subs in pf::web::custom.
See F<pf::web::custom> for details.

=head1 CONFIGURATION AND ENVIRONMENT

Templates files are located under: html/admin/templates/.

=cut

use strict;
use warnings;

use Date::Parse qw(str2time);
use HTML::Entities;
use Locale::gettext qw(bindtextdomain textdomain bind_textdomain_codeset);
use Log::Log4perl;
use POSIX qw(setlocale);
use Template;
use Text::CSV;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw();
}

use pf::config;
use pf::person qw(person_modify $PID_RE);
use pf::temporary_password;
use pf::util;
use pf::web qw(i18n ni18n i18n_format);
use pf::web::constants;
use pf::web::guest 1.30;
use pf::web::util;

our $VERSION = 1.00;

our $REGISTRATION_TEMPLATE = "register_guest.html";
our $REGISTRATION_CONTINUE = 10;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=item web_get_locale

Admin-related i18n setup.

=cut

sub web_get_locale {
    my ($cgi,$session) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
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

=item _init_i18n

=cut

sub _init_i18n {
    my ($cgi, $session) = @_;

    setlocale( POSIX::LC_MESSAGES, pf::web::admin::web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    bind_textdomain_codeset( "packetfence", "UTF-8" );
}

=item render_template

Cuts in the session cookies and template rendering boiler plate.

=cut

sub render_template {
    my ($cgi, $session, $template, $stash, $r) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    # so that we will get the calling sub in the logs instead of this utility sub
    local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;

    # initialize generic components to the stash
    my $default = {
        pf::web::constants::to_hash(),
        'logo' => $Config{'general'}{'logo'},
        'i18n' => \&i18n,
        'i18n_format' => \&i18n_format,
    };

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    $logger->debug("rendering template named $template");
    my $tt = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'ADMIN_TEMPLATE_DIR'}, $CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });
    $tt->process( $template, { %$stash, %$default } , $r ) || do {
        $logger->error($tt->error());
        return $FALSE;
    };
    return $TRUE;
}

=item generate_error_page

Error page generator for the Web Admin interface.

=cut

sub generate_error_page {
    my ( $cgi, $session, $error_msg, $r ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->trace("error page requested");
    _init_i18n($cgi, $session);

    my $stash_ref = {
        txt_message => $error_msg,
        username => encode_entities( $session->param("username") ),
    };
    render_template($cgi, $session, 'error.html', $stash_ref, $r);
    exit(0);
}

=item generate_guestcreation_page

Sub to present a guest registration form where we create the guest accounts.

=cut

sub generate_guestcreation_page {
    my ( $cgi, $session, $err, $section ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    _init_i18n($cgi, $session);

    my $vars = {};
    # put seperately because of side effects in anonymous hashref
    $vars->{'firstname'} = $cgi->param("firstname");
    $vars->{'lastname'} = $cgi->param("lastname");
    $vars->{'company'} = $cgi->param("company");
    $vars->{'phone'} = $cgi->param("phone");
    $vars->{'email'} = lc($cgi->param("email"));
    $vars->{'address'} = $cgi->param("address");
    $vars->{'arrival_date'} = $cgi->param("arrival_date") || POSIX::strftime("%Y-%m-%d", localtime(time));
    $vars->{'notes'} = $cgi->param("notes");

    # access duration
    $vars->{'default_duration'} = $cgi->param("access_duration")
        || $Config{'guests_admin_registration'}{'default_access_duration'};

    $vars->{'duration'} = pf::web::util::get_translated_time_hash(
        [ split (/\s*,\s*/, $Config{'guests_admin_registration'}{'access_duration_choices'}) ],
        pf::web::admin::web_get_locale($cgi, $session)
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
    # TODO migrate to the error constants mechanism
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

    render_template($cgi, $session, $pf::web::admin::REGISTRATION_TEMPLATE, $vars);
    exit;
}

=item generate_guestcreation_confirmation_page

=cut

sub generate_guestcreation_confirmation_page {
    my ( $cgi, $session, $info ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    _init_i18n($cgi, $session);

    my $vars = { };
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

    render_template($cgi, $session, 'guestcreation_confirmation.html', $vars);
    exit;
}

=item generate_login_page

Sub to present a admin login form.

=cut

sub generate_login_page {
    my ( $cgi, $session, $err ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    _init_i18n($cgi, $session);

    my $vars = {};
    $vars->{'txt_auth_error'} = i18n($err) if (defined($err));

    # return login
    $vars->{'username'} = encode_entities($cgi->param("username"));

    render_template($cgi, $session, 'login.html', $vars);
    exit;
}

=item authenticate

    return (1, undef) for successfull authentication
    return (0, "error message") for inability to check credentials

=cut

sub authenticate {
    my ( $cgi, $session ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->trace("authentication attempt");

    # validate login and password
    my ($return, $message, $source_id) = &pf::authentication::authenticate($cgi->param("username"), $cgi->param("password") );

    if (defined($return) && $return == 1) {
        my $value = &pf::authentication::match($source_id,
                                               {username => $cgi->param("username")},
                                               pf::Authentication::Action->SET_ACCESS_LEVEL);
        if (defined $value && $value == $WEB_ADMIN_ALL) {
            # save login into session
            $session->param( "username", $cgi->param("username") );
            #$session->param( "authType", $auth_module );
        }
        else {
            return (0, "Not authorized to use this module.");
        }
    }

    return ($return, $message);
}

=item validate_guest_creation

Validation of guest creation. Single guest.

  return (1,0) for successfull validation
  return (0,1) for wrong guest info
  return (0,2) for invalid access duration

=cut

sub validate_guest_creation {
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

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
    $session->param("email", lc($cgi->param("email")));
    $session->param("phone", $cgi->param("phone"));
    $session->param("address", $cgi->param("address"));
    $session->param("arrival_date", $cgi->param("arrival_date"));
    $session->param("access_duration", $cgi->param("access_duration"));
    $session->param("notes", $cgi->param("notes"));
    return (1, 0);
}

=item validate_guest_creation_multiple

Validation of guest creation. Multiple guests.

  return (1,0) for successfull validation
  return (0,1) for missing info
  return (0,2) for invalid access duration
  return (0,3) for invalid arrival date
  return (0,6) for invalid username (prefix)

=cut

sub validate_guest_creation_multiple {
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

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
    $session->param("email", lc($cgi->param("email")));
    $session->param("phone", $cgi->param("phone"));
    $session->param("address", $cgi->param("address"));
    $session->param("arrival_date", $cgi->param("arrival_date"));
    $session->param("access_duration", $cgi->param("access_duration"));
    $session->param("notes", $cgi->param("notes"));

    return (1, 0);
}

=item validate_guest_import

Validation of mass guest imports.

  return (1,0) for successfull validation
  return (0,1) for missing info
  return (0,2) for invalid access duration
  return (0,3) for invalid arrival date
  return (0,4) for corrupted input file

=cut

sub validate_guest_import {
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

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

=item valid_access_duration

Sub to validate that access duration provided is allowed by configuration.
We are doing this because we can't trust what comes from the client.

=cut

sub valid_access_duration {
    my ($value) = @_;
    foreach my $allowed_duration (split (/\s*,\s*/, $Config{'guests_admin_registration'}{'access_duration_choices'})) {
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

=item create_guest

=cut

sub create_guest {
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    _init_i18n($cgi, $session);

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
        'notes' => $session->param("notes").". ".i18n_format("Expected on %s", $session->param("arrival_date")),
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
        pf::web::admin::generate_error_page($cgi, $session, i18n("error: something went wrong creating the guest"));
    }

    # on success
    return $password;
}

=item create_guest_multiple

=cut

sub create_guest_multiple {
    my ($cgi, $session) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');
    _init_i18n($cgi, $session);

    my $prefix = $cgi->param('prefix');
    my $quantity = int($cgi->param('quantity'));
    my $expiration = POSIX::strftime(
      "%Y-%m-%d %H:%M:%S",
      localtime( str2time($session->param("arrival_date")) + $session->param("access_duration") + 24*60*60 )
    );
    my %users = ();
    my $count = 0;

    for (my $i = 1; $i <= $quantity; $i++) {
      my $pid = "$prefix$i";
      # Create/modify person
      my $notes = $session->param("notes").". ".i18n_format("Expected on %s", $session->param("arrival_date"));
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
        pf::web::admin::generate_error_page($cgi, $session, i18n("error: something went wrong creating the guest") );
        return;
    }

    # on success
    return {'valid_from' => $session->param("arrival_date"),
            'duration' => valid_access_duration($session->param("access_duration")),
            'users' => \%users};
}

sub import_csv {
  my ($filename, $delimiter, $columns, $session) = @_;
  my $logger = Log::Log4perl::get_logger(__PACKAGE__);

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
    my $csv = Text::CSV->new({ binary => 1, sep_char => $delimiter });
    while (my $row = $csv->getline($import_fh)) {
      my $pid = $row->[$index{'c_username'}];
      if ($pid !~ /$PID_RE/) {
        $skipped++;
        next;
      }
      # Create/modify person
      my %data = ('firstname' => $index{'c_firstname'} ? $row->[$index{'c_firstname'}] : undef,
                  'lastname'  => $index{'c_lastname'}  ? $row->[$index{'c_lastname'}]  : undef,
                  'email'     => $index{'c_email'}     ? $row->[$index{'c_email'}]     : undef,
                  'telephone' => $index{'c_phone'}     ? $row->[$index{'c_phone'}]     : undef,
                  'company'   => $index{'c_company'}   ? $row->[$index{'c_company'}]   : undef,
                  'address'   => $index{'c_address'}   ? $row->[$index{'c_address'}]   : undef,
                  'notes'     => $index{'c_note'}      ? $row->[$index{'c_note'}]      : undef,
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
                                                       $row->[$index{'c_password'}]);
        $count++ if ($success);
      }
    }
    $csv->eof or $logger->warn("Problem with importation: " . $csv->error_diag());
    close $import_fh;

    return (1, "$count,$skipped");
  }
  else {
    $logger->warn("Can't open CSV file $filename: $@");
    return (0, 5);
  }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
