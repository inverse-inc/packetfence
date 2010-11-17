#!/usr/bin/perl

=head1 NAME

release.cgi - Handles releasing nodes out of the captive portal

=cut
use strict;
use warnings;

use Date::Parse;
use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";
use pf::config;
use pf::iplog;
use pf::util;
use pf::web;
# called last to allow redefinitions
use pf::web::custom;
#use pf::rawip;
use pf::node;
use pf::class;
use pf::violation;
use pf::trigger;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('release.cgi');
Log::Log4perl::MDC->put('proc', 'release.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

my $ip              = $cgi->remote_addr();
my $destination_url = $cgi->param("destination_url");
my $mac             = ip2mac($ip);

$destination_url = $Config{'trapping'}{'redirecturl'} if (!$destination_url);

if (!valid_mac($mac)) {
  $logger->info("$ip not resolvable, generating error page");
  pf::web::generate_error_page($cgi, $session, "error: not found in the database");
  return(0);     
}

# release on skip registration
#
if (defined($cgi->param('mode'))) {
  # TODO: Validate that this mode = skip can't be tricked client side to create adverse effects
  if ($cgi->param('mode') eq "skip") {

    my $node_info = node_view($mac);
    my $detect_date = str2time($node_info->{'detect_date'});
    if (!isdisabled($Config{'registration'}{'skip_mode'})) {
      if (($Config{'registration'}{'skip_mode'} eq "deadline" && (time - $Config{'registration'}{'skip_deadline'} < 0)) ||
          ($Config{'registration'}{'skip_mode'} eq "window" && $detect_date + $Config{'registration'}{'skip_window'} < time)) {
        $logger->info("test: detect_date=$detect_date window=".$Config{'registration'}{'skip_window'}." time=".time);
        $logger->info("registration grace period exceeded for $mac!");
        print $cgi->redirect("/cgi-bin/register.cgi?mode=register&destination_url=".$destination_url);
      } else {
        my %info;
        $info{'status'}='grace';
        $info{'lastskip'}=mysql_date();
        $info{'user_agent'}=$cgi->user_agent();
        node_modify($mac,%info);

        my $count = violation_count($mac);
        if ($count == 0) {
          if ($Config{'network'}{'mode'} =~ /arp/i) {
            my $cmd = $bin_dir."/pfcmd manage freemac $mac";
            my $output = qx/$cmd/;
          }
          pf::web::generate_release_page($cgi, $session, $destination_url);
        } else {
          print $cgi->redirect("/cgi-bin/redir.cgi?destination_url=$destination_url");
        }
        $logger->info("$mac skipped registration");
      }
    }
    exit;
  }
}

my $violations = violation_view_top($mac); 
# is violations valid
if (!defined($violations) || ref($violations) ne 'HASH' || !defined($violations->{'vid'})) {

  # not valid, we should not be here then, lets tell the user to re-open his browser
  pf::web::generate_error_page($cgi, $session, "release: reopen browser");
  return(0);
}

my $vid = $violations->{'vid'}; 

# is class valid? if so, let's grab some related info that we will need
my ($class_violation_url, $class_redirect_url, $class_max_enable_url);
my $class=class_view($vid);
if (defined($class) && ref($class) eq 'HASH') { 

  $class_violation_url = $class->{'url'} if defined($class->{'url'});
  $class_redirect_url = $class->{'redirect_url'} if defined($class->{'redirect_url'});
  $class_max_enable_url = $class->{'max_enable_url'} if defined($class->{'max_enable_url'});
}

#scan code...
if ($vid==1200001){

  # detect if a system scan is in progress, if so redirect to scan in progress page
  # this should only happen if the user explicitly put release.cgi in his browser address
  if ($violations->{'ticket_ref'} =~ /^Scan in progress, started at: (.*)$/) {
    $logger->info("captive portal redirect to the scan in progress page");
    pf::web::generate_scan_status_page($cgi, $session, $1, $destination_url);
    exit(0);
  }

  my $cmd = $bin_dir."/pfcmd schedule now $ip 1>/dev/null 2>&1";
  $logger->info("scanning $ip by calling $cmd");

  # forking to avoid browser to hang on connection
  if (my $pid = fork) {

    $logger->trace("parent part, redirecting to scan started page");
    pf::web::generate_scan_start_page($cgi, $session, $destination_url);
    exit(0);

  } elsif (defined $pid) {

    # HACK: add a start date in the violation's ticket_ref to track the fact that the scan is in progress
    my $currentScanViolationId = $violations->{'id'};
    violation_modify($currentScanViolationId, (ticket_ref => "Scan in progress, started at: ".mysql_date()));

    # requesting the scan
    $logger->trace("child part, forking $cmd");
    my $scan = qx/$cmd/;
    exit(0);

  } else {
    # unexpected error
    $logger->logdie("Cannot fork: $!");
  }
}

my $cmd = $bin_dir."/pfcmd manage vclose $mac $vid";
$logger->info("calling $bin_dir/pfcmd manage vclose $mac $vid");
my $grace = qx/$cmd/;
$grace=~s/^.+\n\n//;
#my $grace = violation_close($mac,$vid);
$logger->info("pfcmd manage vclose $mac $vid returned $grace");

if ($grace != -1) {
  my $count = violation_count($mac); 

  if ($count == 0) {
    if ($Config{'network'}{'mode'} =~ /arp/i && $count == 0) {
      my $cmd = $bin_dir."/pfcmd manage freemac $mac";
      my $output = qx/$cmd/;
    }
    if ($class_redirect_url) {
      pf::web::generate_release_page($cgi, $session, $class_redirect_url);
    } else {
      pf::web::generate_release_page($cgi, $session, $destination_url);
    }
  } else {
    if ($class_redirect_url) {
      print $cgi->redirect("/cgi-bin/redir.cgi?destination_url=$class_redirect_url");
    } else {
      print $cgi->redirect("/cgi-bin/redir.cgi?destination_url=$destination_url");
    }
  }
  $logger->info("$mac enabled for $grace minutes");
} else {
  $logger->info("$mac reached maximum violations");
  if ($class_max_enable_url) {
    print $cgi->redirect($class_max_enable_url);
  } else {
    pf::web::generate_error_page($cgi, $session, "error: max re-enables reached");
  }
}

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2008-2010 Inverse inc.

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
