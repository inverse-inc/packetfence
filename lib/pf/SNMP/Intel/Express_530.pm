package pf::SNMP::Intel::Express_530;

=head1 NAME

pf::SNMP::Intel::Express_530 - Object oriented module to access SNMP enabled Intel Express 530 switches

=head1 SYNOPSIS

The pf::SNMP::Intel::Express_530 module implements an object oriented interface
to access SNMP enabled Intel Express 530 switches.

The minimum required firmware version is 1.00.23.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Data::Dumper;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::Intel');

sub description { 'Intel Express 530' }

sub getMinOSVersion {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return '1.00.23';
}

sub getVersion {
    my ($this) = @_;
    my $oid_es530AgentRuntimeSwVersion = '1.3.6.1.4.1.343.6.63.1.1.1.0';
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace(
        "SNMP get_request for es530AgentRuntimeSwVersion: $oid_es530AgentRuntimeSwVersion"
    );
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => [$oid_es530AgentRuntimeSwVersion] );
    my $runtimeSwVersion
        = ( $result->{$oid_es530AgentRuntimeSwVersion} || '' );
    if ( $runtimeSwVersion =~ m/v(\d{1}\.\d{2}\.\d{2})/ ) {
        return $1;
    } else {
        return $runtimeSwVersion;
    }
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

    my $dot1dBasePort = $this->getDot1dBasePortForThisIfIndex($ifIndex);
    if ( !defined($dot1dBasePort) ) {
        return 0;
    }

    $logger->trace( "locking - trying to lock \$switch_locker{"
            . $this->{_id}
            . "} in _setVlan" );
    {
        lock %{ $switch_locker_ref->{ $this->{_id} } };
        $logger->trace( "locking - \$switch_locker{"
                . $this->{_id}
                . "} locked in _setVlan" );

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

        # calculate new settings
        my $egressPortsOldVlan
            = $this->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"},
            $ifIndex - 1, 0 );
        my $egressPortsVlan
            = $this->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"},
            $ifIndex - 1, 1 );
        my $untaggedPortsOldVlan
            = $this->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticUntaggedPorts.$oldVlan"},
            $ifIndex - 1, 0 );
        my $untaggedPortsVlan
            = $this->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"},
            $ifIndex - 1, 1 );
        $this->{_sessionRead}->translate(1);

        # set all values
        if ( !$this->connectWrite() ) {
            return 0;
        }
        $logger->trace(
            "SNMP set_request for dot1qPvid, dot1qVlanStaticUntaggedPorts and dot1qVlanStaticEgressPorts"
        );
        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_dot1qPvid.$dot1dBasePort",
                Net::SNMP::INTEGER,
                $newVlan,
                "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
                Net::SNMP::OCTET_STRING,
                $untaggedPortsOldVlan,
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                Net::SNMP::OCTET_STRING,
                $egressPortsOldVlan,
                "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                Net::SNMP::OCTET_STRING,
                $egressPortsVlan,
                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan",
                Net::SNMP::OCTET_STRING,
                $untaggedPortsVlan
            ]
        );

        if ( !defined($result) ) {
            $logger->error(
                "error setting VLAN: " . $this->{_sessionWrite}->error );
        }
    }
    $logger->trace( "locking - \$switch_locker{"
            . $this->{_id}
            . "} unlocked in _setVlan" );
    return ( defined($result) );

}

sub setAdminStatus {
    my ( $this, $ifIndex, $enabled ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    #obtain unit and module from unique ifIndex
    my $OID_es530HwPortEncodingFactor = '1.3.6.1.4.1.343.6.63.2.1.3.0';
    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for es530HwPortEncodingFactor: $OID_es530HwPortEncodingFactor"
    );
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_es530HwPortEncodingFactor"] );
    my $es530PortEncodingFactor = $result->{"$OID_es530HwPortEncodingFactor"};
    my $es530PortCtrlUnitIndex
        = 1 + int( $ifIndex / $es530PortEncodingFactor );
    my $es530PortCtrlModuleIndex = 1;
    my $es530PortCtrlIndex       = $ifIndex % $es530PortEncodingFactor;
    if ( $es530PortCtrlIndex == 0 ) {
        $es530PortCtrlIndex = $es530PortEncodingFactor;
        $es530PortCtrlUnitIndex -= 1;
    }

    my $OID_es530PortCtrlAdminState = '1.3.6.1.4.1.343.6.63.3.4.2.1.4';
    if ( !$this->connectWrite() ) {
        return 0;
    }
    $logger->trace(
        "SNMP set_request for es530PortCtrlAdminState: $OID_es530PortCtrlAdminState"
    );
    $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_es530PortCtrlAdminState.$es530PortCtrlUnitIndex.$es530PortCtrlModuleIndex.$es530PortCtrlIndex",
            Net::SNMP::INTEGER,
            ( $enabled ? 3 : 2 ),
        ]
    );
    return ( defined($result) );
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
