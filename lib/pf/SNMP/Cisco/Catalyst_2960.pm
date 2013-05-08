package pf::SNMP::Cisco::Catalyst_2960;

=head1 NAME

pf::SNMP::Cisco::Catalyst_2960 - Object oriented module to access and configure Cisco Catalyst 2960 switches

=head1 STATUS

=over

=item Supports

=over

=item 802.1X with or without VoIP

=item Port-Security with or without VoIP

=item Link Up / Link Down

=item Stacked configuration

=back

=item Firmware version

Recommended firmware is 12.2(58)SE1

The absolute minimum required firmware version is 12.2(25)SEE2.

Port-security + VoIP mode works with firmware 12.2(44)SE or greater unless mentioned below.
Earlier IOS were not explicitly tested.

=back

This module extends pf::SNMP::Cisco::Catalyst_2950.

=head1 PRODUCT LINES

=over

=item 2960, 2960S, 2960G

With no limitations that we are aware of.

=item 2960 LanLite

The LanLite series doesn't support the fallback VLAN on RADIUS AAA based
approaches (MAC-Auth, 802.1X). This can affect fail-open scenarios.

=back

=head1 BUGS AND LIMITATIONS

=over

=item Port-Security

=over

=item Status with IOS 15.x

At the moment we faced regressions with the Cisco IOS 15.x series. Not a lot
of investigation was performed but at this point consider this series as 
broken with a Port-Security based configuration. At this moment, we recommend
users who cannot use another IOS to configure their switch to do MAC 
Authentication instead (called MAC Authentication Bypass or MAB in Cisco's
terms) or get in touch with us so we can investigate further.

=item Problematic firmwares

12.2(50)SE, 12.2(55)SE were reported as malfunctioning for Port-Security operation.
Avoid these IOS.

12.2(44)SE6 is not sending security violation traps in a specific situation: 
if a given MAC is authorized on a port/VLAN, no trap is sent if the device changes port
if the target port has the same VLAN as where the MAC was first authorized.
Without a security violation trap PacketFence can't authorize the port leaving the MAC unauthorized.
Avoid this IOS.

=item Delays sending security violation traps 

Several IOS are affected by a bug that causes the security violation traps to take a long time before being sent.

In our testing, only the first traps were slow to come, the following were fast enough for a proper operation.
So although in testing they can feel like they are broken, once installed and active in the field these IOS are Ok.
Get in touch with us if you can reproduce a problematic behavior reliably and we will revisit our suggestion.

Known affected IOS: 12.2(44)SE2, 12.2(44)SE6, 12.2(52)SE, 12.2(53)SE1, 12.2(55)SE3

Known fixed IOS: 12.2(58)SE1

=back

=item Port-Security with Voice over IP (VoIP)

=over

=item Security table corruption issues with firmwares 12.2(46)SE or greater and PacketFence before 2.2.1

Several firmware releases have an SNMP security table corruption bug that happens only when VoIP devices are involved.

Although a Cisco problem we developed a workaround in PacketFence 2.2.1 that requires switch configuration changes.
Read the UPGRADE guide under 'Upgrading to a version prior to 2.2.1' for more information.

Firmware versions 12.2(44)SE6 or below should not upgrade their configuration.

Affected firmwares includes at least 12.2(46)SE, 12.2(52)SE, 12.2(53)SE1, 12.2(55)SE1, 12.2(55)SE3 and 12.2(58)SE1.

=item 12.2(25r) disappearing config

For some reason when securing a MAC address the switch loses an important portion of its config.
This is a Cisco bug, nothing much we can do. Don't use this IOS for VoIP.
See issue #1020 for details.

=back

=item SNMPv3

12.2(52) doesn't work in SNMPv3

=back

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;

use base ('pf::SNMP::Cisco::Catalyst_2950');
use pf::config;
use pf::SNMP::constants;
use pf::util;

sub description { 'Cisco Catalyst 2960' }

# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
# VoIP technology supported
sub supportsRadiusVoip { return $TRUE; }
# override 2950's FALSE
sub supportsRadiusDynamicVlanAssignment { return $TRUE; }

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut
sub getMinOSVersion {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return '12.2(25)SEE2';
}

