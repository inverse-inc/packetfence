#!/usr/bin/perl

=head1 NAME

redir.cgi - handle first hit on the captive portal

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;
use URI::Escape qw(uri_escape);

use pf::class;
use pf::config;
use pf::enforcement;
use pf::iplog;
use pf::node;
use pf::Portal::Session;
use pf::scan qw($SCAN_VID);
use pf::util;
use pf::violation;
use pf::web;
use pf::web::guest;
use pf::web::billing 1.00;
# called last to allow redefinitions
use pf::web::custom;
use pf::sms_activation;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('redir.cgi');
Log::Log4perl::MDC->put('proc', 'redir.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $portalSession = pf::Portal::Session->new();

# we need a valid MAC to identify a node
if (!valid_mac($portalSession->getClientMac())) {
  $logger->info($portalSession->getClientIp() . " not resolvable, generating error page");
  pf::web::generate_error_page($portalSession, i18n("error: not found in the database"));
  exit(0);
}

my $mac = $portalSession->getClientMac();
$logger->info("$mac being redirected");

# recording user agent for this mac in node table
# TODO: this validation will not be required if shipped CGI module is > 3.45, see bug #850
if (defined($portalSession->getCgi->user_agent)) {
  pf::web::web_node_record_user_agent($mac,$portalSession->getCgi->user_agent);
} else {
  $logger->warn("$mac has no user agent");
}

# if we are going to provide a provisionned wi-fi profile then we should not deauth the user
if (pf::web::supports_mobileconfig_provisioning($portalSession)) {
  $portalSession->getSession->param("do_not_deauth", $TRUE);
}

# check violation
#
my $violation = violation_view_top($mac);
if ($violation) {
  # There is a violation, redirect the user
  # FIXME: there is not enough validation below
  my $vid=$violation->{'vid'};
  my $class = class_view($vid);

  # detect if a system scan is in progress, if so redirect to scan in progress page
  if ($vid == $SCAN_VID && $violation->{'ticket_ref'} =~ /^Scan in progress, started at: (.*)$/) {
    $logger->info("captive portal redirect to the scan in progress page");
    pf::web::generate_scan_status_page($portalSession, $1);
    exit(0);
  }

  $logger->info("captive portal redirect on violation vid: $vid, redirect template: ".$class->{'template'});

  # The little redirect dance here is controlled by frames which are inherently alterable by the user
  # TODO: We need to validate that a user cannot request a frame with the enable button activated

  # enable button
  if ($portalSession->getCgi->param("enable_menu")) {
    $logger->debug("violation redirect: generating enable button frame (enable_menu = 1)");
    pf::web::generate_enabler_page($portalSession, $vid, $class->{'button_text'});
  } elsif ($class->{'auto_enable'} eq 'Y') {
    $logger->debug("violation redirect: showing violation remediation page inside a frame");
    pf::web::generate_redirect_page($portalSession);
  } else {
    $logger->debug("violation redirect: showing violation remediation page directly since there is no enable button");
    pf::web::generate_violation_page($portalSession, $class->{'template'});
}
  exit(0);
}

#check to see if node needs to be registered
#
my $unreg = node_unregistered($mac);
if ($unreg && isenabled($Config{'trapping'}{'registration'})){
  # Redirect to the billing engine if enabled
  if ( isenabled($portalSession->getProfile->getBillingEngine) ) {
    $logger->info("$mac redirected to billing page");
    pf::web::billing::generate_billing_page($portalSession);
    exit(0);
  }
  # Redirect to the guests self registration page if configured to do so
  elsif ( $portalSession->getProfile->guestRegistrationOnly) {
      $logger->info("$mac redirected to guests self registration page");
      pf::web::guest::generate_selfregistration_page($portalSession);
      exit(0);
  }
  elsif ($Config{'registration'}{'nbregpages'} == 0) {
    $logger->info("$mac redirected to authentication page");
    pf::web::generate_login_page($portalSession);
    exit(0);
  }
  else {
    $logger->info("$mac redirected to multi-page registration process");
    pf::web::generate_registration_page($portalSession);
    exit(0);
  }
}

#if node is pending show pending page
my $node_info = node_view($mac);
if (defined($node_info) && $node_info->{'status'} eq $pf::node::STATUS_PENDING) {
  if(pf::sms_activation::sms_activation_has_entry($mac)) {
    node_deregister($mac);
    pf::web::guest::generate_sms_confirmation_page($portalSession, "/activate/sms");
  } elsif ($portalSession->getCgi->https()) {
  # we drop HTTPS for pending so we can perform our Internet detection and avoid all sort of certificate errors
    print $portalSession->getCgi->redirect(
        "http://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
        .'/captive-portal?destination_url=' . uri_escape($portalSession->getDestinationUrl)
    );
  } else {
    pf::web::generate_pending_page($portalSession);
  }
  exit(0);
}

# NODES IN AN UKNOWN STATE
# aka you shouldn't be here but if you are we need to handle you.

# Here we are using a cache to prevent malicious or accidental DoS of the captive portal
# through too many access reevaluation requests (since this is rather expensive especially in VLAN mode)
my $cached_lost_device = $main::lost_devices_cache->get($mac);

# After 5 requests we won't perform re-eval for 5 minutes
if ( !defined($cached_lost_device) || $cached_lost_device <= 5 ) {

    # set the cache, incrementing before on purpose (otherwise it's not hitting the cache)
    $main::lost_devices_cache->set( $mac, ++$cached_lost_device, "5 minutes");

    $logger->info(
      "MAC $mac shouldn't reach here. Calling access re-evaluation. " .
      "Make sure your network device configuration is correct."
    );
    pf::enforcement::reevaluate_access( $mac, 'redir.cgi', (force => $TRUE) );
}

pf::web::generate_error_page($portalSession,
  i18n("Your network should be enabled within a minute or two. If it is not reboot your computer.")
);

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
