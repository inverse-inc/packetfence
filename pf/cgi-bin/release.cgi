#!/usr/bin/perl

use strict;
use warnings;

use Date::Parse;
use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;

use FindBin;
use lib $FindBin::Bin . "/../lib";
use pf::config;
use pf::iplog;
use pf::util;
use pf::web;
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
  generate_error_page($cgi, $session, "error: not found in the database");
  return(0);     
}

# release on skip registration
#
if (defined($cgi->param('mode'))) {
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
          generate_release_page($cgi, $session, $destination_url);
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
my $vid = $violations->{'vid'}; 
my $class=class_view($vid);

my $class_violation_url = $class->{'url'};
my $class_redirect_url = $class->{'redirect_url'};
my $class_max_enable_url = $class->{'max_enable_url'};

#scan code...
if ($vid==1200001){
  my $cmd = $bin_dir."/pfcmd schedule now $ip";
  $logger->info("scanning $ip by calling $cmd");
  my $scan = qx/$cmd/;
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
      generate_release_page($cgi, $session, $class_redirect_url);
    } else {
      generate_release_page($cgi, $session, $destination_url);
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
  if ($class->{'max_enable_url'}) {
    print $cgi->redirect($class_max_enable_url);
  } else {
    generate_error_page($cgi, $session, "error: max re-enables reached");
  }
}
