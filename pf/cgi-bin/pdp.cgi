#!/usr/bin/perl -w

package PFAPI;

=head1 NAME

pdp.cgi - Web Services handler

=cut

#use Data::Dumper;
use strict;
use warnings;

use CGI;
use Log::Log4perl;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";
use pf::config;
use pf::db;
use pf::util;
use pf::iplog;
use pf::radius::custom;
use pf::violation;

use SOAP::Transport::HTTP;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('pdp.cgi');
Log::Log4perl::MDC->put('proc', 'pdp.cgi');
Log::Log4perl::MDC->put('tid', 0);


SOAP::Transport::HTTP::CGI
    -> dispatch_to('PFAPI')
    -> handle;


sub event_add {
  my ($class, $date, $srcip, $type, $id) = @_;
  $logger->info("violation: $id - IP $srcip");

  # fetch IP associated to MAC
  my $srcmac = ip2mac($srcip);
  if ($srcmac) {

    # trigger a violation
    violation_trigger($srcmac, $id, $type, ( ip => $srcip ));

  } else {
    $logger->info("violation on IP $srcip with trigger ${type}::${id}: violation not added, can't resolve IP to mac !");
    return(0);
  }
  return (1);
}

sub radius_authorize {
  my ($class, $nas_port_type, $switch_ip, $eap_type, $mac, $port, $user_name, $ssid) = @_;
  my $radius = new pf::radius::custom();

  #TODO change to trace level once done
  $logger->info("received a radius authorization request with parameters: ".
           "nas port type => $nas_port_type, switch_ip => $switch_ip, EAP-Type => $eap_type, ".
           "mac => $mac, port => $port, username => $user_name, ssid => $ssid");

  my $return;
  eval {
      $return = $radius->authorize($nas_port_type, $switch_ip, $eap_type, $mac, $port, $user_name, $ssid);
  };
  if ($@) {
      $logger->logdie("radius authorize failed with error: $@");
  }
  return $return;
}
=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2008-2010 Inverse inc.

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
