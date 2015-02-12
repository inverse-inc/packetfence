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
use pf::node;

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

=head2 getVlanPool

Calculate the vlan in a pool

=cut

sub getVlanPool {
    my ($self, $vlan, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    my $logger =  pf::log::get_logger();

    return $vlan if ($vlan !~ /(\d+)-(\d+)/);
    # TODO select algo based on the portal profile or on the switch
    $vlan = $self->getRoundRobbin($1, $2, $mac, $node_info);
    return $vlan;
}

=head2 getRoundRobbin

Return the vlan id based on round robbin

=cut

sub getRoundRobbin {
    my ($self, $first_vlan, $last_vlan, $mac, $node_info) = @_;
    my $logger =  pf::log::get_logger();

    my $vlan_count = $last_vlan - $first_vlan +1;
    my $node_info_complete = node_view($mac);
    if ( defined($node_info_complete->{'last_vlan'}) && $node_info_complete->{'last_vlan'} ~~ [$first_vlan..$last_vlan] ) {
        return ($node_info_complete->{'last_vlan'});
    }
    my $last_reg_mac = node_last_reg_non_inline($mac, $node_info->{'category'});
    if (defined($last_reg_mac) && $last_reg_mac ne '') {
        my $new_vlan;
        my $last_reg_mac_info = node_view($last_reg_mac);
        if(defined($last_reg_mac_info->{'last_vlan'}) && $first_vlan <= $last_reg_mac_info->{'last_vlan'} && $last_reg_mac_info->{'last_vlan'} <= $last_vlan) {
            $new_vlan = (($last_reg_mac_info->{'last_vlan'} - $first_vlan) + 1) % $vlan_count + $first_vlan;
        } else {
            $new_vlan = $first_vlan;
        }
        return ($new_vlan);
    } else {
        $logger->warn("Welcome to the workflow, you are the first registered node YEAH !!!!");
        return ($first_vlan);
    }
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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
