#!/usr/bin/perl

=head1 NAME

register.cgi 

=head1 SYNOPSYS

Handles captive-portal authentication, /status, de-registration, multiple registration pages workflow and viewing AUP

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

use Log::Log4perl;
use URI::Escape qw(uri_escape);

use pf::config;
use pf::iplog;
use pf::locationlog;
use pf::node;
use pf::nodecategory;
use pf::Portal::Session;
use pf::util;
use pf::violation;
use pf::web;
use pf::web::custom; # called last to allow redefinitions

use pf::authentication;
use pf::Authentication::constants;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('register.cgi');
Log::Log4perl::MDC->put('proc', 'register.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $portalSession = pf::Portal::Session->new();
my $cgi = $portalSession->getCgi();
my $mac = $portalSession->getClientMac();

# we need a valid MAC to identify a node
if ( !valid_mac($mac) ) {
  $logger->info($portalSession->getClientIp() . " not resolvable, generating error page");
  pf::web::generate_error_page($portalSession, i18n("error: not found in the database"));
  exit(0);
}

$logger->info($portalSession->getClientIp() . " - " . $portalSession->getClientMac() . " on registration page");

my %info;

# Pull username
$info{'pid'} = $cgi->remote_user || "admin";

# Pull browser user-agent string
$info{'user_agent'} = $cgi->user_agent;

if (defined($cgi->param('username')) && $cgi->param('username') ne '') {
  
  my ($form_return, $err) = pf::web::validate_form($portalSession);
  if ($form_return != 1) {
    $logger->trace("form validation failed or first time for " . $portalSession->getClientMac());
    pf::web::generate_login_page($portalSession, $err);
    exit(0);
  }

  my ($auth_return, $error) = pf::web::web_user_authenticate($portalSession);
  if ($auth_return != 1) {
    $logger->trace("authentication failed for " . $portalSession->getClientMac());
    pf::web::generate_login_page($portalSession, $error);
    exit(0);
  }

  my $pid = $portalSession->getSession->param("username");
  my $params = { username => $pid };
  # TODO : add current_time and computer_name
  my $locationlog_entry = locationlog_view_open_mac($mac);
  if ($locationlog_entry) {
      $params->{connection_type} = $locationlog_entry->{'connection_type'};
      $params->{SSID} = $locationlog_entry->{'ssid'};
  }

  # obtain node information provided by authentication module. We need to get the role (category here)
  # as web_node_register() might not work if we've reached the limit
  my $value = &pf::authentication::match(undef, $params, $Actions::SET_ROLE);

  $logger->trace("Got role '$value' for username $pid");

  # This appends the hashes to one another. values returned by authenticator wins on key collision
  if (defined $value) {
      %info = (%info, (category => $value));
  }

  # If an access duration is defined, use it to compute the unregistration date;
  # otherwise, use the unregdate when defined.
  $value = &pf::authentication::match(undef, $params, $Actions::SET_ACCESS_DURATION);
  if (defined $value) {
      $value = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + normalize_time($value)));
      $logger->trace("Computed unrege date from access duration: $value");
  }
  else {
      $value = &pf::authentication::match(undef, $params, $Actions::SET_UNREG_DATE);
  }
  if (defined $value) {
      $logger->trace("Got unregdate $value for username $pid");
      %info = (%info, (unregdate => $value));
  }

  pf::web::web_node_register($portalSession, $pid, %info);
  pf::web::end_portal_session($portalSession);

} elsif (defined($cgi->url_param('mode')) && $cgi->url_param('mode') eq "next_page") {
  my $pageNb = int($cgi->url_param('page'));
  if (($pageNb > 1) && ($pageNb <= $Config{'registration'}{'nbregpages'})) {
    pf::web::generate_registration_page($portalSession, $pageNb);
  } else {
    pf::web::generate_error_page($portalSession, i18n("error: invalid page number"));
  }

} elsif (defined($cgi->url_param('mode')) && $cgi->url_param('mode') eq "deregister") {
  my ($form_return, $err) = pf::web::validate_form($portalSession);
  if ($form_return != 1) {
    $logger->trace("form validation failed or first time for " . $portalSession->getClientMac());
    pf::web::generate_login_page($portalSession, $err);
    exit(0);
  }

  my ($auth_return, $error) = pf::web::web_user_authenticate($portalSession);
  if ($auth_return != 1) {
    $logger->trace("authentication failed for " . $portalSession->getClientMac());
    pf::web::generate_login_page($portalSession, $error);
    exit(0);
  }

  my $node_info = node_view($portalSession->getClientMac());
  my $pid = $node_info->{'pid'};
  if ($portalSession->getSession->param("username") eq $pid) {
    my $cmd = $bin_dir."/pfcmd manage deregister " . $portalSession->getClientMac();
    my $output = qx/$cmd/;
    $logger->info("calling $bin_dir/pfcmd manage deregister " . $portalSession->getClientMac());
    print $cgi->redirect("/authenticate");
  } else {
    pf::web::generate_error_page($portalSession, i18n("error: access denied not owner"));
  }

} elsif (defined($cgi->url_param('mode')) && $cgi->url_param('mode') eq "release") {
  # TODO this is duplicated also in register.cgi
  # we drop HTTPS so we can perform our Internet detection and avoid all sort of certificate errors
  if ($cgi->https()) {
    print $cgi->redirect(
      "http://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
      .'/access?destination_url=' . uri_escape($portalSession->getDestinationUrl())
    );
  } else {
    pf::web::generate_release_page($portalSession);
  }
  exit(0);
} elsif (defined($cgi->url_param('mode')) && $cgi->url_param('mode') eq "aup") {
  pf::web::generate_aup_standalone_page($portalSession);
  exit(0);
} elsif (defined($cgi->url_param('mode'))) {
  pf::web::generate_error_page($portalSession, i18n("error: incorrect mode"));
} else {
  pf::web::generate_login_page($portalSession);
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

