#
# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
#
#  Modified for supporting SMC LAN SWITCHES
# Model TigerSwitch 6224M
#
# Mr. Chinasee BOONYATANG 	 	[chinasee.b@psu.ac.th]
#  Prince of Songkla University , Thailand
#  http://netserv.cc.psu.ac.th
#  2009-01-29
#
#

package pf::SNMP::SMC;

=head1 NAME

pf::SNMP::SMC - Object oriented module to access SNMP enabled SMC switches

=head1 SYNOPSIS

The pf::SNMP::SMC module implements an object oriented interface
to access SNMP enabled SMC switches.

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use POSIX;
use Log::Log4perl;
use Data::Dumper;

sub getVersion {
    my ($this) = @_;
    my $OID_swProdVersion = '1.3.6.1.4.1.202.20.43.1.1.5.4.0';    #swProdVersion
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->debug("SNMP get_request for swProdVersion: $OID_swProdVersion");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => [$OID_swProdVersion] );
    return ( $result->{$OID_swProdVersion} || '' );
}

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # link status trap varbind oid = .1.3.6.1.2.1.2.2.1.1.1  /Up

    if ( $trapString
        =~ /BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = /
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticUntaggedPorts
        = '1.3.6.1.2.1.17.7.1.4.3.1.4';                  # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticEgressPorts
        = '1.3.6.1.2.1.17.7.1.4.3.1.2';                  # Q-BRIDGE-MIB
    my $result;

    # get current egress and untagged ports
    $this->{_sessionRead}->translate(0);
    $logger->trace(
        "SNMP get_request for dot1qVlanStaticUntaggedPorts and dot1qVlanStaticEgressPorts"
    );
    $result = $this->{_sessionRead}->get_request(
        -varbindlist => [
            "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
            "$OID_dot1qVlanStaticEgressPorts.$newVlan",
            "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
            "$OID_dot1qVlanStaticUntaggedPorts.$newVlan"
        ]
    );

    my $dot1dBasePort = $this->getDot1dBasePortForThisIfIndex($ifIndex);
    if ( !defined($dot1dBasePort) ) {
        return 0;
    }

    # calculate new settings
    my $egressPortsOldVlan
        = $this->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"},
        $dot1dBasePort - 1, 0 );
    my $egressPortsVlan
        = $this->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"},
        $dot1dBasePort - 1, 1 );
    my $untaggedPortsOldVlan
        = $this->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticUntaggedPorts.$oldVlan"},
        $dot1dBasePort - 1, 0 );
    my $untaggedPortsVlan
        = $this->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"},
        $dot1dBasePort - 1, 1 );
    $this->{_sessionRead}->translate(1);

    # set all values
    if ( !$this->connectWrite() ) {
        return 0;
    }

    $logger->trace(
        "SNMP set_request for egressPorts and untaggedPorts for old and new VLAN "
    );

    #add port to new VLAN untagged & egress
    $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_dot1qVlanStaticEgressPorts.$newVlan",
            Net::SNMP::OCTET_STRING,
            $egressPortsVlan,
            "$OID_dot1qVlanStaticUntaggedPorts.$newVlan",
            Net::SNMP::OCTET_STRING,
            $untaggedPortsVlan,
        ]
    );

    if ( !defined($result) ) {
        print $this->{_sessionWrite}->error . "\n";
        $logger->error(
            "error setting egressPorts and untaggedPorts for old and new vlan: "
                . $this->{_sessionWrite}->error );
    }

    #change port PVID
    $result = $this->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_dot1qPvid.$ifIndex", Net::SNMP::GAUGE32, $newVlan ] );

    if ( !defined($result) ) {
        print $this->{_sessionWrite}->error . "\n";
        $logger->error(
            "error setting egressPorts and untaggedPorts for old and new vlan: "
                . $this->{_sessionWrite}->error );
    }

    #remove port from old VLAN untagged & egress
    $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
            Net::SNMP::OCTET_STRING,
            $untaggedPortsOldVlan,
            "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
            Net::SNMP::OCTET_STRING,
            $egressPortsOldVlan
        ]
    );

    if ( !defined($result) ) {
        print $this->{_sessionWrite}->error . "\n";
        $logger->error(
            "error setting egressPorts and untaggedPorts for old and new vlan: "
                . $this->{_sessionWrite}->error );
    }

    return ( defined($result) );
}

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
