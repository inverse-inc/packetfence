package pf::vlan::pool;

=head1 NAME

pf::vlan::pool - Object oriented module for VLAN isolation oriented functions

=head1 SYNOPSIS

The pf::vlan::pool module contains the functions necessary for the VLAN Pool.

=cut

use strict;
use warnings;

use Log::Log4perl;

use pf::config;
use pf::util;
use pf::log();

use pf::Portal::ProfileFactory;
use pf::person;


=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=cut

=head2 new

Constructor.

=cut

sub new {
    my $logger =  pf::log::get_logger();
    $logger->debug("instantiating new pf::vlan object");
    my ( $class, %argv ) = @_;
    my $this = bless {}, $class;
    return $this;
}

sub getVlanPool {
    my ($self, $vlan, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    my $logger =  pf::log::get_logger();

    return $vlan if ($vlan !~ /(\d+)-(\d+)/);
    $logger->warn("$1 $2");
}

