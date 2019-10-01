package pf::Switch::Foundry;

=head1 NAME

pf::Switch::Foundry - Object oriented module to access SNMP enabled
Foundry switches

=head1 SYNOPSIS

The pf::Switch::Foundry module implements an object oriented interface
to access SNMP enabled Foundry switches.

=head1 STATUS

Supports linkUp / linkDown and Port Security modes

Supports IP Telephony

Developed and tested on FastIron 4802 running on image version 04.0.00

=head1 BUGS AND LIMITATIONS

Port security works with an OS version of 4 or greater.

FastIron with a JetCore chipset cannot work in port-security mode (check show version)

You cannot run a network with VLAN 1 as your normal VLAN with these switches.

SNMPv3 support was not tested.

Not so sure how often the security violation traps are sent.
If PacketFence misses the trap you might be out of luck.
We should check with the documentation but I can't find detailed SNMP options right now.

mac-detection VLAN needs to have at least one port where it is tagged on the switch.
Otherwise the VLAN doesn't show up through SNMP and we can't add ports to it.

IP Telephony support requires dual-mode support

=head1 SUBROUTINES

TODO: this list is incomplete

=over

=cut

use strict;
use warnings;

use base ('pf::Switch');
use POSIX;
use Net::SNMP;

use pf::util;
use pf::constants::role qw($VOICE_ROLE);

# snPortMacSecurityIntfMacRowStatus value constants
use constant DELETE => 3;
use constant CREATE => 4;
# snSwIfInfoTagMode value constants
use constant DUAL_MODE => 3;

sub getVersion {
    my ($self)         = @_;
    my $oid_snAgImgVer = '1.3.6.1.4.1.1991.1.1.2.1.11.0';
    my $logger         = $self->logger;

    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for snAgImgVer: $oid_snAgImgVer");
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [$oid_snAgImgVer] );
    return ( $result->{$oid_snAgImgVer} || '');
}

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

    # new linkup / linkdown trap format found with 4.00 OS
    } elsif ($trapString =~ /^BEGIN\ TYPE\ ([23])\                                          # 2=down and 3=up
        END\ TYPE\ BEGIN\ SUBTYPE\ 0\ END\ SUBTYPE\ BEGIN\ VARIABLEBINDINGS\                # nothing of interest
        \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+)\                                              # ifIndex
        =\ INTEGER:\ /x) {
        $trapHashRef->{'trapType'} = ( ($1 == 2) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    # trap has been generalized from previous version to work with 4.00 OS
    # TODO we were told of an 'alternate' trap syntax with x/y/z instead of ifIndex below
    # TODO to calculate ifIndex you need to use: (x-1)256+(y-1)64+z
    } elsif ($trapString =~ /\.1\.3\.6\.1\.4\.1\.1991\.1\.1\.2\.1\.44\.0\ =\              # Notification OID
        STRING:\ "Security:\ Port\ [sS]ecurity\ violation\ at\                            # Trap string
        interface\ ethernet\ (\d+),\ address\                                             # ifIndex
        ([0-9A-Fa-f]{2})([0-9A-Fa-z]{2})\.([0-9A-Fa-f]{2})([0-9A-Fa-z]{2})\.([0-9A-Fa-f]{2})([0-9A-Fa-z]{2}) # MAC
        ,\ vlan\ (\d+)                                                                    # VLAN
        /x ) {
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

=item isDefinedVlan - returns 1 (true) if requested vlan exists or 0 (false) otherwise

=cut

sub isDefinedVlan {
    my ($self, $vlan) = @_;
    my $logger = $self->logger;
    # vlanIfIndex to vlan number (vlan tag)
    my $oid_snVLanByPortVLanId = '1.3.6.1.4.1.1991.1.1.3.2.1.1.2'; #from FOUNDRY-SN-SWITCH-GROUP-MIB

    if (!$self->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_table for snVLanByPortVLanId: $oid_snVLanByPortVLanId");
    my $result = $self->{_sessionRead}->get_table(-baseoid => "$oid_snVLanByPortVLanId");

    # loop on all vlans
    foreach my $vlanIfIndex (keys %{$result}) {
        if ($result->{$vlanIfIndex} == $vlan) {
            return 1;
        }
    }

    $logger->warn("could not find vlan $vlan on this switch");
    return 0;
}

sub getVlans {
    my ($self)                   = @_;
    my $vlans                    = {};
    my $oid_snVLanByPortVLanName = '1.3.6.1.4.1.1991.1.1.3.2.1.1.25';

    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return $vlans;
    }

    $logger->trace("SNMP get_request for snVlanByPortVlanName: "
                    . $oid_snVLanByPortVLanName);
    my $result = $self->{_sessionRead}->get_table(
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
                .  $self->{_ip});
    }
    return $vlans;
}


sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $OID_snVLanByPortMemberRowStatus = '1.3.6.1.4.1.1991.1.1.3.2.6.1.3';
    $logger->trace("SNMP set_request for snVlanByPortMemberRowStatus: " . $OID_snVLanByPortMemberRowStatus);
    my $result;
    if ($newVlan == 1) {
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                 "$OID_snVLanByPortMemberRowStatus.$oldVlan.$ifIndex", Net::SNMP::INTEGER, 3
            ]
        );
    } elsif ($oldVlan == 1) {
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                 "$OID_snVLanByPortMemberRowStatus.$newVlan.$ifIndex", Net::SNMP::INTEGER, 4
            ]
        );
    } else {
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                 "$OID_snVLanByPortMemberRowStatus.$oldVlan.$ifIndex", Net::SNMP::INTEGER, 3,
                 "$OID_snVLanByPortMemberRowStatus.$newVlan.$ifIndex", Net::SNMP::INTEGER, 4
            ]
        );
    }

    # At this point, in my tests, $result is almost always in error state but the operation did work on the switch
    # So don't check the error and move on

    # if we are in port security mode we need to authorize the MAC in the new VLAN (and deauthorize the old stuff)
    # because this switch's port-security secure MAC address table is VLAN aware
    if ($self->isPortSecurityEnabled($ifIndex)) {

        my $auth_result = $self->authorizeCurrentMacWithNewVlan($ifIndex, $newVlan, $oldVlan);
        if (!defined($auth_result) || $auth_result != 1) {
            $logger->warn("couldn't authorize MAC for new VLAN: no secure mac");
        }
    }

    # if VoIP is enabled, we need to play with the dual-mode stuff
    if ($self->isVoIPEnabled()) {
        my $dualmode_result = $self->_setDualModeVlan($ifIndex, $newVlan);
        if (!defined($dualmode_result)) {
            $logger->warn("there was a problem trying to set the correct untagged VLAN for VoIP support");
        }
    }
    return (defined($result));
}

