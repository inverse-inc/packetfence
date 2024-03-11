package pf::Switch::Cisco::Catalyst_4500;

=head1 NAME

pf::Switch::Cisco::Catalyst_4500 - Object oriented module to access and configure Cisco Catalyst 4500 switches

=head1 STATUS

This module is currently only a placeholder, see pf::Switch::Cisco::Cisco_IOS_15_0.

We do not know the minimum required firmware version.

=head1 BUGS AND LIMITATIONS

Because a lot of code is shared with the Cisco_IOS_15_0 make sure to check the BUGS AND LIMITATIONS section of
L<pf::Switch::Cisco::Cisco_IOS_15_0> also.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=head1 SNMP

This switch can parse SNMP traps and change a VLAN on a switch port using SNMP.

=cut

use strict;
use warnings;
use Net::SNMP;

use base ('pf::Switch::Cisco::Cisco_IOS_15_0');

sub description { 'Cisco Catalyst 4500 Series' }

=head2 getIfIndexByNasPortId

Fetch the ifindex on the switch by NAS-Port-Id radius attribute

=cut


sub getIfIndexByNasPortId {
    my ($self, $ifDesc_param) = @_;

    if (!defined($ifDesc_param) || !$self->connectRead() ) {
        return 0;
    }

    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';
    my $ifDescHashRef;
    my $cache = $self->cache_distributed;
    my $result = $cache->compute($self->{'_id'} . "-" . $OID_ifDesc, sub { $self->{_sessionRead}->get_table( -baseoid => $OID_ifDesc )});
    foreach my $key ( keys %{$result} ) {
        my $ifDesc = $result->{$key};
        if ( $ifDesc =~ /$ifDesc_param$/i ) {
            $key =~ /^$OID_ifDesc\.(\d+)$/;
            return $1;
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
