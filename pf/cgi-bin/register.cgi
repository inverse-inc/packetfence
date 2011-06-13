#!/usr/bin/perl

=head1 NAME

register.cgi 

=head1 SYNOPSYS

Handles captive-portal authentication, /status, de-registration, multiple registration pages workflow and viewing AUP

=cut
use CGI::Carp qw( fatalsToBrowser );
use CGI;
use CGI::Session;
use Log::Log4perl;
use strict;
use warnings;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";
# required for dynamically loaded authentication modules
use lib INSTALL_DIR . "/conf";

use pf::config;
use pf::iplog;
use pf::util;
use pf::web;
# called last to allow redefinitions
use pf::web::custom;
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
my $ip              = pf::web::get_client_ip($cgi);
my $mac             = ip2mac($ip);
my $destination_url = $cgi->param("destination_url");

$destination_url = $Config{'trapping'}{'redirecturl'} if (!$destination_url);

if (!valid_mac($mac)) {
  $logger->info("MAC not found for $ip generating Error Page");
  pf::web::generate_error_page($cgi, $session, "error: not found in the database");
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

if (defined($params{'username'}) && $params{'username'} ne '') {

  my ($auth_return,$err) = pf::web::web_user_authenticate($cgi, $session);
  if ($auth_return != 1) {
    $logger->trace("authentication failed for $mac");
    pf::web::generate_login_page($cgi, $session, $destination_url, $mac, $err);
    exit(0);
  }

  my $maxnodes = 0;
  $maxnodes = $Config{'registration'}{'maxnodes'} if (defined $Config{'registration'}{'maxnodes'});
  my $pid = $session->param("username");

  my $node_count = 0;
  $node_count = node_pid($pid) if ($pid ne '1');

  if ($pid ne '1' && $maxnodes !=0 && $node_count >= $maxnodes ) {
    $logger->info("$maxnodes are already registered to $pid");
    pf::web::generate_error_page($cgi, $session, "error: only register max nodes");
    return(0);
  }
 
  pf::web::web_node_register($cgi, $session, $mac, $pid, %info);

  my $count = violation_count($mac);

  if ($count == 0) {
    if ($Config{'network'}{'mode'} =~ /arp/i) {
      my $cmd = $bin_dir."/pfcmd manage freemac $mac";
      my $output = qx/$cmd/;
    }
    # we drop HTTPS so we can perform our Internet detection and avoid all sort of certificate errors
    if ($cgi->https()) {  
      print $cgi->redirect(
        "http://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
        ."/access?destination_url=$destination_url"
      );
    } else {
      pf::web::generate_release_page($cgi, $session, $destination_url, $mac);
    }
    exit(0);
  } else {
    print $cgi->redirect("/captive-portal?destination_url=$destination_url");
    $logger->info("more violations yet to come for $mac");
  }

# TODO this workflow is unsupported right now
} elsif (defined($params{'mode'}) && $params{'mode'} eq "next_page") {
  my $pageNb = int($params{'page'});
  if (($pageNb > 1) && ($pageNb <= $Config{'registration'}{'nbregpages'})) {
    pf::web::generate_registration_page($cgi, $session, $destination_url, $mac, $pageNb);
  } else {
    pf::web::generate_error_page($cgi, $session, "error: invalid page number");
  }
} elsif (defined($params{'mode'}) && $params{'mode'} eq "status") {
  if (trappable_ip($ip)) {
    if (defined($params{'json'})) {
      pf::web::generate_status_json($cgi, $session, $mac);
    } else {
      pf::web::generate_status_page($cgi, $session, $mac);
    }
  } else {
    pf::web::generate_error_page($cgi, $session, "error: not trappable IP");
  }
} elsif (defined($params{'mode'}) && $params{'mode'} eq "deregister") {
  my ($auth_return,$err) = pf::web::web_user_authenticate($cgi, $session);
  if ($auth_return != 1) {
    pf::web::generate_login_page($cgi, $session, $destination_url, $mac, $err);
    exit(0);
  }
  my $node_info = node_view($mac);
  my $pid = $node_info->{'pid'};
  if ($session->param("username") eq $pid) {
    #node_deregister($mac);
    #trapmac($mac);
    my $cmd = $bin_dir."/pfcmd manage deregister $mac";
    my $output = qx/$cmd/;
    $logger->info("calling $bin_dir/pfcmd  manage deregister $mac");
    print $cgi->redirect("/authenticate");
  } else {
    pf::web::generate_error_page($cgi, $session, "error: access denied not owner");
  }
} elsif (defined($params{'mode'}) && $params{'mode'} eq "release") {
  # we drop HTTPS so we can perform our Internet detection and avoid all sort of certificate errors
  if ($cgi->https()) {
    print $cgi->redirect(
      "http://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
      ."/access?destination_url=$destination_url"
    );
  } else {
    pf::web::generate_release_page($cgi, $session, $destination_url, $mac);
  }
  exit(0);
} elsif (defined($params{'mode'}) && $params{'mode'} eq "aup") {
  pf::web::generate_aup_standalone_page($cgi, $session, $mac);
  exit(0);
} elsif (defined($params{'mode'})) {
  pf::web::generate_error_page($cgi, $session, "error: incorrect mode");
} else {
  pf::web::generate_login_page($cgi, $session, $destination_url, $mac);
}

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
