package pf::Switch::Enterasys::SecureStack_C3;

=head1 NAME

pf::Switch::Enterasys::SecureStack_C3 - Object oriented module to parse SNMP traps and manage 
Enterasys SecureStack C3 switches

=head1 STATUS

Developed and tested on an Enterasys SecureStack C3. 
Firmware version: 06.03.01.0008

It should work on all C3 switches and maybe more.

=cut

use strict;
use warnings;
use Net::SNMP;
use base ('pf::Switch::Enterasys');

sub description { 'Enterasys SecureStack C3' }

=head1 BUGS AND LIMITATIONS

=over

=item Multiple untagged egress VLAN per port

This switch supports multiple untagged VLAN per port but personally I don't think it's a "feature" ;). 
What happens is since we only change the primary VLAN id (PVID) on a setVlan, you need to pre-approve all the 
possible VLANs as untagged VLANs on the user ports. 
This way when the PVID changes, the VLAN was already authorized to go out egress untagged.

For example, if your normal VLAN is 10, isolation is 9 and registration is 8 and your users ports are 1 to 23 then you run:

set vlan egress 8,9,10 ge.1.1-ge.1.23 untagged

and you will be fine.

=item SNMPv3
    
SNMPv3 support was not tested

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
