package pf::SNMP::Enterasys;

=head1 NAME

pf::SNMP::Enterasys - Object oriented module to access SNMP enabled 
Enterasys switches

=head1 SYNOPSIS

The pf::SNMP::Enterasys module implements an object oriented interface
to access SNMP enabled Enterasys switches.

=cut

use strict;
use warnings;

use base ('pf::SNMP');
use POSIX;
use Log::Log4perl;
use Net::SNMP;

use pf::SNMP::constants;
use pf::util;

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( $trapString
        =~ /\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) =/
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } elsif ( $trapString
        =~ /\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.5624\.1\.2\.31\.1\.0\.1\|\.1\.3\.6\.1\.2\.1\.17\.7\.1\.2\.2\.1\.2\.(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d+) = INTEGER: /
        )
    {
        $trapHashRef->{'trapType'}      = 'mac';
        $trapHashRef->{'trapOperation'} = 'learnt';
        $trapHashRef->{'trapIfIndex'}   = $1;
        $trapHashRef->{'trapVlan'}      = $this->getVlan($1);
        $trapHashRef->{'trapMac'}       = lc(
            sprintf(
                "%02X:%02X:%02X:%02X:%02X:%02X", $2, $3, $4, $5, $6, $7
            )
        );
    } elsif ( $trapString
        =~ /\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.5624\.1\.2\.21\.1\.[01]\.1\|\.1\.3\.6\.1\.4\.1\.5624\.1\.2\.21\.1\.2\.1\.1\.4\.(\d+) = $SNMP::MAC_ADDRESS_FORMAT/) {

        $trapHashRef->{'trapType'}    = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($2);
        $trapHashRef->{'trapVlan'} = $this->getVlan( $trapHashRef->{'trapIfIndex'} );

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return $this->_setVlanByOnlyModifyingPvid( $ifIndex, $newVlan, $oldVlan,
        $switch_locker_ref );
}

sub isLearntTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return 0;
}

sub isPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    #ENTERASYS-MAC_LOCKING-MIB
    my $OID_etsysMACLockingSystemEnable = '1.3.6.1.4.1.5624.1.2.21.1.1.1';
    my $OID_etsysMACLockingEnable       = '1.3.6.1.4.1.5624.1.2.21.1.2.1.1.2';
    my $OID_etsysMACLockingViolationEnable
        = '1.3.6.1.4.1.5624.1.2.21.1.2.1.1.3';

    if ( !$this->connectRead() ) {
        return 0;
    }

    #determine if port security is enabled
    $logger->trace(
        "SNMP get_request for etsysMACLocking variables: $OID_etsysMACLockingSystemEnable.0, $OID_etsysMACLockingEnable.$ifIndex, $OID_etsysMACLockingViolationEnable.$ifIndex"
    );
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [
            "$OID_etsysMACLockingSystemEnable.0",
            "$OID_etsysMACLockingEnable.$ifIndex",
            "$OID_etsysMACLockingViolationEnable.$ifIndex"
        ]
    );
    return (
        exists( $result->{"$OID_etsysMACLockingSystemEnable.0"} )
            && ( $result->{"$OID_etsysMACLockingSystemEnable.0"} ne
            'noSuchInstance' )
            && ( $result->{"$OID_etsysMACLockingSystemEnable.0"} ne
            'noSuchObject' )
            && ( $result->{"$OID_etsysMACLockingSystemEnable.0"} == 1 )
            && exists( $result->{"$OID_etsysMACLockingEnable.$ifIndex"} )
            && ( $result->{"$OID_etsysMACLockingEnable.$ifIndex"} ne
            'noSuchInstance' )
            && ( $result->{"$OID_etsysMACLockingEnable.$ifIndex"} ne
            'noSuchObject' )
            && ( $result->{"$OID_etsysMACLockingEnable.$ifIndex"} == 1 )
            && exists(
            $result->{"$OID_etsysMACLockingViolationEnable.$ifIndex"}
            )
            && ( $result->{"$OID_etsysMACLockingViolationEnable.$ifIndex"} ne
            'noSuchInstance' )
            && ( $result->{"$OID_etsysMACLockingViolationEnable.$ifIndex"} ne
            'noSuchObject' )
            && (
            $result->{"$OID_etsysMACLockingViolationEnable.$ifIndex"} == 1 )
    );
}

