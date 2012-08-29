#!/usr/bin/perl
=head1 NAME

guest-management.cgi

=cut
use strict;
use warnings;

use lib "/usr/local/pf/lib";

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;
use PHP::Session;
use POSIX;
use Readonly;
use Template;

use pf::class;
use pf::config;
use pf::email_activation;
use pf::iplog;
use pf::node;
use pf::util;
use pf::violation;
use pf::web;
use pf::web::admin 1.00;
use pf::web::guest 1.40;
# called last to allow redefinitions
use pf::web::custom;

# for guest_managers authentication module
use lib "/usr/local/pf/conf";
use authentication::guest_managers;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('guest-management.cgi');
Log::Log4perl::MDC->put('proc', 'guest-management.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $cgi = new CGI;
$cgi->charset("UTF-8");

my $psession = undef;
my $sid = $cgi->cookie('PHPSESSID');
my $sdir = "$var_dir/session";
if ($sid && -f "$sdir/sess_$sid") {
  $psession = PHP::Session->new($sid, {create => 1, save_path => $sdir});
}

my $session = new CGI::Session(undef, $cgi, {Directory=>"$var_dir/session"});

my $result;
my $ip              = $cgi->remote_addr();
my $enable_menu     = $cgi->param("enable_menu");
my $mac             = ip2mac($ip);

# Is user already logged in?
# If we can find an existing PHP session, we allow the user to proceed.
if ($psession && $psession->get('user')) {
  $session->param("username", $psession->get('user'));
}

if (defined($session->param("username"))) {

    if (defined($cgi->param("action")) && $cgi->param("action") eq "logout") {
        # Logout button
        $session->delete();

        if ($psession && $psession->get('user')) {
          print $cgi->redirect("/login.php?logout=true");
        }
        else {
          pf::web::admin::generate_login_page($cgi, $session);
        }

    }
    elsif (defined($cgi->param("action_print")) || defined($cgi->param("action_sendEmail"))) {
        #
        # Single user registration
        #

        my ($success, $error) = pf::web::admin::validate_guest_creation($cgi, $session);
        if (!$success) {
            $logger->debug("guest registration form didn't pass validation");
            pf::web::admin::generate_guestcreation_page( $cgi, $session, $error, 'single' );
        }
        else {
            $logger->debug("guest registration form passed validation");

            my $password = pf::web::admin::create_guest( $cgi, $session );

            my $info = {
                'firstname' => $session->param("firstname"),
                'lastname' => $session->param("lastname"),
                'email' => $session->param("email"),
                'username' => $session->param("pid"),
                'password' => $password,
                'valid_from' => $session->param("arrival_date"),
                'duration' => pf::web::admin::valid_access_duration($session->param("access_duration")),
                'notes' => $session->param("notes"),
            };

            # tear down session information
            $session->clear([ "firstname", "lastname", "email", "phone", "arrival_date", "access_duration" ]);

            if (defined($cgi->param("action_print"))) {
                # Print page
                pf::web::admin::generate_guestcreation_confirmation_page($cgi, $session, $info);
            }
            else {
                # Otherwise send email
                # translate 3d into 3 days with proper plural form handling
                my ($singular, $plural, $value) = get_translatable_time($info->{'duration'});
                $info->{'duration'} = "$value " . ni18n($singular, $plural, $value);

                pf::web::guest::send_template_email(
                    $pf::web::guest::TEMPLATE_EMAIL_GUEST_ADMIN_PREREGISTRATION, 
                    i18n_format("%s: Guest Network Access Information", $Config{'general'}{'domain'}),
                    $info
                );
                        
                # Return user to the guest registration page
                pf::web::admin::generate_guestcreation_page($cgi, $session,
                                                           $pf::web::admin::REGISTRATION_CONTINUE, 'single');
            }
        }
    }
    elsif (defined($cgi->param("action_print_multiple"))) {
        #
        # Multiple user registration
        #
        my ($success, $error) = pf::web::admin::validate_guest_creation_multiple($cgi, $session);
        if (!$success) {
          $logger->debug("multiple guest creation form didn't pass validation");
          pf::web::admin::generate_guestcreation_page($cgi, $session, $error, 'multiple');
        }
        else {
          $logger->debug("multiple guest creation form passed validation");
          my $info = pf::web::admin::create_guest_multiple($cgi, $session);

          if ($info) {
            # Print page
            pf::web::admin::generate_guestcreation_confirmation_page($cgi, $session, $info);
          }
        }
    }
    elsif (defined($cgi->param("action_import"))) {
        #
        # CSV import
        #
        my ($success, $error) = pf::web::admin::validate_guest_import($cgi, $session);
        if (!$success) {
          $logger->debug("guest import form didn't pass validation");
          pf::web::admin::generate_guestcreation_page($cgi, $session, $error, 'import');
        }
        else {
          $logger->debug("guest import form passed validation");
          
          my $file = $cgi->upload('users_file');
          if (!$file && $cgi->cgi_error) {
            $logger->error("Import: Received corrupted file: " . $cgi->cgi_error);
            pf::web::admin::generate_error_page( $cgi, $session, i18n("error: something went wrong creating the guest"));
          }
          else {
            my $filename = $cgi->param('users_file');
            my $tmpfilename = $cgi->tmpFileName($filename);
            my $delimiter = $cgi->param('delimiter');
            my $columns = $cgi->param('columns');
            $logger->info("CSV file import users from $tmpfilename ($filename, \"$delimiter\", \"$columns\")");
            ($success, $error) = pf::web::admin::import_csv($tmpfilename, $delimiter, $columns, $session);
            if ($success) {
              my ($count, $skipped) = split(',',$error);
              $logger->info("CSV file import $count users, skip $skipped users");
              $error = i18n_format("Import completed: %i guest(s) created, %i line(s) skipped.", $count, $skipped);
              
              # Tear down session information
              $session->clear([ "delimiter", "columns", "arrival_date", "access_duration" ]);
            }
            pf::web::admin::generate_guestcreation_page($cgi, $session, $error, 'import');
          }
        }
      }
    else {
      # No specific action, show guest registration page
      pf::web::admin::generate_guestcreation_page( $cgi, $session );
    }
}
else {
    # User is not logged and didn't provide username or password: show login form
    if (!($cgi->param("username") && $cgi->param("password"))) {
        pf::web::admin::generate_login_page($cgi, $session);
        exit(0);
    }

    # User provided username and password: authenticate
    my ($auth_return, $authenticator) = pf::web::admin::authenticate($cgi, $session, "guest_managers");
    if ($auth_return != 1) {
        $logger->info("authentication failed for user ".$cgi->param("username"));
        my $error;
        if (!defined($authenticator)) {
            $error = 'Unable to validate credentials at the moment';
        } else {
            $error = $authenticator->getLastError();
        }
        pf::web::admin::generate_login_page($cgi, $session, $error);
        exit(0);
    }

    # auth succeeded: redirect to guest registration page
    pf::web::admin::generate_guestcreation_page( $cgi, $session );
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2011, 2012 Inverse inc.
    
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
# vim: set autoindent:
