package pf::Switch::constants;

=head1 NAME

pf::Switch::constants - Constants for SNMP to be consumed by SNMP modules

=head1 DESCRIPTION

This file is splitted by packages and refering to the constant requires you to
specify the package.

=cut

use strict;
use warnings;

use Readonly;

=head1 SNMP

Defined by standards

=cut

package SNMP;

=head2 VERSIONS

Supported SNMP versions by PacketFence

=cut

Readonly::Scalar our $VERSION_1 => '1';
Readonly::Scalar our $VERSION_2C => '2c';
Readonly::Scalar our $VERSION_3 => '3';

Readonly::Array our @VERSIONS =>
  (
   $VERSION_1, $VERSION_2C, $VERSION_3
  );

=head2 MAC_ADDRESS_FORMAT

snmptrapd guesses the format of data in traps.
If the format is printable then it feeds it as a STRING.
Otherwise an Hex-STRING is sent (99.9% of the cases).

We need to handle both cases thus this precompiled regexp.

=cut

Readonly::Scalar our $MAC_ADDRESS_FORMAT => qr/
    (
        Hex-STRING:\ 
        [0-9A-Z]{2}\ [0-9A-Z]{2}\ [0-9A-Z]{2}\ [0-9A-Z]{2}\ [0-9A-Z]{2}\ [0-9A-Z]{2} # MAC Address
    |
        STRING:\ 
        ".+"
    )
/sx; # which may contain newline characters to mean hex 0a (thus the s)


=head2 dot1dTpFdbStatus - defined by RFC 1493 (Definitions of Managed Objects for Bridges)

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

=head2 TruthValue - defined by RFC 1903 (SNMP Textual Conventions) aka SNMPv2-TC

 true (1)
 false (2)

=cut

Readonly::Scalar our $TRUE => 1;
Readonly::Scalar our $FALSE => 2;

=head2 RowStatus - defined by RFC 2579 (Textual Conventions for SMIv2)

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

=head2 ifAdminStatus - defined by RFC 2863 (Interfaces Group) aka IF-MIB

 up(1),        -- ready to pass packets
 down(2),
 testing(3),   -- in some test mode

=head2 ifOperStatus - defined by RFC 2863 (Interfaces Group) aka IF-MIB

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

=head2 ifType - defined by RFC 2863 (Interfaces Group) aka IF-MIB

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

=head2 Working modes

Working modes of a switch

=cut

Readonly::Scalar our $TESTING_MODE => 'testing';
Readonly::Scalar our $REGISTRATION_MODE => 'registration';
Readonly::Scalar our $PRODUCTION_MODE => 'production';

Readonly::Array our @MODES =>
  (
   $TESTING_MODE, $REGISTRATION_MODE, $PRODUCTION_MODE,
  );

=head2 Deauth type method

Deauth type method constant

=cut

Readonly::Scalar our $TELNET => 'Telnet';
Readonly::Scalar our $SSH => 'SSH';
Readonly::Scalar our $SNMP => 'SNMP';
Readonly::Scalar our $RADIUS => 'RADIUS';
Readonly::Scalar our $HTTP => 'HTTP';
Readonly::Scalar our $HTTPS => 'HTTPS';

=head2 Deauth type method

List of available deauth type methods

=cut

Readonly::Array our @METHODS =>
  (
   $TELNET, $SSH, $SNMP, $RADIUS, $HTTP, $HTTPS,
  );


=head1 Q-BRIDGE

RFC 4363:  Definitions of Managed Objects for Bridges with Traffic Classes, Multicast Filtering, and Virtual LAN Extensions

=cut

package SNMP::Q_BRIDGE;

=head2 dot1qStaticUnicastStatus

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

=head1 LLDP

=cut

package SNMP::LLDP;

=head2 LldpSystemCapabilitiesMap

Defined by IEEE 802.1AB. Values below from LLDP-MIB.

 other(0),
 repeater(1),
 bridge(2),
 wlanAccessPoint(3),
 router(4),
 telephone(5),
 docsisCableDevice(6),
 stationOnly(7)

=cut

# only the one in use are defined
Readonly::Scalar our $TELEPHONE => 5;

=head1 CISCO

Cisco constants

=cut

package CISCO;

=head2 cpsIfViolationAction - Action to take in case of port-security violation (from CISCO-PORT-SECURITY-MIB)

 Shutdown (1)
 DropNotify (2)
 Drop (3)

=cut

Readonly::Scalar our $SHUTDOWN => 1;
Readonly::Scalar our $DROPNOTIFY => 2;
Readonly::Scalar our $DROP => 3;