sub getMaxMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return -1;
    }

    if ( !$this->isPortSecurityEnabled($ifIndex) ) {
        return -1;
    }

    my $OID_etsysMACLockingStaticStationsAllocated
        = '1.3.6.1.4.1.5624.1.2.21.1.2.1.1.8';

    #determine max number of MAC addresses allowed
    $logger->trace(
        "SNMP get_request for etsysMACLockingStaticStationsAllocated: $OID_etsysMACLockingStaticStationsAllocated.$ifIndex"
    );
    my $result = $this->{_sessionRead}->get_request( -varbindlist =>
            [ "$OID_etsysMACLockingStaticStationsAllocated.$ifIndex" ] );
    if ((   !exists(
                $result->{
                    "$OID_etsysMACLockingStaticStationsAllocated.$ifIndex"}
            )
        )
        || ( $result->{"$OID_etsysMACLockingStaticStationsAllocated.$ifIndex"}
            eq 'noSuchInstance' )
        )
    {
        $logger->error(
            "ERROR: could not obtain etsysMACLockingStaticStationsAllocated");
        return -1;
    }
    return $result->{"$OID_etsysMACLockingStaticStationsAllocated.$ifIndex"};
}

sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_etsysMACLockingStaticEntryRowStatus
        = '1.3.6.1.4.1.5624.1.2.21.1.3.1.1.2';

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my @oid_value;
    if ($deauthMac) {
        my @macArray = split( /:/, $deauthMac );
        my $completeOid
            = $OID_etsysMACLockingStaticEntryRowStatus . "." . $ifIndex;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 6 );
    }
    if ($authMac) {
        my @macArray = split( /:/, $authMac );
        my $completeOid
            = $OID_etsysMACLockingStaticEntryRowStatus . "." . $ifIndex;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 4 );
    }

    if ( scalar(@oid_value) > 0 ) {
        $logger->trace(
            "SNMP set_request for etsysMACLockingStaticEntryRowStatus");
        my $result = $this->{_sessionWrite}
            ->set_request( -varbindlist => \@oid_value );
    }
    return 1;
}

sub getAllSecureMacAddresses {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_etsysMACLockingStaticEntryRowStatus
        = '1.3.6.1.4.1.5624.1.2.21.1.3.1.1.2';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for etsysMACLockingStaticEntryRowStatus: $OID_etsysMACLockingStaticEntryRowStatus"
    );
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$OID_etsysMACLockingStaticEntryRowStatus" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$OID_etsysMACLockingStaticEntryRowStatus\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $2, $3, $4, $5, $6, $7 );
            my $ifIndex = $1;
            my $oldVlan = $this->getVlan($ifIndex);
            push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $oldVlan;
        }
    }
    return $secureMacAddrHashRef;
}

sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_etsysMACLockingStaticEntryRowStatus
        = '1.3.6.1.4.1.5624.1.2.21.1.3.1.1.2';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for etsysMACLockingStaticEntryRowStatus: $OID_etsysMACLockingStaticEntryRowStatus"
    );
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$OID_etsysMACLockingStaticEntryRowStatus" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$OID_etsysMACLockingStaticEntryRowStatus\.$ifIndex\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $1, $2, $3, $4, $5, $6 );
            my $oldVlan = $this->getVlan($ifIndex);
            push @{ $secureMacAddrHashRef->{$oldMac} }, $oldVlan;
        }
    }
    return $secureMacAddrHashRef;
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
