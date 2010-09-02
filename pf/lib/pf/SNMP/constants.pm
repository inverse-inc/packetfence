package pf::SNMP::constants;

=head1 NAME

pf::SNMP::constants - Constants for SNMP to be consumed by SNMP modules

=head1 DESCRIPTION

This file is splitted by packages and refering to the constant requires you to
specify the package.

=cut

use strict;
use warnings;
use diagnostics;

use Readonly;

=head1 SNMP

Defined by standards

=over

=cut
package SNMP;

=item TruthValue - defined by RFC 1903 (SNMP Textual Conventions) aka SNMPv2-TC

 true (1)
 false (2)

=cut
Readonly::Scalar our $TRUE => 1;
Readonly::Scalar our $FALSE => 2;

=back

=head1 Q-BRIDGE

RFC 4363:  Definitions of Managed Objects for Bridges with Traffic Classes, Multicast Filtering, and Virtual LAN Extensions

=over

=cut
package SNMP::Q_BRIDGE;

=item dot1qStaticUnicastStatus

 other(1)
 invalid(2)
 permanent(3)
 deleteOnReset(4)
 deleteOnTimeout(5)
 
=cut
Readonly::Scalar our $OTHER => 1;
Readonly::Scalar our $INVALID => 2;
Readonly::Scalar our $PERMANENT => 3;
Readonly::Scalar our $DELETE_ON_RESET => 4;
Readonly::Scalar our $DELETE_ON_TIMEOUT => 5;

=back
 
=head1 CISCO

Cisco constants

=over

=cut
package CISCO;

=item cpsIfViolationAction - Action to take in case of port-security violation (from CISCO-PORT-SECURITY-MIB)

 Shutdown (1)
 DropNotify (2)
 Drop (3)

=cut
Readonly::Scalar our $SHUTDOWN => 1;
Readonly::Scalar our $DROPNOTIFY => 2;
Readonly::Scalar our $DROP => 3;

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010 Inverse inc.

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
