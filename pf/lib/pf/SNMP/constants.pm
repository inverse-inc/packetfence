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

=item dot1dTpFdbStatus - defined by RFC 1493 (Definitions of Managed Objects for Bridges)

 other(1)
 invalid(2)
 learned(3)
 self(4)
 mgmt(5)

=cut
Readonly::Scalar our $OTHER => 1;
Readonly::Scalar our $INVALID => 2;
Readonly::Scalar our $LEARNED => 3;
Readonly::Scalar our $SELF => 4;
Readonly::Scalar our $MGMT => 5;

=item TruthValue - defined by RFC 1903 (SNMP Textual Conventions) aka SNMPv2-TC

 true (1)
 false (2)

=cut
Readonly::Scalar our $TRUE => 1;
Readonly::Scalar our $FALSE => 2;

=item RowStatus - defined by RFC 2579 (Textual Conventions for SMIv2)

 active (1)
 notInService (2)
 notReady (3)
 createAndGo (4)
 createAndWait (5)
 destroy (6)

=cut
Readonly::Scalar our $ACTIVE => 1;
Readonly::Scalar our $NOT_IN_SERVICE => 2;
Readonly::Scalar our $NOT_READY => 3;
Readonly::Scalar our $CREATE_AND_GO => 4;
Readonly::Scalar our $CREATE_AND_WAIT => 5;
Readonly::Scalar our $DESTROY => 6;

=item ifAdminStatus - defined by RFC 2863 (Interfaces Group) aka IF-MIB

 up(1),        -- ready to pass packets
 down(2),
 testing(3),   -- in some test mode

=item ifOperStatus - defined by RFC 2863 (Interfaces Group) aka IF-MIB

 up(1),        -- ready to pass packets
 down(2),
 testing(3),   -- in some test mode
 unknown(4),   -- status can not be determined for some reason.
 dormant(5),
 notPresent(6),    -- some component is missing
 lowerLayerDown(7) -- down due to state of lower-layer interface(s)

=cut
Readonly::Scalar our $UP => 1;
Readonly::Scalar our $DOWN => 2;
Readonly::Scalar our $TESTING => 3;
Readonly::Scalar our $UNKNOWN => 4;
Readonly::Scalar our $DORMANT => 5;
Readonly::Scalar our $NOT_PRESENT => 6;
Readonly::Scalar our $LOWER_LAYER_DOWN => 7;

=item ifType - defined by RFC 2863 (Interfaces Group) aka IF-MIB

There are a lot of ifTypes, only a few of interest to PacketFence were copied here. 
Check http://www.iana.org/assignments/ianaiftype-mib for the full list.

 ...
 ethernetCsmacd(6),
 ...
 gigabitEthernet (117), Obsoleted via RFC3635. ethernetCsmacd (6) should be used instead
 ...

=cut
Readonly::Scalar our $ETHERNET_CSMACD => 6;
Readonly::Scalar our $GIGABIT_ETHERNET => 117;


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

=head1 EXTREME

Extreme Networks constants

=over

=cut
package EXTREME;

=item PORT_SECURITY_DETECT_VLAN 

Special VLAN used to detect if locked-learning is activated or not. Used for isPortSecurityEnabled()

=cut
Readonly::Scalar our $PORT_SECURITY_DETECT_VLAN => 'security-detection';

=item Web Services constants - constants related to Extreme's Web Services functionality

 WS_TIMEOUT - Timeout value for Web Services operations
 WS_PROXY_URI_PATH - Common path for Extreme's Web Services operations
 WS_NAMESPACE_FDB - Namespace for the Fdb table operations
 WS_PREFIX_XOS - Prefix for XOS APIs
 WS_DATATYPE_MAC - MAC address datatype
 WS_DATATYPE_VLAN - VLAN datatype
 WS_DATATYPE_PORT - Port datatype
 WS_CREATE_FDB - Create Fdb Entry method call
 WS_DELETE_FDB - Delete Fdb Entry method call
 WS_GET_ALL_FDB - Get All Fdb Entries method call
 WS_NODE_ALL_FDB_RESPONSE - Tree structure that gets to the Fdb contents

