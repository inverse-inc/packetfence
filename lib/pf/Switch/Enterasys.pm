package pf::Switch::Enterasys;

=head1 NAME

pf::Switch::Enterasys - Object oriented module to access SNMP enabled 
Enterasys switches

=head1 SYNOPSIS

The pf::Switch::Enterasys module implements an object oriented interface
to access SNMP enabled Enterasys switches.

=cut

use strict;
use warnings;

use base ('pf::Switch');
use POSIX;
use Net::SNMP;

use pf::Switch::constants;
use pf::util;

#
# %TRAP_NORMALIZERS
# A hash of Enterasys trap normalizers
# Use the following convention when adding a normalizer
# <nameOfTrapNotificationType>TrapNormalizer
#
our %TRAP_NORMALIZERS = (
    '.1.3.6.1.4.1.5624.1.2.21.1.0.1' => 'etsysMACLockingMACViolationTrapNormalizer',
    '.1.3.6.1.4.1.5624.1.2.21.1.1.1' => 'etsysMACLockingSystemEnableTrapNormalizer',
);

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;
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
        $trapHashRef->{'trapVlan'}      = $self->getVlan($1);
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
        $trapHashRef->{'trapVlan'} = $self->getVlan( $trapHashRef->{'trapIfIndex'} );

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;
    return $self->_setVlanByOnlyModifyingPvid( $ifIndex, $newVlan, $oldVlan,
        $switch_locker_ref );
}

sub isLearntTrapsEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    return 0;
}

sub isPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    #ENTERASYS-MAC_LOCKING-MIB
    my $OID_etsysMACLockingSystemEnable = '1.3.6.1.4.1.5624.1.2.21.1.1.1';
    my $OID_etsysMACLockingEnable       = '1.3.6.1.4.1.5624.1.2.21.1.2.1.1.2';
    my $OID_etsysMACLockingViolationEnable
        = '1.3.6.1.4.1.5624.1.2.21.1.2.1.1.3';

    if ( !$self->connectRead() ) {
        return 0;
    }

    #determine if port security is enabled
    $logger->trace(
        "SNMP get_request for etsysMACLocking variables: $OID_etsysMACLockingSystemEnable.0, $OID_etsysMACLockingEnable.$ifIndex, $OID_etsysMACLockingViolationEnable.$ifIndex"
    );
    my $result = $self->{_sessionRead}->get_request(
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
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return -1;
    }

    if ( !$self->isPortSecurityEnabled($ifIndex) ) {
        return -1;
    }

    my $OID_etsysMACLockingStaticStationsAllocated
        = '1.3.6.1.4.1.5624.1.2.21.1.2.1.1.8';

    #determine max number of MAC addresses allowed
    $logger->trace(
        "SNMP get_request for etsysMACLockingStaticStationsAllocated: $OID_etsysMACLockingStaticStationsAllocated.$ifIndex"
    );
    my $result = $self->{_sessionRead}->get_request( -varbindlist =>
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
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = $self->logger;

    my $OID_etsysMACLockingStaticEntryRowStatus
        = '1.3.6.1.4.1.5624.1.2.21.1.3.1.1.2';

    if ( !$self->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    if ( !$self->connectWrite() ) {
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
        my $result = $self->{_sessionWrite}
            ->set_request( -varbindlist => \@oid_value );
    }
    return 1;
}

sub getAllSecureMacAddresses {
    my ($self) = @_;
    my $logger = $self->logger;
    my $OID_etsysMACLockingStaticEntryRowStatus
        = '1.3.6.1.4.1.5624.1.2.21.1.3.1.1.2';

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for etsysMACLockingStaticEntryRowStatus: $OID_etsysMACLockingStaticEntryRowStatus"
    );
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$OID_etsysMACLockingStaticEntryRowStatus" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$OID_etsysMACLockingStaticEntryRowStatus\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $2, $3, $4, $5, $6, $7 );
            my $ifIndex = $1;
            my $oldVlan = $self->getVlan($ifIndex);
            push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $oldVlan;
        }
    }
    return $secureMacAddrHashRef;
}

sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $OID_etsysMACLockingStaticEntryRowStatus
        = '1.3.6.1.4.1.5624.1.2.21.1.3.1.1.2';

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for etsysMACLockingStaticEntryRowStatus: $OID_etsysMACLockingStaticEntryRowStatus"
    );
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$OID_etsysMACLockingStaticEntryRowStatus" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$OID_etsysMACLockingStaticEntryRowStatus\.$ifIndex\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $1, $2, $3, $4, $5, $6 );
            my $oldVlan = $self->getVlan($ifIndex);
            push @{ $secureMacAddrHashRef->{$oldMac} }, $oldVlan;
        }
    }
    return $secureMacAddrHashRef;
}

sub etsysMACLockingMACViolationTrapNormalizer {
    my ($self, $trapInfo) = @_;
    my ($pdu, $variables) = @$trapInfo;
    my $logger = $self->logger;
    my $oid = '.1.3.6.1.4.1.5624.1.2.21.1.2.1.1.4.';
    my ($variable) = $self->findTrapVarWithBase($variables, $oid);
    return undef unless $variable;
    unless ($variable) {
        $logger->error("Cannot find OID $oid in trap");
        return undef;
    }
    my $trapMac = $self->extractMacFromVariable($variable);
    unless ($trapMac) {
        $logger->error("Cannot extract a mac address from OID $oid");
        return undef;
    }
    unless ($variable->[0] =~ /^\Q$oid\E(\d+)$/) {
        $logger->error("Cannot extract the board and port index from $variable->[0]");
        return undef;
    }
    my $trapIfIndex = $1;
    return {
        trapType => 'secureMacAddrViolation',
        trapMac => $trapMac,
        trapIfIndex => $trapIfIndex,
        trapVlan => $self->getVlan($trapIfIndex),
    };
}

sub etsysMACLockingSystemEnableTrapNormalizer {
    my ($self, $trapInfo) = @_;
    return $self->etsysMACLockingSystemEnableTrapNormalizer($trapInfo);
}

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