=head2 ConfigFileType

Various configuration-related source files or target files.
Used by ccCopySourceFileType and ccCopyDestFileType.
From CISCO-CONFIG-COPY MIB.

  networkFile(1),
  iosFile(2),
  startupConfig(3),
  runningConfig(4),
  terminal(5),
  fabricStartupConfig(6)

=cut

Readonly::Scalar our $NETWORK_FILE => 1;
Readonly::Scalar our $STARTUP_CONFIG => 3;
Readonly::Scalar our $RUNNING_CONFIG => 4;
Readonly::Scalar our $TERMINAL => 5;

=head2 NAS-Port constants

Used for NAS-Port to ifIndex translation

=cut

Readonly::Scalar our $IFINDEX_OFFSET => 10000;
Readonly::Scalar our $IFINDEX_GIG_OFFSET => 10100;
Readonly::Scalar our $IFINDEX_PER_STACK => 500;

=head2 LLDP constants

lldpRemTimeMark is always set to 0 on Cisco's (at least those we tried)

=cut

Readonly::Scalar our $DEFAULT_LLDP_REMTIMEMARK => 0;

=head2 Trunk encapsulation constants

Used to set the encapsulation of a trunk

=cut

Readonly::Scalar our $TRUNK_DOT1Q => 4;
Readonly::Scalar our $TRUNK_AUTO => 5;

=head1 EXTREME

Extreme Networks constants

=cut

package EXTREME;

=head2 PORT_SECURITY_DETECT_VLAN

Special VLAN used to detect if locked-learning is activated or not. Used for isPortSecurityEnabled()

=cut

Readonly::Scalar our $PORT_SECURITY_DETECT_VLAN => 'security-detection';

=head2 Web Services constants - constants related to Extreme's Web Services functionality

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

=head1 EXTREME::VLAN

Extreme Networks VLAN oriented constants

=cut

package EXTREME::VLAN;

=head2 extremeVlanOpaqueControlOperation - Operations on VLANs (from EXTREME-VLAN-MIB)

 addTagged(1)
 addUntagged(2)
 delete(3)

=cut

Readonly::Scalar our $ADD_TAGGED => 1;
Readonly::Scalar our $ADD_UNTAGGED => 2;
Readonly::Scalar our $DELETE => 3;

=head1 NORTEL

Nortel constants

=cut

package NORTEL;

=head2 rcVlanPortType - Port types (from RC-VLAN-MIB)

  access(1),
  trunk(2)

Note: Documentation is incomplete other values were found empirically.

=cut

Readonly::Scalar our $ACCESS => 1; # aka Untag All (not allowed in strict mode)
Readonly::Scalar our $TRUNK => 2; # aka Tag All
Readonly::Scalar our $UNTAG_PVID_ONLY => 5;
Readonly::Scalar our $TAG_PVID_ONLY => 6; # (not allowed in strict mode)

=head1 HP

HP ProCurve constants

=cut

package HP;

=head2 coDevWirCliDisassociate - Disassociate the wireless client (from COLUBRIS-DEVICE-WIRELESS-MIB)

 idle(0),
 disassociate(1)

=cut

Readonly::Scalar our $IDLE => 0;
Readonly::Scalar our $DISASSOCIATE => 1;

=head1 THREECOM

3Com constants

=cut

package THREECOM;

=head2 hwdot1qTpFdbSetStatus

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


=head2 hwdot1qTpFdbSetOperate

 add(1),
 delete(2)

=cut

Readonly::Scalar our $ADD => 1;
Readonly::Scalar our $DELETE => 2;


=head2 NAS-Port constants

Used for NAS-Port to ifIndex translation

=cut

Readonly::Scalar our $NAS_PORT_OFFSET => 16781312;
Readonly::Scalar our $NAS_PORTS_PER_PORT_RANGE => 4096;

=head1 BROCADE

Brocade constants

=cut

package BROCADE;

=head2 dot1xPaePortReauthenticate - 802.1x Port state (from brcdlp)

  force_unauthorized(1),
  controlauto(2)

Note: Documentation is incomplete other values were found empirically.

=cut

Readonly::Scalar our $FORCE_UNAUTHORIZED => 1; # aka force unauthorized
Readonly::Scalar our $CONTROLAUTO => 2; # aka force control auto

=head1 AEROHIVE

AeroHive constants

=cut

package AEROHIVE;

=head2 ahConnectionChangeEvent - Roaming change (from ah_trp_mib)

ahAPId,
ahAPName,
ahObjectName,
ahIfIndex,           -- Interface index detecting the client/neighbor
ahObjectType,        -- Client connection or neighbor connection
ahRemoteId,          -- MAC addr for the client or neighbour
ahCurrentState,      -- up, or down.
ahSSID,              -- ssid of the client is using if remoteid is a client
ahCLientIP,          -- Client IP address if the remote id is a client
ahClientHostName,    -- Client Host Name if the remote id is a client
ahClientUserName,    -- Client User Name if the remote id is a client
ahClientAuthMethod,  -- The authentication method the client uses to communicate with the HiveAP
ahClientEncryptionMethod,       -- The encryption method the client uses to communicate with the HiveAP
ahClientMACProtocol,    -- The radio mode the client uses to communicate with the HiveAP
ahClientVLAN,                   -- The VLAN used by client to communicate with the HiveAP
ahClientUserProfId,     -- The user profile id used by client to communicate with the HiveAP
ahClientChannel,                -- The radio channel used by client to communicate with the HiveAP
ahClientCWPUsed,                -- The boolean indicating whether Captive Web Portal is used
ahBSSID,                                -- Basic Service Set Identifier of the client is using if remoteid is a client.
ahAssociationTime,      -- The association time(s) of client connect or disconnect to AP.
ahIfName,               -- The interface name of client connect or disconnect to AP.
ahCode,
ahTrapDesc


=cut

Readonly::Scalar our $ahConnectionChangeEvent => '.1.3.6.1.4.1.26928.1.1.1.1.1.4';
Readonly::Scalar our $ahAPId => '.1.3.6.1.4.1.26928.1.1.1.1.2.1';
Readonly::Scalar our $ahAPName => '.1.3.6.1.4.1.26928.1.1.1.1.2.2';
Readonly::Scalar our $ahTrapDesc => '.1.3.6.1.4.1.26928.1.1.1.1.2.11';
Readonly::Scalar our $ahCode => '.1.3.6.1.4.1.26928.1.1.1.1.2.12';
Readonly::Scalar our $ahObjectName => '.1.3.6.1.4.1.26928.1.1.1.1.2.4';
Readonly::Scalar our $ahIfIndex => '.1.3.6.1.4.1.26928.1.1.1.1.2.13';
Readonly::Scalar our $ahObjectType => '.1.3.6.1.4.1.26928.1.1.1.1.2.14';
Readonly::Scalar our $ahRemoteId => '.1.3.6.1.4.1.26928.1.1.1.1.2.15';
Readonly::Scalar our $ahCurrentState => '.1.3.6.1.4.1.26928.1.1.1.1.2.10';
Readonly::Scalar our $ahSSID => '.1.3.6.1.4.1.26928.1.1.1.1.2.20';
Readonly::Scalar our $ahCLientIP => '.1.3.6.1.4.1.26928.1.1.1.1.2.25';
Readonly::Scalar our $ahClientHostName => '.1.3.6.1.4.1.26928.1.1.1.1.2.26';
Readonly::Scalar our $ahClientUserName => '.1.3.6.1.4.1.26928.1.1.1.1.2.27';
Readonly::Scalar our $ahClientAuthMethod => '.1.3.6.1.4.1.26928.1.1.1.1.2.35';
Readonly::Scalar our $ahClientEncryptionMethod => '.1.3.6.1.4.1.26928.1.1.1.1.2.36';
Readonly::Scalar our $ahClientMACProtocol => '.1.3.6.1.4.1.26928.1.1.1.1.2.37';
Readonly::Scalar our $ahClientVLAN => '.1.3.6.1.4.1.26928.1.1.1.1.2.38';
Readonly::Scalar our $ahClientUserProfId => '.1.3.6.1.4.1.26928.1.1.1.1.2.39';
Readonly::Scalar our $ahClientChannel => '.1.3.6.1.4.1.26928.1.1.1.1.2.40';
Readonly::Scalar our $ahClientCWPUsed => '.1.3.6.1.4.1.26928.1.1.1.1.2.41';
Readonly::Scalar our $ahBSSID => '.1.3.6.1.4.1.26928.1.1.1.1.2.42';
Readonly::Scalar our $ahAssociationTime => '.1.3.6.1.4.1.26928.1.1.1.1.2.48';
Readonly::Scalar our $ahIfName => '.1.3.6.1.4.1.26928.1.1.1.1.2.69';
Readonly::Scalar our $ahIDPRSSI => '.1.3.6.1.4.1.26928.1.1.1.1.2.18';

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
