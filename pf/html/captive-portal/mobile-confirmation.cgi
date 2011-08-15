#!/usr/bin/perl
=head1 NAME

mobile-confirmation.cgi 

=head1 SYNOPSYS

Handles captive-portal SMS authentication.

=cut
use strict;
use warnings;

use CGI::Carp qw( fatalsToBrowser );
use CGI;
use CGI::Session;
use Log::Log4perl;
use POSIX;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";
use lib INSTALL_DIR . "/conf";

use pf::config;
use pf::iplog;
use pf::node;
use pf::util;
use pf::violation;
use pf::web;
# called last to allow redefinitions
use pf::web::custom;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('mobile-confirmation.cgi');
Log::Log4perl::MDC->put('proc', 'mobile-confirmation.cgi');
Log::Log4perl::MDC->put('tid', 0);

my %params;
my $cgi             = new CGI;
my $session         = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});
my $ip              = $cgi->remote_addr;
my $mac             = ip2mac($ip);
my $destination_url = $cgi->param("destination_url");

$destination_url = $Config{'trapping'}{'redirecturl'} if (!$destination_url);

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


# FIXME to enforce 'harder' trapping (proper workflow) once this all work
# put code as main if () and provide a way to unset session in template
if ($cgi->param("pin")) { # && $session->param("authType")) {

    # Handling Cancel first
    if (defined($cgi->param("action")) && $cgi->param("action") eq 'Cancel') {
        $session->clear(["pin"]);
        pf::web::generate_registration_page($cgi, $session, $destination_url, $mac,1);
        return (0);
    }

    $logger->info("entering guest authentication by SMS");
    my ($auth_return,$err) = pf::web::guest::web_sms_validation($cgi, $session);
    if ($auth_return != 1) {
        # Invalid PIN -- redirect to confirmation template 
        $logger->info("Loading SMS confirmation page");
        pf::web::guest::generate_sms_confirmation_page($cgi, $session, $ENV{REQUEST_URI}, $destination_url, $err);
        return (0);
    }

    $logger->info("Valid PIN -- Registering user");
   
    my $maxnodes = 0;
    $maxnodes = $Config{'registration'}{'maxnodes'} if (defined $Config{'registration'}{'maxnodes'});
    my $pid = $session->param( "phone" );

    my $node_count = 0;
    $node_count = node_pid($pid) if ($pid ne '1');

    if ($pid ne '1' && $maxnodes !=0 && $node_count >= $maxnodes ) {
      $logger->info("$maxnodes are already registered to $pid");
      pf::web::generate_error_page($cgi, $session, "error: only register max nodes");
      return(0);
    }

    # save user info
    $info{'firstname'} = $session->param( "final_user_first_name");
    $info{'lastname'} = $session->param( "final_user_name");
    $info{'email'} = $session->param( "final_user_email");
    $info{'telephone'} = $session->param("phone");

    # Setting access timeout
    my $unregdate = localtime( time + normalize_time($pf::web::guest::DEFAULT_REGISTRATION_DURATION) );
    $info{'unregdate'} = POSIX::strftime( "%Y-%m-%d %H:%M:%S", $unregdate );

    $logger->info(
        "saving person info: firstname=" . $info{'firstname'} . ", lastname=" . $info{'lastname'} 
        . ", email=" . $info{'email'}
    );
    $info{'notes'} = 'Guest';

    $logger->info("setting unregdate to " . $info{'unregdate'});

    pf::web::web_node_register($cgi, $session, $mac, $pid, %info);
    # clear state that redirects to the Enter PIN page
    $session->clear(["phone"]);

    my $count = violation_count($mac);

    if ($count == 0) {
      if ($Config{'network'}{'mode'} =~ /arp/i) {
        my $cmd = $bin_dir."/pfcmd manage freemac $mac";
        my $output = qx/$cmd/;
      }
      pf::web::generate_release_page($cgi, $session, $destination_url, $mac);
      $logger->info("registration url = $destination_url");
    } else {
      print $cgi->redirect("/captive-portal?destination_url=$destination_url");
      $logger->info("more violations yet to come for $mac");
    }
} else {
  pf::web::generate_registration_page($cgi, $session, $destination_url, $mac,1);
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Francis Lachapelle <flachapelle@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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

