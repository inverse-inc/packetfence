#!/usr/bin/perl -w

package PFEvents;

#use Data::Dumper;
use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );

use lib '/usr/local/pf/lib';
use pf::db;
use pf::util;
use pf::iplog;
use pf::trigger;

use SOAP::Transport::HTTP;

SOAP::Transport::HTTP::CGI
    -> dispatch_to('PFEvents')
    -> handle;


sub event_add {
  my ($class, $date, $srcip, $type, $id) = @_;
  pflogger("PDP: $date - IP: $srcip - Type: $type - ID: $id",1);
  my $dbh = db_connect();

  my @trigger_info = trigger_view_enable($id,$type);
  if (scalar(@trigger_info)) {
    foreach my $row (@trigger_info) {
      my $vid = $row->{'vid'};
      # do violation addition 
      pflogger("PDP: violation: $vid : $srcip",1);

      my $srcmac = ip2mac($srcip);
      if ($srcmac) {
        pflogger("PDP: violation: $srcip resolved to $srcmac [$vid]",1);
        if (!whitelisted_mac($srcmac) && valid_mac($srcmac) && trappable_ip($srcip) && trappable_mac($srcmac)) {
          `/usr/local/pf/bin/pfcmd violation add vid=$vid,mac=$srcmac`;
        }
      } else {
        pflogger("PDP: Mac not found for IP: $srcip",1);
        return(0);
      }
    }
  } else {
    pflogger("violation not added, no trigger found for " . $type . "::" . $id . " or violation is disabled", 8);
  }
  return (1);
}

