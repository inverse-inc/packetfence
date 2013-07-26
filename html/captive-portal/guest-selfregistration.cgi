#!/usr/bin/perl

=head1 NAME

guest-selfregistration.cgi - guest self registration portal

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

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
use pf::Portal::Session;
use pf::util;
use pf::violation;
use pf::web;
use pf::web::guest 1.30;
# called last to allow redefinitions
use pf::web::custom;

use pf::authentication;
use pf::Authentication::constants;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('guest-selfregistration.cgi');
Log::Log4perl::MDC->put('proc', 'guest-selfregistration.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $portalSession = pf::Portal::Session->new();
my $cgi = $portalSession->getCgi();
my $session = $portalSession->getSession();

# if self registration is not enabled, redirect to portal entrance
print $cgi->redirect("/captive-portal?destination_url=".uri_escape($portalSession->getDestinationUrl()))
    if ( isdisabled($portalSession->getProfile->getGuestSelfReg) );

# if we can resolve the MAC we are in on-site self-registration
# if we can't resolve it and preregistration is disabled, generate an error
my $is_valid_mac = valid_mac($portalSession->getClientMac());
if ( !$is_valid_mac && isdisabled($Config{'guests_self_registration'}{'preregistration'}) ) {
    $logger->info($portalSession->getClientIp() . " not resolvable, generating error page");
    pf::web::generate_error_page($portalSession, i18n("error: not found in the database"));
    exit(0);
}
# we can't resolve the MAC and preregistration is enabled: pre-registration
elsif ( !$is_valid_mac ) {
    $session->param("preregistration", $TRUE);
}
# forced pre-registration overrides anything previously set (or not set)
if (defined($cgi->url_param("preregistration")) && $cgi->url_param("preregistration") eq 'forced') {
    $session->param("preregistration", $TRUE);
}

# Clearing the MAC if in pre-registration
# Warning: this assumption is important for preregistration
if ($session->param("preregistration")) {
    $portalSession->setGuestNodeMac(undef);
}
# Assigning MAC as guest MAC
# FIXME quick and hackish fix for #1505. A proper, more intrusive, API changing, fix should hit devel.
else {
    $portalSession->setGuestNodeMac($portalSession->getClientMac());
}

if (defined($cgi->url_param('mode')) && $cgi->url_param('mode') eq $pf::web::guest::GUEST_REGISTRATION) {

    my %info;

    # is form valid?
    my ($auth_return, $err, $errargs_ref) = pf::web::guest::validate_selfregistration($portalSession);

    #
    # Email
    #
    if ( $auth_return && defined($cgi->param('by_email'))
         && is_in_list($SELFREG_MODE_EMAIL, $portalSession->getProfile->getGuestModes) ) {

      # User chose to register by email
      $logger->info( "registering " . ( $session->param("preregistration") ? 'a remote' : $portalSession->getClientMac() ) . " guest by email" );

      my $pid = $session->param('guest_pid');
      my $email = $session->param("email");
      $info{'pid'} = $pid;

      # fetch role for this user
      my $email_type = pf::Authentication::Source::EmailSource->meta->get_attribute('type')->default;
      my $source_id = $portalSession->getProfile()->getSourceByType($email_type);
      my $auth_params =
        {
         'username' => $pid,
         'user_email' => $email
        };
      $info{'category'} = &pf::authentication::match($source_id, $auth_params, $Actions::SET_ROLE);

      # form valid, adding person (using modify in case person already exists)
      person_modify($pid, (
          'firstname'   => $session->param("firstname"),
          'lastname'    => $session->param("lastname"),
          'company'     => $session->param('company'),
          'email'       => $email,
          'telephone'   => $session->param("phone"),
          'notes'       => 'email activation. Date of arrival: ' . time2str("%Y-%m-%d %H:%M:%S", time),
      ));

      # if we are on-site: register the node
      if (!$session->param("preregistration")) {
          # Use the activation timeout to set the unregistration date
          my $source = &pf::authentication::getAuthenticationSource($source_id);
          my $timeout = normalize_time($source->{email_activation_timeout});
          $info{'unregdate'} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime( time + $timeout ));
          $logger->debug("Registration for guest ".$pid." is valid until ".$info{'unregdate'});

          pf::web::web_node_register($portalSession, $pid, %info);
      }

      # add more info for the activation email
      %info = pf::web::guest::prepare_email_guest_activation_info($portalSession, %info);

      # TODO this portion of the code should be throttled to prevent malicious intents (spamming)
      ($auth_return, $err, $errargs_ref) = pf::email_activation::create_and_email_activation_code(
          $portalSession->getGuestNodeMac(), $pid, $email,
          ( $session->param("preregistration")
              ? $pf::web::guest::TEMPLATE_EMAIL_EMAIL_PREREGISTRATION
              : $pf::web::guest::TEMPLATE_EMAIL_GUEST_ACTIVATION
          ),
          $pf::email_activation::GUEST_ACTIVATION,
          %info
      );

      if (!$session->param("preregistration")) {
          # does the necessary captive portal escape sequence (violations, provisionning, etc.)
          pf::web::end_portal_session($portalSession) if ($auth_return);
      }
      # pregistration: we show a confirmation page
      else {
          # send to a success page
          pf::web::generate_generic_page(
              $portalSession, $pf::web::guest::PREREGISTRATION_CONFIRMED_TEMPLATE, { 'mode' => $SELFREG_MODE_EMAIL }
          );
      }
    } # Email

    #
    # SMS
    #
    elsif ( $auth_return && defined($cgi->param('by_sms'))
            && is_in_list($SELFREG_MODE_SMS, $portalSession->getProfile->getGuestModes) ) {

      if ($session->param("preregistration")) {
          pf::web::generate_error_page($portalSession, i18n("Registration in advance by SMS is not supported."));
          exit(0);
      }

      # User chose to register by SMS
      $logger->info("registering " . $portalSession->getClientMac() . " guest by SMS " . $session->param("phone") . " @ " . $cgi->param("mobileprovider"));
      ($auth_return, $err, $errargs_ref) = sms_activation_create_send( $portalSession->getGuestNodeMac(),
                                                                       $session->param("phone"),
                                                                       $cgi->param("mobileprovider") );
      if ($auth_return) {

          my $pid = $session->param('guest_pid');
          my $phone = $session->param("phone");
          $info{'pid'} = $pid;

          # form valid, adding person (using modify in case person already exists)
          $logger->info("Adding guest person " . $session->param('guest_pid') . "(" . $session->param("phone") . ")");
          person_modify($pid, (
              'firstname' => $session->param("firstname"),
              'lastname' => $session->param("lastname"),
              'company' => $session->param('company'),
              'email' => $session->param("email"),
              'telephone' => $phone,
              'notes' => 'sms confirmation. Date of arrival: ' . time2str("%Y-%m-%d %H:%M:%S", time),
          ));

          $logger->info("redirecting to mobile confirmation page");

          # fetch role for this user
          my $sms_type = pf::Authentication::Source::SMSSource->meta->get_attribute('type')->default;
          my $source_id = $portalSession->getProfile->getSourceByType($sms_type);
          my $auth_params =
            {
             'username' => $pid,
             'phonenumber' => $phone
            };
          $info{'category'} = &pf::authentication::match($source_id, $auth_params, $Actions::SET_ROLE);

          # set node in pending mode with the appropriate role
          $info{'status'} = $pf::node::STATUS_PENDING;
          node_modify($portalSession->getClientMac(), %info);

          # show form for PIN number
          pf::web::guest::generate_sms_confirmation_page($portalSession, "/activate/sms", $err, $errargs_ref);
          exit(0);
      }
    } # SMS

    #
    # Sponsor
    #
    elsif ( $auth_return && defined($cgi->param('by_sponsor'))
            && is_in_list($SELFREG_MODE_SPONSOR, $portalSession->getProfile->getGuestModes) ) {
      # User chose to register through a sponsor
      $logger->info("registering " . ( $session->param("preregistration") ? 'a remote' : $portalSession->getClientMac() ) . " guest through a sponsor");

      my $pid = $session->param('guest_pid');
      my $email = $session->param("email");
      $info{'pid'} = $pid;

      # form valid, adding person (using modify in case person already exists)
      person_modify($pid, (
          'firstname' => $session->param("firstname"),
          'lastname' => $session->param("lastname"),
          'company' => $session->param('company'),
          'email' => $email,
          'telephone' => $session->param("phone"),
          'sponsor' => $session->param("sponsor"),
          'notes' => 'sponsored guest. Date of arrival: ' . time2str("%Y-%m-%d %H:%M:%S", time)
      ));
      $logger->info("Adding guest person " . $session->param('guest_pid'));

      my $sponsor_type = pf::Authentication::Source::SponsorEmailSource->meta->get_attribute('type')->default;
      my $source_id = $portalSession->getProfile->getSourceByType($sponsor_type);
      my $auth_params =
        {
         'username' => $pid,
         'user_email' => $email
        };

      # fetch role for this user
      $info{'category'} = &pf::authentication::match($source_id, $auth_params, $Actions::SET_ROLE);

      # Setting access timeout and role (category) dynamically
      $info{'unregdate'} = &pf::authentication::match($source_id, $auth_params, $Actions::SET_ACCESS_DURATION);

      if (defined $info{'unregdate'}) {
          $info{'unregdate'} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + normalize_time($info{'unregdate'})));
      }
      else {
          $info{'unregdate'} = &pf::authentication::match($source_id, $auth_params, $Actions::SET_UNREG_DATE);
      }

      # set node in pending mode
      $info{'status'} = $pf::node::STATUS_PENDING;

      if (!$session->param("preregistration")) {
          # modify the node
          node_modify($portalSession->getClientMac(), %info);
      }

      $info{'cc'} = $Config{'guests_self_registration'}{'sponsorship_cc'};
      # fetch more info for the activation email
      # this is meant to be overridden in pf::web::custom with customer specific needs
      %info = pf::web::guest::prepare_sponsor_guest_activation_info($portalSession, %info);

      # TODO this portion of the code should be throttled to prevent malicious intents (spamming)
      ($auth_return, $err, $errargs_ref) = pf::email_activation::create_and_email_activation_code(
          $portalSession->getGuestNodeMac(), $pid, $info{'sponsor'},
          $pf::web::guest::TEMPLATE_EMAIL_SPONSOR_ACTIVATION,
          $pf::email_activation::SPONSOR_ACTIVATION,
          %info
      );

      # on-site: redirection will show pending page (unless there's a violation for the node)
      if (!$session->param("preregistration")) {
          print $cgi->redirect('/captive-portal?destination_url=' . uri_escape($portalSession->getDestinationUrl()));
          exit(0);
      }
      # pregistration: we show a confirmation page
      else {
          # send to a success page
          pf::web::generate_generic_page(
              $portalSession, $pf::web::guest::PREREGISTRATION_CONFIRMED_TEMPLATE, { 'mode' => $SELFREG_MODE_SPONSOR }
          );
      }
    } # SPONSOR

    # Registration form was invalid, return to guest self-registration page and show error message
    if ($auth_return != $TRUE) {
        $logger->info("Missing information for self-registration");
        pf::web::guest::generate_selfregistration_page($portalSession, $err, $errargs_ref);
        exit(0);
    }
}
else {
    # wipe web fields
    $cgi->delete('firstname', 'lastname', 'email', 'phone', 'organization');

    # by default, show guest registration page
    pf::web::guest::generate_selfregistration_page($portalSession);
}

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