sub isLearntTrapsEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    return 0;
}

sub isPortSecurityEnabled {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    if (!$self->connectRead()) {
        return 0;
    }

    # from FOUNDRY-SN-SWITCH-GROUP-MIB
    my $oid_snPortMacSecurityIntfContentSecurity = "1.3.6.1.4.1.1991.1.1.3.24.1.1.3.1.2";

    #determine if port security is enabled
    $logger->trace("SNMP get_request for snPortMacSecurityIntfContentSecurity: "
        . "$oid_snPortMacSecurityIntfContentSecurity.$ifIndex");

    # snmp request
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [ "$oid_snPortMacSecurityIntfContentSecurity.$ifIndex" ] );

    # validating answer
    my $valid_answer = (defined($result->{"$oid_snPortMacSecurityIntfContentSecurity.$ifIndex"})
        && ($result->{"$oid_snPortMacSecurityIntfContentSecurity.$ifIndex"} ne 'noSuchInstance')
        && ($result->{"$oid_snPortMacSecurityIntfContentSecurity.$ifIndex"} ne 'noSuchObject'));

    # if valid return answer, otherwise assume there's no port-security
    if ($valid_answer) {
        return $result->{"$oid_snPortMacSecurityIntfContentSecurity.$ifIndex"};
    } else {
        $logger->debug("there was a problem grabbing port-security status, it's probably only deactivated");
        return 0;
    }
}

=item getSecureMacAddresses - return all MAC addresses in security table and their VLAN for a given ifIndex

Returns an hashref with MAC => Array(VLANs)

=cut

