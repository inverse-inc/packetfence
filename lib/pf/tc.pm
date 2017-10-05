package pf::tc;

=head1 NAME

pf::tc - module for tc tables management.

=cut

=head1 DESCRIPTION

pf::tc contains the functions necessary to manipulate the
tc tables for traffic shaping

=cut

use strict;
use warnings;

use pf::log;
use Readonly;

use pf::config qw(
    @internal_nets
    $management_network
);

my @ints = split(',', pf::iptables::get_network_snat_interface());
my @listen_interfaces = map {$_->tag("int")} @internal_nets, $management_network;

my @interfaces = keys %{{map {($_ => 1)} (@ints, @listen_interfaces)}};
$i = 1;
foreach my $int ( @interfaces) {
    foreach my $network ( keys %ConfigNetworks ) {
        $logger->warn("tc qdisc del dev $int root");
        $logger->warn("tc qdisc add dev $int root handle $i:0 htb default 1");
        next if ( !pf::config::is_network_type_inline($network) );
        foreach my $role ( @roles ) {
            $logger->warn("tc class add dev eth0 parent $i:0 classid $i:$role->{'category_id'} htb rate 1mbit ceil 1mbit");
        }
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.

=cut

1;
