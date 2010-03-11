package pf::SNMP::Foundry;

=head1 NAME

pf::SNMP::Foundry - Object oriented module to access SNMP enabled 
Foundry switches

=head1 SYNOPSIS

The pf::SNMP::Foundry module implements an object oriented interface
to access SNMP enabled Foundry switches.

=head1 BUGS AND LIMITATIONS

The isDefinedVlan function currently always returns true since I
couldn't find an easy way to determine (using SNMP) if a given
VLAN is defined or not ... VLANs which don't have ports assigned to
them simply don't seem to appear using SNMP

=head1 STATUS

Currently only supports linkUp / linkDown mode

Developed and tested on FastIron 4802 running on image version 07.8.04aT53

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use POSIX;
use Log::Log4perl;
use Net::SNMP;


sub getVersion {
    my ($this)       = @_;
    my $oid_snAgImgVer = '1.3.6.1.4.1.1991.1.1.2.1.11.0';
    my $logger       = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for snAgImgVer: $oid_snAgImgVer");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [$oid_snAgImgVer] );
    return ( $result->{$oid_snAgImgVer} || '');
}

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
    } elsif ( $trapString =~ /\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.1991\.0\.77\|\.1\.3\.6\.1\.4\.1\.1991\.1\.1\.2\.1\.44\.0 = STRING: "Security: Port security violation at interface ethernet (\d+), address ([0-9A-Fa-f]{2})([0-9A-Fa-z]{2})\.([0-9A-Fa-f]{2})([0-9A-Fa-z]{2})\.([0-9A-Fa-f]{2})([0-9A-Fa-z]{2}), vlan (\d+)/ ) {
        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapMac'} = lc("$2:$3:$4:$5:$6:$7");
        $trapHashRef->{'trapVlan'} = $8;
    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub isDefinedVlan {
    my ( $this, $vlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    # TODO ideally we should implement that
    $logger->debug("isDefinedVlan called for Foundry switch. "
                   . "returning true even though we don't know !");
    return 1;
}

sub getVlans {
    my ($this)                   = @_;
    my $vlans                    = {};
    my $oid_snVLanByPortVLanName = '1.3.6.1.4.1.1991.1.1.3.2.1.1.25';

    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return $vlans;
    }

    $logger->trace("SNMP get_request for snVlanByPortVlanName: "
                    . $oid_snVLanByPortVLanName);
    my $result = $this->{_sessionRead}->get_table(
            -baseoid => $oid_snVLanByPortVLanName
        );
    if ( defined($result) ) {
        foreach my $key ( keys %{$result} )
        {
            $key =~ /^$oid_snVLanByPortVLanName\.(\d+)$/;
            $vlans->{$1} = $result->{$key};
        }
    } else {
        $logger->info( "result is not defined at switch "
                .  $this->{_ip});
    }
    return $vlans;
}


sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $OID_snVLanByPortMemberRowStatus = '1.3.6.1.4.1.1991.1.1.3.2.6.1.3';
    $logger->trace("SNMP set_request for snVlanByPortMemberRowStatus: "
                   . $OID_snVLanByPortMemberRowStatus);
    my $result;
    if ($newVlan == 1) {
        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                 "$OID_snVLanByPortMemberRowStatus.$oldVlan.$ifIndex",
                 Net::SNMP::INTEGER,
                 3 ]
            );
    } elsif ($oldVlan == 1) {
        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                 "$OID_snVLanByPortMemberRowStatus.$newVlan.$ifIndex",
                 Net::SNMP::INTEGER,
                 4 ]
            );
    } else {
        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                 "$OID_snVLanByPortMemberRowStatus.$oldVlan.$ifIndex",
                 Net::SNMP::INTEGER,
                 3,
                 "$OID_snVLanByPortMemberRowStatus.$newVlan.$ifIndex",
                 Net::SNMP::INTEGER,
                 4 ]
            );
    }
    return (defined($result));
}

sub isLearntTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return 0;
}

sub isPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return 0;
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
}

=head1 BUGS AND LIMITATIONS
    
You cannot run a network with VLAN 1 as your normal VLAN with these switches.
 
SNMPv3 support was not tested.

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009,2010 Inverse inc.

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
