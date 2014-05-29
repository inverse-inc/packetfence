package pf::api;
=head1 NAME

pf::api RPC methods exposing PacketFence features

=cut

=head1 DESCRIPTION

pf::api

=cut

use strict;
use warnings;

use pf::config();
use pf::iplog();
use pf::log();
use pf::radius::custom();
use pf::violation();
use pf::soh::custom();
use pf::util();
use pf::node;

sub event_add {
  my ($class, $date, $srcip, $type, $id) = @_;
  my $logger = pf::log::get_logger();
  $logger->info("violation: $id - IP $srcip");

  # fetch IP associated to MAC
  my $srcmac = pf::util::ip2mac($srcip);
  if ($srcmac) {

    # trigger a violation
    pf::violation::violation_trigger($srcmac, $id, $type);

  } else {
    $logger->info("violation on IP $srcip with trigger ${type}::${id}: violation not added, can't resolve IP to mac !");
    return(0);
  }
  return (1);
}

sub echo {
    my ($class, @args) = @_;
    return @args;
}

sub radius_authorize {
  my ($class, %radius_request) = @_;
  my $logger = pf::log::get_logger();

  my $radius = new pf::radius::custom();
  my $return;
  eval {
      $return = $radius->authorize(\%radius_request);
  };
  if ($@) {
      $logger->error("radius authorize failed with error: $@");
  }
  return $return;
}

sub radius_accounting {
  my ($class, %radius_request) = @_;
  my $logger = pf::log::get_logger();

  my $radius = new pf::radius::custom();
  my $return;
  eval {
      $return = $radius->accounting(\%radius_request);
  };
  if ($@) {
      $logger->logdie("radius accounting failed with error: $@");
  }
  return $return;
}

sub soh_authorize {
  my ($class, %radius_request) = @_;
  my $logger = pf::log::get_logger();

  my $soh = pf::soh::custom->new();
  my $return;
  eval {
    $return = $soh->authorize(\%radius_request);
  };
  if ($@) {
    $logger->error("soh authorize failed with error: $@");
  }
  return $return;
}

sub update_iplog {
    my ( $class, $srcmac, $srcip, $lease_length ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::iplog::iplog_update($srcmac, $srcip, $lease_length));
}
 
sub unreg_node_for_pid {
    my ($class, $pid) = @_;

    my $logger = pf::log::get_logger();

    #use Data::Dumper;
    #$logger->warn(Dumper $pid);
    $logger->info("Unregistering nodes for $pid");

    my @node_infos =  node_view_reg_pid($pid->{'pid'});

    foreach my $node_info ( @node_infos ) {
        node_deregister($node_info->{'mac'});
    }

return 1;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

1;

