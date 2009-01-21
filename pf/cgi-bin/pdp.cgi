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
  $logger->info("violation: $id - IP $srcip");
  my $dbh = db_connect();

  my @trigger_info = trigger_view_enable($id,$type);
  if (scalar(@trigger_info)) {
    foreach my $row (@trigger_info) {
      my $vid = $row->{'vid'};
      my $srcmac = ip2mac($srcip);
      if ($srcmac) {
        $logger->info("violation: $vid - IP $srcip : IP resolved to $srcmac");
        if (whitelisted_mac($srcmac)) {
          $logger->info("violation: $vid - IP $srcip : violation not added, $srcmac is whitelisted !");
        } elsif (!valid_mac($srcmac)) {
          $logger->info("violation: $vid - IP $srcip : violation not added, $srcmac is not valid !");
        } elsif (!trappable_ip($srcip)) {
          $logger->info("violation: $vid - IP $srcip : violation not added, IP is not trappable !");
        } elsif (!trappable_mac($srcmac)) {
          $logger->info("violation: $vid - IP $srcip : violation not added, $srcmac is not trappable !");
        } else  {
          `/usr/local/pf/bin/pfcmd violation add vid=$vid,mac=$srcmac`;
        }
      } else {
        $logger->info("violation: $vid - IP $srcip : violation not added, can not resolve IP to mac !");
        return(0);
      }
    }
  } else {
    $logger->info("violation: $id - IP $srcip : violation not added, no trigger found or violation is disabled");
  }
  return (1);
}

