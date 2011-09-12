#!/usr/bin/perl

=head1 NAME

redir.cgi - handle first hit on the captive portal

=cut
#use Data::Dumper;
use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;

use pf::class;
use pf::config;
use pf::enforcement;
use pf::iplog;
use pf::node;
use pf::scan qw($SCAN_VID);
use pf::util;
use pf::violation;
use pf::web;
# called last to allow redefinitions
use pf::web::custom;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('redir.cgi');
Log::Log4perl::MDC->put('proc', 'redir.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

my $result;
my $ip              = pf::web::get_client_ip($cgi);
my $destination_url = $cgi->param("destination_url") || $Config{'trapping'}{'redirecturl'};
my $enable_menu     = $cgi->param("enable_menu");
my $mac             = ip2mac($ip);
my %tags;

# valid mac?
if (!valid_mac($mac)) {
  $logger->info("$ip not resolvable, generating error page");
  pf::web::generate_error_page($cgi, $session, "error: not found in the database");
  exit(0);
}
$logger->info("$mac being redirected");

# recording user agent for this mac in node table
# TODO: this validation will not be required if shipped CGI module is > 3.45, see bug #850
if (defined($cgi->user_agent)) {
  pf::web::web_node_record_user_agent($mac,$cgi->user_agent);
} else {
  $logger->warn("$mac has no user agent");
}

# check violation 
#
my $violation = violation_view_top($mac);
if ($violation){
  # There is a violation, redirect the user
  # FIXME: there is not enough validation below
  my $vid=$violation->{'vid'};
  my $class=class_view($vid);

  # detect if a system scan is in progress, if so redirect to scan in progress page
  if ($vid == $SCAN_VID && $violation->{'ticket_ref'} =~ /^Scan in progress, started at: (.*)$/) {
    $logger->info("captive portal redirect to the scan in progress page");
    pf::web::generate_scan_status_page($cgi, $session, $1, $destination_url);
    exit(0);
  }

  $logger->info("captive portal redirect on violation vid: $vid, redirect url: ".$class->{'url'});

  # The little redirect dance here is controlled by frames which are inherently alterable by the user
  # TODO: We need to validate that a user cannot request a frame with the enable button activated

  # enable button
  if ($enable_menu) {
    $logger->debug("violation redirect: generating enable button frame (enable_menu = 1)");
    pf::web::generate_enabler_page($cgi, $session, $destination_url, $vid, $class->{'button_text'});
  } elsif  ($class->{'auto_enable'} eq 'Y'){
    $logger->debug("violation redirect: generating redirect frame");
    pf::web::generate_redirect_page($cgi, $session, $class->{'url'}, $destination_url);
  } else {
    $logger->debug("violation redirect: showing violation url directly since there is no enable button");
    print $cgi->redirect($class->{'url'});
  }
  exit(0);
}

#check to see if node needs to be registered
#
my $unreg = node_unregistered($mac);
if ($unreg && isenabled($Config{'trapping'}{'registration'})){
  if ($Config{'registration'}{'nbregpages'} == 0) {
    $logger->info("$mac redirected to authentication page");
    pf::web::generate_login_page($cgi, $session, $destination_url, $mac);
    exit(0);
  } else {
    $logger->info("$mac redirected to multi-page registration process");
    pf::web::generate_registration_page($cgi, $session, $destination_url, $mac);
    exit(0);
  }
}

#if node is pending show pending page
my $node_info = node_view($mac);
if (defined($node_info) && $node_info->{'status'} eq $pf::node::STATUS_PENDING) {
  # we drop HTTPS for pending so we can perform our Internet detection and avoid all sort of certificate errors
  if ($cgi->https()) {
    print $cgi->redirect(
        "http://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
        ."/captive-portal?destination_url=$destination_url"
    );
  } else {
    pf::web::generate_pending_page($cgi, $session, $destination_url, $mac);
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
      "MAC $mac shouldn't reach here. " .
      "Calling access re-evaluation through flip.pl. " .
      "Make sure your network device configuration is correct."
    );
    pf::enforcement::reevaluate_access( $mac, 'redir.cgi', (force => $TRUE) );
}

pf::web::generate_error_page($cgi, $session, 
  "Your network should be enabled within a minute or two. If it is not reboot your computer."
);

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2008-2011 Inverse inc.
    
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
