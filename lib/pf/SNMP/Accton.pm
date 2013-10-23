package pf::SNMP::Accton;

=head1 NAME

pf::SNMP::Accton - Object oriented module to access SNMP enabled Accton switches

=head1 SYNOPSIS

The pf::SNMP::Accton module implements an object oriented interface
to access SNMP enabled Accton switches.

=cut

use strict;
use warnings;

use base ('pf::SNMP');
use Log::Log4perl;
use Net::SNMP;

sub getVersion {
    my ($this)          = @_;
    my $oid_swOpCodeVer = '1.3.6.1.4.1.259.6.10.74.1.1.3.1.6.1';
    my $logger          = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for swOpCodeVer: $oid_swOpCodeVer");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => [$oid_swOpCodeVer] );
    if ( exists( $result->{$oid_swOpCodeVer} )
        && ( $result->{$oid_swOpCodeVer} ne 'noSuchInstance' ) )
    {
        return $result->{$oid_swOpCodeVer};
    }
    return '';
}

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( $trapString
        =~ /^BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = INTEGER: \d+ END VARIABLEBINDINGS$/
        )
    {

        #trap in 'old' firmware release
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } elsif ( $trapString
        =~ /^BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = INTEGER: \d+\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.7\.\d+ = INTEGER: [^|]+\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.8\.\d+ = INTEGER: [^)]+\) END VARIABLEBINDINGS/
        )
    {

        #trap in 'new' firmware release
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } elsif ( $trapString
        =~ /BEGIN VARIABLEBINDINGS .+\|\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) =/
        )
    {

        #trap in 'newest' firmware release
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } else {
        $logger->info("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub getTrunkPorts {
    my ($this) = @_;
    my $OID_vlanPortMode = '1.3.6.1.4.1.259.6.10.74.1.12.2.1.2';
    my @trunkPorts;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return -1;
    }
    $logger->trace("SNMP get_table for vlanPortMode: $OID_vlanPortMode");
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_vlanPortMode );
    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            if ( $result->{$key} == 2 ) {
                $key =~ /^$OID_vlanPortMode\.(\d+)$/;
                push @trunkPorts, $1;
                $logger->info( "Switch " . $this->{_id} . " trunk port: $1" );
            }
        }
    } else {
        $logger->error(
            "Problem while reading vlanPortMode for switch " . $this->{_id} );
        return -1;
    }
    return @trunkPorts;
}

sub getUpLinks {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @upLinks;

    if ( lc(@{ $this->{_uplink} }[0]) eq 'dynamic' ) {
        @upLinks = $this->getTrunkPorts();
    } else {
        @upLinks = @{ $this->{_uplink} };
    }
    return @upLinks;
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
    my $id = $this->{_id};
    $logger->trace( "locking - trying to lock \$switch_locker{$id} in _setVlan" );
    {
        lock %{ $switch_locker_ref->{ $id } };
        $logger->trace( "locking - \$switch_locker{$id} locked in _setVlan" );

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
            "SNMP set_request for egressPorts, untaggedPorts and Pvid for new vlan"
        );
        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                Net::SNMP::OCTET_STRING,
                $egressPortsVlan,
                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan",
                Net::SNMP::OCTET_STRING,
                $untaggedPortsVlan,
                "$OID_dot1qPvid.$dot1dBasePort",
                Net::SNMP::GAUGE32,
                $newVlan
            ]
        );
        if ( !defined($result) ) {
            $logger->error(
                "error setting egressPorts, untaggedPorts and Pvid for new vlan: "
                    . $this->{_sessionWrite}->error );
        }

        $logger->trace(
            "SNMP set_request for egressPorts, untaggedPorts for old vlan");
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
            $logger->error(
                "error setting egressPorts, untaggedPorts for old vlan: "
                    . $this->{_sessionWrite}->error );
        }
    }
    $logger->trace( "locking - \$switch_locker{$id} unlocked in _setVlan" );
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