sub getSecureMacAddresses {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    # from FOUNDRY-SN-SWITCH-GROUP-MIB
    my $oid_snPortMacSecurityIntfMacVlanId = '1.3.6.1.4.1.1991.1.1.3.24.1.1.4.1.3';

    my $secureMacAddrHashRef = {};
    if (!$self->connectRead()) {
        return $secureMacAddrHashRef;
    }

    # fetch the information
    $logger->trace("SNMP get_table for snPortMacSecurityIntfMacVlanId: $oid_snPortMacSecurityIntfMacVlanId.$ifIndex");
    my $result = $self->{_sessionRead}->get_table(-baseoid => "$oid_snPortMacSecurityIntfMacVlanId.$ifIndex");

    foreach my $oid_including_mac (keys %{$result}) {
        if ($oid_including_mac =~ /^$oid_snPortMacSecurityIntfMacVlanId\.$ifIndex   # the question part
            \.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)            # MAC address in OID format
            $/x) {

            # oid to mac
            my $mac = sprintf("%02x:%02x:%02x:%02x:%02x:%02x", $1, $2, $3, $4, $5, $6);
            my $vlan = $result->{$oid_including_mac};

            # add mac => vlan to hashref
            push @{$secureMacAddrHashRef->{$mac}}, $vlan;
        }
    }

    return $secureMacAddrHashRef;
}

=item getAllSecureMacAddresses - return all MAC addresses in security table and their VLAN

Returns an hashref with MAC => ifIndex => Array(VLANs)

=cut

sub getAllSecureMacAddresses {
    my ($self) = @_;
    my $logger = $self->logger;

    # from FOUNDRY-SN-SWITCH-GROUP-MIB
    my $oid_snPortMacSecurityIntfMacVlanId = '1.3.6.1.4.1.1991.1.1.3.24.1.1.4.1.3';

    my $secureMacAddrHashRef = {};
    if (!$self->connectRead()) {
        return $secureMacAddrHashRef;
    }

    # fetch the information
    $logger->trace("SNMP get_table for snPortMacSecurityIntfMacVlanId: $oid_snPortMacSecurityIntfMacVlanId");
    my $result = $self->{_sessionRead}->get_table(-baseoid => "$oid_snPortMacSecurityIntfMacVlanId");

    foreach my $oid_including_mac (keys %{$result}) {
        if ($oid_including_mac =~ /^$oid_snPortMacSecurityIntfMacVlanId             # the question part
            \.([0-9]+)                                                              # ifIndex
            \.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)            # MAC address in OID format
            $/x) {

            my $ifIndex = $1;
            # oid to mac
            my $mac = sprintf("%02x:%02x:%02x:%02x:%02x:%02x", $2, $3, $4, $5, $6, $7);
            my $vlan = $result->{$oid_including_mac};

            # add mac => vlan to hashref
            push @{$secureMacAddrHashRef->{$mac}->{$ifIndex}}, $vlan;
        }
    }

    return $secureMacAddrHashRef;
}

=item authorizeMAC - authorize a MAC address and de-authorize the previous one if required

=cut

