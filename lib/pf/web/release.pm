package pf::web::release;

=head1 NAME

release.pm - Handles releasing nodes out of the captive portal.

=cut
# TODO this is not the best namespace.. we should reconsider

use strict;
use warnings;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK REDIRECT);
use Date::Parse;
use Log::Log4perl;
use URI::Escape qw(uri_escape);

use pf::class;
use pf::config;
use pf::iplog;
use pf::node;
use pf::Portal::Session;
use pf::scan qw($SCAN_VID);
use pf::trigger;
use pf::util;
use pf::violation;
use pf::web;
# called last to allow redefinitions
use pf::web::custom;

sub handler
{
  my $r = shift;

  Log::Log4perl->init("$conf_dir/log.conf");
  my $logger = Log::Log4perl->get_logger('release.pm');
  Log::Log4perl::MDC->put('proc', 'release.pm');
  Log::Log4perl::MDC->put('tid', 0);

  my $portalSession     = pf::Portal::Session->new();
  my $cgi               = $portalSession->getCgi();
  my $session           = $portalSession->getSession();
  my $ip                = $portalSession->getClientIp();
  my $destination_url   = $portalSession->getDestinationUrl();
  my $mac               = $portalSession->getClientMac();

  # we need a valid MAC to identify a node
  # TODO this is duplicated too much, it should be brought up in a global dispatcher
  if (!valid_mac($mac)) {
    $logger->info("$ip not resolvable, generating error page");
    pf::web::generate_error_page($portalSession, i18n("error: not found in the database"), $r);
    return Apache2::Const::OK;
  }

  if (defined($cgi->param('mode'))) {
    if ($cgi->param('mode') eq 'release') {
      # TODO this is duplicated also in register.cgi
      # we drop HTTPS so we can perform our Internet detection and avoid all sort of certificate errors
      if ($cgi->https()) {
        print $cgi->redirect(
          "http://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
          .'/access?destination_url=' . uri_escape($destination_url)
        );
        return Apache2::Const::REDIRECT;
      } else {
        pf::web::generate_release_page($portalSession, $r);
        return Apache2::Const::OK;
      }
    }
  }
  
  my $violations = violation_view_top($mac); 
  # is violations valid
  if (!defined($violations) || ref($violations) ne 'HASH' || !defined($violations->{'vid'})) {
    # not valid, we should not be here then, lets tell the user to re-open his browser
    pf::web::generate_error_page($portalSession, i18n("release: reopen browser"), $r);
    return Apache2::Const::OK;
  }
  
  my $vid = $violations->{'vid'}; 
  
  # is class valid? if so, let's grab some related info that we will need
  my ($class_redirect_url, $class_max_enable_url);
  my $class=class_view($vid);
  if (defined($class) && ref($class) eq 'HASH') {
    $class_redirect_url = $class->{'redirect_url'} if defined($class->{'redirect_url'});
    $class_max_enable_url = $class->{'max_enable_url'} if defined($class->{'max_enable_url'});
  }

  # scan code...
  if ($vid == $SCAN_VID) {
    # detect if a system scan is in progress, if so redirect to scan in progress page
    # this should only happen if the user explicitly put /release in his browser address
    if ($violations->{'ticket_ref'} =~ /^Scan in progress, started at: (.*)$/) {
      $logger->info("captive portal redirect to the scan in progress page");
      pf::web::generate_scan_status_page($portalSession, $1, $r);
      return Apache2::Const::OK;
    }
    
    # Start scan in cleanup phase to avoid browser to hang on connection
    my $cmd = $bin_dir."/pfcmd schedule now $ip 1>/dev/null 2>&1";
    $logger->info("scanning $ip by calling $cmd");
    $r->pool->cleanup_register(\&scan, [$logger, $violations, $cmd]); 
 
    $logger->trace("parent part, redirecting to scan started page");
    pf::web::generate_scan_start_page($portalSession, $r);
  
    return Apache2::Const::OK;
  }
  
  my $cmd = $bin_dir."/pfcmd manage vclose $mac $vid";
  $logger->info("calling $bin_dir/pfcmd manage vclose $mac $vid");
  my $grace = qx/$cmd/;
  $grace =~ s/^.+\n\n//;
  #my $grace = violation_close($mac,$vid);
  $logger->info("pfcmd manage vclose $mac $vid returned $grace");
  
  if ($grace != -1) {
    my $count = violation_count($mac); 
  
    $logger->info("$mac enabled for $grace minutes");
    if ($count == 0) {
  
      if ($class_redirect_url) {
        $destination_url = $class_redirect_url;
      }
      # we drop HTTPS so we can perform our Internet detection and avoid all sort of certificate errors
      if ($cgi->https()) {
        print $cgi->redirect(
          "http://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
          .'/access?destination_url=' . uri_escape($destination_url)
        );
        return Apache2::Const::REDIRECT;
      }
      else {
        pf::web::generate_release_page($portalSession, $r);
        return Apache2::Const::OK;
      }
    }
    else {
      if ($class_redirect_url) {
        print $cgi->redirect('/captive-portal?destination_url=' . uri_escape($class_redirect_url));
      } else {
        print $cgi->redirect('/captive-portal?destination_url=' . uri_escape($destination_url));
      }
      return Apache2::Const::REDIRECT;
    }
  } else {
    $logger->info("$mac reached maximum violations");
    if ($class_max_enable_url) {
      print $cgi->redirect($class_max_enable_url);
      return Apache2::Const::REDIRECT;
    }
    else {
      pf::web::generate_error_page($portalSession, i18n("error: max re-enables reached"), $r);
      return Apache2::Const::OK;
    }
  }

} # sub handler

sub scan {
  my $args = shift;
  my ($logger, $violations, $cmd) = @{$args};

  # HACK: add a start date in the violation's ticket_ref to track the fact that the scan is in progress
  my $currentScanViolationId = $violations->{'id'};
  violation_modify($currentScanViolationId, (ticket_ref => "Scan in progress, started at: ".mysql_date()));
  
  # requesting the scan
  $logger->trace("cleanup phase, forking $cmd");
  my $scan = qx/$cmd/;
  
  return Apache2::Const::OK;
} # sub scan

1;

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
