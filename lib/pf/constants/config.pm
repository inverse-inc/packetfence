package pf::constants::config;

=head1 NAME

pf::constants::config - constants for config object

=cut

=head1 DESCRIPTION

pf::constants::config

=cut

use strict;
use warnings;

use Readonly;

Readonly our $IF_ENFORCEMENT_VLAN => 'vlan';
Readonly our $IF_ENFORCEMENT_INLINE => 'inline';
Readonly our $IF_ENFORCEMENT_INLINE_L2 => 'inlinel2';
Readonly our $IF_ENFORCEMENT_INLINE_L3 => 'inlinel3';

Readonly our $NET_TYPE_VLAN_REG => 'vlan-registration';
Readonly our $NET_TYPE_VLAN_ISOL => 'vlan-isolation';
Readonly our $NET_TYPE_INLINE => 'inline';
Readonly our $NET_TYPE_INLINE_L2 => 'inlinel2';
Readonly our $NET_TYPE_INLINE_L3 => 'inlinel3';

Readonly our $TIME_MODIFIER_RE => qr/[smhDWMY]/;
Readonly our $ACCT_TIME_MODIFIER_RE => qr/[DWMY]/;
Readonly our $DEADLINE_UNIT => qr/[RF]/;


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

