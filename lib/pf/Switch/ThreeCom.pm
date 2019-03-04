package pf::Switch::ThreeCom;

=head1 NAME

pf::Switch::ThreeCom - Object oriented module to access SNMP enabled 3COM
switches

=head1 SYNOPSIS

The pf::Switch::ThreeCom module implements an object oriented interface
to access SNMP enabled 3COM switches.

=cut

use strict;
use warnings;

use base ('pf::Switch');
use Net::SNMP;

use pf::Switch::constants;
use pf::util;

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;
    if ( $trapString
        =~ /BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.2\.(\d+) = /
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } elsif ( $trapString
        =~ /BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = /
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    } elsif ( $trapString =~ /BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.([0-9]+) = INTEGER: [0-9]+\|\.1\.3\.6\.1\.4\.1\.43\.45\.1\.10\.2\.26\.1\.2\.2\.1\.1\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.(\d+) = $SNMP::MAC_ADDRESS_FORMAT/ ) {

        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapVlan'} = $2;
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($3);

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub getDot1dBasePortForThisIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger                   = $self->logger;
    my $ifIndexDot1dBasePortHash = {
        102 => 1,
        103 => 2,
        104 => 3,
        105 => 4
    };
    return $ifIndexDot1dBasePortHash->{$ifIndex};

}

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;
    return $self->_setVlanByOnlyModifyingPvid( $ifIndex, $newVlan, $oldVlan, $switch_locker_ref );
}

sub _getMacAtIfIndex {
    my ( $self, $ifIndex, $vlan ) = @_;
    my $logger = $self->logger;
    my @macArray;
    if ( !$self->connectRead() ) {
        return @macArray;
    }
    my %macBridgePortHash = $self->getMacBridgePortHash();
    my $dot1dBasePort     = $self->getDot1dBasePortForThisIfIndex($ifIndex);
    foreach my $_mac ( keys %macBridgePortHash ) {
        if ( $macBridgePortHash{$_mac} eq $dot1dBasePort ) {
            push @macArray, lc($_mac);
        }
    }
    return @macArray;
}

sub getIfIndexByNasPortId {
    my ($self, $ifDesc_param) = @_;
    my $logger = $self->logger;

    if ( !$self->connectRead() || !defined($ifDesc_param)) {
        return 0;
    }
    if ($ifDesc_param =~ /(unit|slot)=(\d+);subslot=(\d+);port=(\d+)/) {
        my $unit = $2;
        my $subslot = $3;
        my $port = $4;
        my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';
        my $ifDescHashRef;
        my $result = $self->cachedSNMPTable([-baseoid => $OID_ifDesc]);
        foreach my $key ( keys %{$result} ) {
            my $ifDesc = $result->{$key};
            if ( $ifDesc =~ /(GigabitEthernet|Ten-GigabitEthernet|Ethernet)$unit\/$subslot\/$port$/i ) {
                $key =~ /^$OID_ifDesc\.(\d+)$/;
                return $1;
            }
        }
    }
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
