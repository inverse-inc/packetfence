#!/usr/bin/perl
#use Data::Dumper;
use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;

use constant INSTALL_DIR => '/usr/local/pf';
use constant SCAN_VID => 1200001;
use lib INSTALL_DIR . "/lib";

use pf::config;
use pf::iplog;
use pf::util;
use pf::web;
# not SUID now!
#use pf::rawip;
use pf::node;
use pf::class;
use pf::violation;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('redir.cgi');
Log::Log4perl::MDC->put('proc', 'redir.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

my $result;
my $ip              = $cgi->remote_addr();
my $destination_url = $cgi->param("destination_url");
my $enable_menu     = $cgi->param("enable_menu");
my $mac             = ip2mac($ip);
my %tags;

# valid mac?
if (!valid_mac($mac)) {
  $logger->info("$ip not resolvable, generating error page");
  generate_error_page($cgi, $session, "error: not found in the database");
  exit(0);
}
$logger->info("$mac being redirected");

# recording user agent for this mac in node table
web_node_record_user_agent($mac,$cgi->user_agent);

# registration auth request?
if (defined($cgi->param('mode')) && $cgi->param('auth')) {
 my $type=$cgi->param('auth');
 if ($type eq "skip"){
    $logger->info("User is trying to skip redirecting to release.cgi");
    print $cgi->redirect("/cgi-bin/release.cgi?mode=skip&destination_url=$destination_url");    
  }else{
    $logger->info("redirecting to register-$type.cgi for reg authentication");
    print $cgi->redirect("/cgi-bin/register-$type.cgi?mode=register&destination_url=$destination_url");
  }
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
  if ($vid == SCAN_VID && $violation->{'ticket_ref'} =~ /^Scan in progress, started at: (.*)$/) {
    $logger->info("captive portal redirect to the scan in progress page");
    generate_scan_status_page($cgi, $session, $1, $destination_url);
    exit(0);
  }

  $logger->info("captive portal redirect on violation vid: $vid, redirect url: ".$class->{'url'});

  # The little redirect dance here is controlled by frames which are inherently alterable by the user
  # TODO: We need to validate that a user cannot request a frame with the enable button activated

  # enable button
  if ($enable_menu) {
    $logger->debug("violation redirect: generating enable button frame (enable_menu = 1)");
    generate_enabler_page($cgi, $session, $destination_url, $vid, $class->{'button_text'});
  } elsif  ($class->{'auto_enable'} eq 'Y'){
    $logger->debug("violation redirect: generating redirect frame");
    generate_redirect_page($cgi, $session, $class->{'url'}, $destination_url);
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
  $logger->info("$mac redirected to registration page");
  generate_registration_page($cgi, $session, $destination_url,$mac,1);
  exit(0);
}

# 
$logger->info("$mac already registered or registration disabled, freeing mac");
if ($Config{'network'}{'mode'} =~ /arp/i) {
  $logger->info("$mac already registered or registration disabled, freeing mac");
  my $cmd = $bin_dir."/pfcmd manage freemac $mac";
  my $output = qx/$cmd/;
  $logger->info("freed $mac");
}
#TODO: I think the below here is what's causing redirect loops, need to confirm first then fix
$logger->info("redirecting to ".$Config{'trapping'}{'redirecturl'});
print $cgi->redirect($Config{'trapping'}{'redirecturl'});

