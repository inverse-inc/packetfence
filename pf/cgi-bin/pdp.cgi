#!/usr/bin/perl -w

package PFEvents;

#use Data::Dumper;
use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use Log::Log4perl;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";
use pf::config;
use pf::db;
use pf::util;
use pf::iplog;
use pf::trigger;

use SOAP::Transport::HTTP;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('pdp.cgi');
Log::Log4perl::MDC->put('proc', 'pdp.cgi');
Log::Log4perl::MDC->put('tid', 0);


SOAP::Transport::HTTP::CGI
    -> dispatch_to('PFEvents')
    -> handle;


sub event_add {
  my ($class, $date, $srcip, $type, $id) = @_;
  $logger->info("PDP: $date - IP: $srcip - Type: $type - ID: $id");
  my $dbh = db_connect();

  my @trigger_info = trigger_view_enable($id,$type);
  if (scalar(@trigger_info)) {
    foreach my $row (@trigger_info) {
      my $vid = $row->{'vid'};
      # do violation addition 
      $logger->info("PDP: violation: $vid : $srcip");

      my $srcmac = ip2mac($srcip);
      if ($srcmac) {
        $logger->info("PDP: violation: $srcip resolved to $srcmac [$vid]");
        if (!whitelisted_mac($srcmac) && valid_mac($srcmac) && trappable_ip($srcip) && trappable_mac($srcmac)) {
          `$bin_dir/pfcmd violation add vid=$vid,mac=$srcmac`;
        }
      } else {
        $logger->info("PDP: Mac not found for IP: $srcip");
        return(0);
      }
    }
  } else {
    $logger->info("violation not added, no trigger found for " . $type . "::" . $id . " or violation is disabled");
  }
  return (1);
}

