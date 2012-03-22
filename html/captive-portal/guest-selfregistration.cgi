#!/usr/bin/perl
=head1 NAME

guest-selfregistration.cgi - guest self registration portal

=cut
use strict;
use warnings;

use lib '/usr/local/pf/lib';

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Date::Format qw(time2str);
use Log::Log4perl;
use Readonly;
use POSIX;
use URI::Escape qw(uri_escape);

use pf::config;
use pf::email_activation;
use pf::sms_activation;
use pf::iplog;
use pf::node;
use pf::person qw(person_modify);
use pf::util;
use pf::violation;
use pf::web;
use pf::web::guest 1.20;
# called last to allow redefinitions
use pf::web::custom;

# constants
Readonly::Scalar my $GUEST_REGISTRATION => "guest-register";

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('guest-selfregistration.cgi');
Log::Log4perl::MDC->put('proc', 'guest-selfregistration.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $cgi = new CGI;
$cgi->charset("UTF-8");
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

my $ip = $cgi->remote_addr();
my $destination_url = pf::web::get_destination_url($cgi);
my %info;

# if self registration is not enabled, redirect to portal entrance
print $cgi->redirect("/captive-portal?destination_url=".uri_escape($destination_url))
    if (isdisabled($Config{'registration'}{'guests_self_registration'}));

# we need a valid MAC to identify a node
# TODO this is duplicated too much, it should be brought up in a global dispatcher
my $mac = ip2mac($ip);
if (!valid_mac($mac)) {
  $logger->info("$ip not resolvable, generating error page");
  pf::web::generate_error_page($cgi, $session, "error: not found in the database");
  exit(0);
}

# Correct POST
if (defined($cgi->url_param('mode')) && $cgi->url_param('mode') eq $GUEST_REGISTRATION) {

    # is form valid?
    my ($auth_return, $err, $errargs_ref) = pf::web::guest::validate_selfregistration($cgi, $session);

    # Email
    if ($auth_return && defined($cgi->param('by_email')) && defined($guest_self_registration{$SELFREG_MODE_EMAIL})) {
      # User chose to register by email
      $logger->info("registering $mac guest by email");

      # form valid, adding person (using modify in case person already exists)
      person_modify($session->param('guest_pid'), (
          'firstname' => $session->param("firstname"),
          'lastname' => $session->param("lastname"),
          'company' => $session->param('company'),
          'email' => $session->param("email"),
          'telephone' => $session->param("phone"),
          'notes' => 'email activation. Date of arrival: ' . time2str("%Y-%m-%d %H:%M:%S", time),
      ));
      $logger->info("Adding guest person " . $session->param('guest_pid'));

      # grab additional info about the node
      $info{'pid'} = $session->param('guest_pid');
      $info{'category'} = $Config{'guests_self_registration'}{'category'};

      # unreg in guests.email_activation_timeout seconds
      my $timeout = $Config{'guests_self_registration'}{'email_activation_timeout'};
      $info{'unregdate'} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime( time + $timeout ));

      # register the node
      pf::web::web_node_register($cgi, $session, $mac, $info{'pid'}, %info);

      # add more info for the activation email
      %info = pf::web::guest::prepare_email_guest_activation_info($cgi, $session, $mac, %info);
      
      # TODO this portion of the code should be throttled to prevent malicious intents (spamming)
      ($auth_return, $err, $errargs_ref) = pf::email_activation::create_and_email_activation_code(
          $mac, $info{'pid'}, $info{'pid'}, $pf::web::guest::TEMPLATE_EMAIL_GUEST_ACTIVATION, %info
      );

      # does the necessary captive portal escape sequence (violations, provisionning, etc.)
      pf::web::end_portal_session($cgi, $session, $mac, $destination_url) if ($auth_return);
    }

    # SMS
    elsif ( $auth_return && defined($cgi->param('by_sms')) && defined($guest_self_registration{$SELFREG_MODE_SMS}) ) {
      # User chose to register by SMS
      $logger->info("registering $mac guest by SMS " . $session->param("phone") . " @ " . $cgi->param("mobileprovider"));
      ($auth_return, $err, $errargs_ref) = sms_activation_create_send($mac, $session->param("phone"), $cgi->param("mobileprovider") );
      if ($auth_return) {

          # form valid, adding person (using modify in case person already exists)
          $logger->info("Adding guest person " . $session->param('guest_pid') . "(" . $session->param("phone") . ")");
          person_modify($session->param('guest_pid'), (
              'firstname' => $session->param("firstname"),
              'lastname' => $session->param("lastname"),
              'company' => $session->param('company'),
              'email' => $session->param("email"),
              'telephone' => $session->param("phone"),
              'notes' => 'sms confirmation. Date of arrival: ' . time2str("%Y-%m-%d %H:%M:%S", time),
          ));

          $logger->info("redirecting to mobile confirmation page");
          pf::web::guest::generate_sms_confirmation_page($cgi, $session, "/activate/sms", $destination_url, $err, $errargs_ref);
          exit(0);
      }
    }

    # Registration form was invalid, return to guest self-registration page and show error message
    if ($auth_return != $TRUE) {
        $logger->info("Missing information for self-registration");
        pf::web::guest::generate_selfregistration_page(
            $cgi, $session, "/signup?mode=$GUEST_REGISTRATION", $destination_url, $mac, $err, $errargs_ref
        );
        exit(0);
    }
}
else {
    # wipe web fields
    $cgi->delete('firstname', 'lastname', 'email', 'phone', 'organization');

    # by default, show guest registration page
    pf::web::guest::generate_selfregistration_page(
        $cgi, $session, "/signup?mode=$GUEST_REGISTRATION", $destination_url, $mac
    );
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT
        
Copyright (C) 2010-2012 Inverse inc.
    
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