=cut
Readonly::Scalar our $WS_TIMEOUT => 10;
Readonly::Scalar our $WS_PROXY_URI_PATH => 'xmlservice';
Readonly::Scalar our $WS_NAMESPACE_FDB => 'urn:xapi/l2protocol/fdb';
Readonly::Scalar our $WS_PREFIX_XOS => 'xos';

Readonly::Scalar our $WS_DATATYPE_TRUE => 'true';
Readonly::Scalar our $WS_DATATYPE_FALSE => 'false';
Readonly::Scalar our $WS_DATATYPE_MAC => 'macAddress';
Readonly::Scalar our $WS_DATATYPE_VLAN => 'vlan';
Readonly::Scalar our $WS_DATATYPE_PORT => 'port';
Readonly::Scalar our $WS_DATATYPE_PERMANENT => 'isPermanent';

Readonly::Scalar our $WS_CREATE_FDB => 'xos:createFdb';
Readonly::Scalar our $WS_DELETE_FDB => 'xos:deleteFdb';
Readonly::Scalar our $WS_GET_ALL_FDB => 'xos:getAllFdb';

Readonly::Scalar our $WS_NODE_ALL_FDB_RESPONSE => '//Body/getAllFdbResponse/reply/fdb';

=back

=head1 EXTREME::VLAN

Extreme Networks VLAN oriented constants

=over 

=cut
package EXTREME::VLAN;

=item extremeVlanOpaqueControlOperation - Operations on VLANs (from EXTREME-VLAN-MIB)

 addTagged(1)
 addUntagged(2)
 delete(3)

=cut
Readonly::Scalar our $ADD_TAGGED => 1;
Readonly::Scalar our $ADD_UNTAGGED => 2;
Readonly::Scalar our $DELETE => 3;

=back

=head1 NORTEL

Nortel constants

=over

=cut
package NORTEL;

=item rcVlanPortType - Port types (from RC-VLAN-MIB)

  access(1),
  trunk(2)

Note: Documentation is incomplete other values were found empirically.

=cut
Readonly::Scalar our $ACCESS => 1; # aka Untag All (not allowed in strict mode)
Readonly::Scalar our $TRUNK => 2; # aka Tag All
Readonly::Scalar our $UNTAG_PVID_ONLY => 5;
Readonly::Scalar our $TAG_PVID_ONLY => 6; # (not allowed in strict mode)

=back

=head1 HP

HP ProCurve constants

=over 

=cut
package HP;

=item coDevWirCliDisassociate - Disassociate the wireless client (from COLUBRIS-DEVICE-WIRELESS-MIB)

 idle(0),
 disassociate(1)

=cut
Readonly::Scalar our $IDLE => 0;
Readonly::Scalar our $DISASSOCIATE => 1;

=back

=head1 THREECOM

3Com constants

=over

=cut
package THREECOM;

=item hwdot1qTpFdbSetStatus

 other(1),
 learned(3),
 static(6),
 dynamic(7),
 blackhole(9),
 security(11)

=cut
Readonly::Scalar our $OTHER => 1;
Readonly::Scalar our $LEARNED => 3;
Readonly::Scalar our $STATIC => 6;


=item hwdot1qTpFdbSetOperate

 add(1),
 delete(2)

=cut
Readonly::Scalar our $ADD => 1;
Readonly::Scalar our $DELETE => 2;


=item NAS-Port constants

Used for NAS-Port to ifIndex translation

=cut
Readonly::Scalar our $NAS_PORT_OFFSET => 16781312;
Readonly::Scalar our $NAS_PORTS_PER_PORT_RANGE => 4096;

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010-2011 Inverse inc.

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
