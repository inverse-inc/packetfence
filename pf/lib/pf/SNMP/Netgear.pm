package pf::SNMP::Netgear;

=head1 NAME

pf::SNMP::Netgear

=head1 DESCRIPTION

This modules holds functions common to the Netgear switches but details and documentation are in each sub-module. 
Refer to them for more information.

=head1 BUGS AND LIMITATIONS

This modules holds functions common to the Netgear switches but details and documentation are in each sub-module. 
Refer to them for more information.

=cut

use strict;
use warnings;
use diagnostics;

use POSIX;
use Log::Log4perl;
use Net::SNMP;

use pf::SNMP::constants;
use pf::util;

use base ('pf::SNMP');

=head1 SUBROUTINES
            
=over   

=cut

=item isPortSecurityEnabled - check if port security is enabled on the switch

Since port security on this switch is called Trusted MAC, there's no check possible to see if
port security is enabled.
Return true cause the switch is correctly configured for port security

=cut

sub isPortSecurityEnabled { return 1 == 1; }

=back

=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

=head1 LICENCE

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
