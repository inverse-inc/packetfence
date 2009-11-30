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
use pf::violation;

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

  # fetch IP associated to MAC
  my $srcmac = ip2mac($srcip);
  if ($srcmac) {

    # trigger a violation
    violation_trigger($srcmac, $id, $type, { ip => $srcip });

  } else {
    $logger->info("violation on IP $srcip with trigger ${type}::${id}: violation not added, can't resolve IP to mac !");
    return(0);
  }
  return (1);
}