sub getAllSecureMacAddresses {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrRowStatus: $oid_cpsIfVlanSecureMacAddrRowStatus"
    );
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsIfVlanSecureMacAddrRowStatus" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsIfVlanSecureMacAddrRowStatus\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $2, $3, $4, $5, $6, $7 );
            my $oldVlan = $8;
            my $ifIndex = $1;
            push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $oldVlan;
        }
    }

    return $secureMacAddrHashRef;
}

sub isDynamicPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsIfVlanSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.3.1.3';

    if ( !$this->connectRead() ) {
        return 0;
    }
    if ( !$this->isPortSecurityEnabled($ifIndex) ) {
        $logger->debug("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrType: $oid_cpsIfVlanSecureMacAddrType"
    );
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsIfVlanSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if (   ( $result->{$oid_including_mac} == 1 )
            || ( $result->{$oid_including_mac} == 3 ) )
        {
            return 0;
        }
    }

    return 1;
}

sub isStaticPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsIfVlanSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.3.1.3';

    if ( !$this->connectRead() ) {
        return 0;
    }
    if ( !$this->isPortSecurityEnabled($ifIndex) ) {
        $logger->info("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrType: $oid_cpsIfVlanSecureMacAddrType"
    );
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsIfVlanSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if (   ( $result->{$oid_including_mac} == 1 )
            || ( $result->{$oid_including_mac} == 3 ) )
        {
            return 1;
        }
    }

    return 0;
}

sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrRowStatus: $oid_cpsIfVlanSecureMacAddrRowStatus"
    );
    my $result = $this->{_sessionRead}->get_table(
        -baseoid => "$oid_cpsIfVlanSecureMacAddrRowStatus.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsIfVlanSecureMacAddrRowStatus\.$ifIndex\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $1, $2, $3, $4, $5, $6 );
            my $oldVlan = $7;
            push @{ $secureMacAddrHashRef->{$oldMac} }, int($oldVlan);
        }
    }

    return $secureMacAddrHashRef;
}

sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    # We will assemble the SNMP set request in this array and do it all in one pass
    my @oid_value;
    if ($deauthMac) {
        $logger->trace("Adding a cpsIfVlanSecureMacAddrRowStatus DESTROY to the set request");
        my $oid = "$oid_cpsIfVlanSecureMacAddrRowStatus.$ifIndex." . mac2oid($deauthMac) . ".$deauthVlan";
        push @oid_value, ($oid, Net::SNMP::INTEGER, $SNMP::DESTROY);
    }
    if ($authMac) {
        $logger->trace("Adding a cpsIfVlanSecureMacAddrRowStatus CREATE_AND_GO to the set request");
        # Warning: placing in deauthVlan instead of authVlan because authorization happens before VLAN change
        my $oid = "$oid_cpsIfVlanSecureMacAddrRowStatus.$ifIndex." . mac2oid($authMac) . ".$deauthVlan";
        push @oid_value, ($oid, Net::SNMP::INTEGER, $SNMP::CREATE_AND_GO);
    }
    if (@oid_value) {
        $logger->trace("SNMP set_request for cpsIfVlanSecureMacAddrRowStatus");
        my $result = $this->{_sessionWrite}->set_request(-varbindlist => \@oid_value);
        if (!defined($result)) {
            $logger->warn(
                "SNMP error tyring to remove or add secure rows to ifIndex $ifIndex in port-security table. "
                . "This could be normal. Error message: ".$this->{_sessionWrite}->error()
            );
        }
    }
    return 1;
}

=item dot1xPortReauthenticate

Points to pf::SNMP implementation bypassing Catalyst_2950's overridden behavior.

=cut
sub dot1xPortReauthenticate {
    my ($this, $ifIndex) = @_;

    return $this->_dot1xPortReauthenticate($ifIndex);
}

=item NasPortToIfIndex

Translate RADIUS NAS-Port into switch's ifIndex.

=cut
sub NasPortToIfIndex {
    my ($this, $NAS_port) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # ex: 50023 is ifIndex 10023
    if ($NAS_port =~ s/^5/1/) {
        return $NAS_port;
    } else {
        $logger->warn("Unknown NAS-Port format. ifIndex translation could have failed. "
            ."VLAN re-assignment and switch/port accounting will be affected.");
    }
    return $NAS_port;
}

=item getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut
sub getVoipVsa {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    return ('Cisco-AVPair' => "device-traffic-class=voice");
}

=back

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
