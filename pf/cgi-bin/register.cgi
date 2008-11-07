#!/usr/bin/perl

use Date::Parse;
use CGI::Carp qw( fatalsToBrowser );
use CGI;
use CGI::Session;
use Log::Log4perl;
use strict;
use warnings;

use FindBin;
use lib $FindBin::Bin . "/../lib";
use pf::config;
use pf::iplog;
use pf::util;
use pf::web;
#use pf::rawip;
use pf::node;
use pf::violation;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('register.cgi');
Log::Log4perl::MDC->put('proc', 'register.cgi');
Log::Log4perl::MDC->put('tid', 0);

my %params;
my $cgi             = new CGI;
my $session         = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});
my $ip              = $cgi->remote_addr;
my $mac             = ip2mac($ip);
my $destination_url = $cgi->param("destination_url");

$destination_url = $Config{'trapping'}{'redirecturl'} if (!$destination_url);

$logger->info("DGL: " . $FindBin::Bin);
if (!valid_mac($mac)) {
  $logger->info("MAC not found for $ip generating Error Page");
  generate_error_page($cgi, $session, "error: not found in the database");
  exit(0);
}

$logger->info("$ip - $mac ");

my %info;

# Pull username
$info{'pid'}=1;
$info{'pid'}=$cgi->remote_user if (defined $cgi->remote_user);

# Pull browser user-agent string
$info{'user_agent'}=$cgi->user_agent;

# pull parameters from query string
foreach my $param($cgi->url_param()) {
  $params{$param} = $cgi->url_param($param);
}
foreach my $param($cgi->param()) {
  $params{$param} = $cgi->param($param);
}

if (defined($params{'mode'})) {
  if ($params{'mode'} eq "register") {
    my ($auth_return,$err) = web_user_authenticate($cgi, $session);
    if ($auth_return != 1) {
      generate_login_page($cgi, $session, $ENV{REQUEST_URI}, $destination_url, $err);
      exit(0);
    }

    my $maxnodes = 0;
    $maxnodes = $Config{'registration'}{'maxnodes'} if (defined $Config{'registration'}{'maxnodes'});
    my $pid = $session->param("login");

    my $node_count = node_pid($pid) if ($pid ne '1');

    if ($pid ne '1' && $maxnodes !=0 && $node_count >= $maxnodes ) {
      $logger->info("$maxnodes are already registered to $pid");
      generate_error_page($cgi, $session, "error: only register max nodes");
      return(0);
    }
   
    #determine default VLAN if VLAN isolation is enabled
    #and the vlan has not been set yet 
    if ($Config{'network'}{'mode'} =~ /vlan/i) {
      if (! defined($info{'vlan'})) {
         my %ConfigVlan;
         tie %ConfigVlan, 'Config::IniFiles', (-file => "$conf_dir/switches.conf");
         $info{'vlan'}=$ConfigVlan{'default'}{'normalVlan'};                    
      }
    }

    #node_register($mac, $pid, %info);
    web_node_register($mac, $pid, %info);

    my $count = violation_count($mac);

    if ($count == 0) {
      if ($Config{'network'}{'mode'} =~ /arp/i) {
        my $cmd = $bin_dir."/pfcmd manage freemac $mac";
        my $output = qx/$cmd/;
      }
      generate_release_page($cgi, $session, $destination_url);
      $logger->info("registration url = $destination_url");
    } else {
      print $cgi->redirect("/cgi-bin/redir.cgi?destination_url=$destination_url");
      $logger->info("more violations yet to come for $mac");
    }

  } elsif ($params{'mode'} eq "next_page") {
    my $pageNb = int($params{'page'});
    if (($pageNb > 1) && ($pageNb <= $Config{'registration'}{'nbregpages'})) {
      generate_registration_page($cgi, $session, $destination_url, $mac,$pageNb);
    } else {
      generate_error_page($cgi, $session, "error: invalid page number");
    }
  } elsif ($params{'mode'} eq "status") {
    if (trappable_ip($ip)) {
      generate_status_page($cgi, $session, $mac);
    } else {
      generate_error_page($cgi, $session, "error: not trappable IP");
    }
  } elsif ($params{'mode'} eq "deregister") {
    my ($auth_return,$err) = web_user_authenticate($cgi, $session);
    if ($auth_return != 1) {
      generate_login_page($cgi, $session, $ENV{REQUEST_URI},$destination_url,$err);
      exit(0);
    }
    my $node_info = node_view($mac);
    my $pid = $node_info->{'pid'};
    if ($session->param("login") eq $pid) {
      #node_deregister($mac);
      #trapmac($mac);
      my $cmd = $bin_dir."/pfcmd manage deregister $mac";
      my $output = qx/$cmd/;
      $logger->info("calling $bin_dir/pfcmd  manage deregister $mac");
      print $cgi->redirect("/cgi-bin/register.cgi");
    } else {
      generate_error_page($cgi, $session, "error: access denied not owner");
    }
  }  else {
    generate_error_page($cgi, $session, "error: incorrect mode");
  }
} else {
  generate_registration_page($cgi, $session, $destination_url, $mac,1);
}