sub authorizeMAC {
    my ($self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan) = @_;
    my $logger = $self->logger;

    # TODO consider pushing this up to caller (especially if we do it in every authorizeMAC)
    if (!$self->isProductionMode()) {
        $logger->info("not in production mode ... we won't add an entry to the SecureMacAddrTable");
        return 1;
    }

    if (!$self->connectWrite()) {
        return 0;
    }

    # OID information
    my $oid_snPortMacSecurityIntfMacRowStatus = '1.3.6.1.4.1.1991.1.1.3.24.1.1.4.1.4';
    my $oid_snPortMacSecurityIntfMacVlanId = '1.3.6.1.4.1.1991.1.1.3.24.1.1.4.1.3';

    # WARNING: deauth/auth was splitted into two set requests because the switch couldn't handle both in the same set
    # deauthentication set request
    my @deauth_oid_to_set;
    if ($deauthMac) {
        # VLAN
        my $vlan_deassign_oid = "$oid_snPortMacSecurityIntfMacVlanId.$ifIndex.".mac2oid($deauthMac);
        push @deauth_oid_to_set, ($vlan_deassign_oid, Net::SNMP::GAUGE32, $deauthVlan);

        # MAC
        my $deauth_oid = "$oid_snPortMacSecurityIntfMacRowStatus.$ifIndex.".mac2oid($deauthMac);
        push @deauth_oid_to_set, ($deauth_oid, Net::SNMP::INTEGER, DELETE);
    }

    # if there's something to do
    if (@deauth_oid_to_set) {
        $logger->trace("De-auth SNMP set_request for snPortMacSecurityIntfMacRowStatus. Values: \n"
            . $deauth_oid_to_set[0] . "(" . $deauth_oid_to_set[1]  . ") => " . $deauth_oid_to_set[2]  . "\n"
            . $deauth_oid_to_set[3] . "(" . $deauth_oid_to_set[4]  . ") => " . $deauth_oid_to_set[5]  . "\n"
        );
        my $result = $self->{_sessionWrite}->set_request(-varbindlist => \@deauth_oid_to_set);
        if (!defined($result)) {
            $logger->warn("SNMP error tyring to perform de-auth. This could be normal. "
                . "Error message: ".$self->{_sessionWrite}->error());
        }
    }

    # authentication set request
    my @auth_oid_to_set;
    if ($authMac) {
        # VLAN
        my $vlan_assign_oid = "$oid_snPortMacSecurityIntfMacVlanId.$ifIndex.".mac2oid($authMac);
        push @auth_oid_to_set, ($vlan_assign_oid, Net::SNMP::GAUGE32, $authVlan);

        # MAC
        my $auth_oid = "$oid_snPortMacSecurityIntfMacRowStatus.$ifIndex.".mac2oid($authMac);
        push @auth_oid_to_set, ($auth_oid, Net::SNMP::INTEGER, CREATE);
    }

    # if there's something to do
    if (@auth_oid_to_set) {
        $logger->trace("Auth SNMP set_request for snPortMacSecurityIntfMacRowStatus. Values: \n"
            . $auth_oid_to_set[0] . "(" . $auth_oid_to_set[1]  . ") => " . $auth_oid_to_set[2]  . "\n"
            . $auth_oid_to_set[3] . "(" . $auth_oid_to_set[4]  . ") => " . $auth_oid_to_set[5]  . "\n"
        );
        my $result = $self->{_sessionWrite}->set_request(-varbindlist => \@auth_oid_to_set);
        if (!defined($result)) {
            $logger->error("SNMP error tyring to perform auth. This could be normal. "
                . "Error message: ".$self->{_sessionWrite}->error());
            return 0;
        }
    }
    return 1;
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
}

=item isVoIPEnabled - is Voice over IP enabled on that switch?

=cut

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

=item _setDualModeVlan - set the dual-mode of the specified ifIndex to the given VLAN

dual-mode is required when there is IP Telephony on the switch.
Dual-mode allows an ifIndex to support an untagged vlan along with a tagged one (ie: voice vlan).

=cut

sub _setDualModeVlan {
    my ($self, $ifIndex, $vlan) = @_;
    my $logger = $self->logger;

    if ( !$self->connectWrite() ) {
        return 0;
    }

    # from FOUNDRY-SN-SWITCH-GROUP-MIB
    my $oid_snSwIfInfoTagMode = '1.3.6.1.4.1.1991.1.1.3.3.5.1.4';
    my $oid_snSwIfVlanId = '1.3.6.1.4.1.1991.1.1.3.3.5.1.24';
    $logger->trace("SNMP set_request for dual-mode (snSwIfInfoTagMode and snSwIfVlanId): "
        . "$oid_snSwIfInfoTagMode and $oid_snSwIfVlanId"
    );

    # get rid of the specific dual-mode vlan id (required otherwise setting a new one gives an error)
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [
            "$oid_snSwIfInfoTagMode.$ifIndex", Net::SNMP::INTEGER, DUAL_MODE,
            "$oid_snSwIfVlanId.$ifIndex", Net::SNMP::INTEGER, 0
        ]
    );

    # set dual-mode to allow specified vlan as the untagged vlan for this ifIndex
    $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [
            "$oid_snSwIfInfoTagMode.$ifIndex", Net::SNMP::INTEGER, DUAL_MODE,
            "$oid_snSwIfVlanId.$ifIndex", Net::SNMP::INTEGER, $vlan
        ]
    );

    return (defined($result));
}

=item getVoiceVlan - in what VLAN should a VoIP device be

=cut

sub getVoiceVlan {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    my $voiceVlan = $self->getVlanByName($VOICE_ROLE);
    if (defined($voiceVlan)) {
        return $voiceVlan;
    }

    # otherwise say it didn't work
    $logger->warn("Voice VLAN was requested but it's not configured!");
    return -1;
}


=back

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
