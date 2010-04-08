package pf::SNMP::Foundry;

=head1 NAME

pf::SNMP::Foundry - Object oriented module to access SNMP enabled 
Foundry switches

=head1 SYNOPSIS

The pf::SNMP::Foundry module implements an object oriented interface
to access SNMP enabled Foundry switches.

=head1 STATUS

Supports linkUp / linkDown and Port Security modes

Developed and tested on FastIron 4802 running on image version 04.0.00

=head1 BUGS AND LIMITATIONS
    
Port security works with an OS version of 4 or greater.

FastIron with a JetCore chipset cannot work in port-security mode (check show version)

You cannot run a network with VLAN 1 as your normal VLAN with these switches.

SNMPv3 support was not tested.
    
Not so sure how often the security violation traps are sent.
If PacketFence misses the trap you might be out of luck.
We should check with the documentation but I can't find detailed SNMP options right now.

=head1 SUBROUTINES

TODO: this list is incomplete

=over

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use POSIX;
use Log::Log4perl;
use Net::SNMP;

use pf::util;

use constant DELETE => 3;
use constant CREATE => 4;

sub getVersion {
    my ($this)         = @_;
    my $oid_snAgImgVer = '1.3.6.1.4.1.1991.1.1.2.1.11.0';
    my $logger         = Log::Log4perl::get_logger( ref($this) );

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
    # trap has been generalized from previous version to work with 4.00 OS
    } elsif ($trapString =~ /\.1\.3\.6\.1\.4\.1\.1991\.1\.1\.2\.1\.44\.0\ =\              # Notification OID
        STRING:\ "Security:\ Port\ security\ violation\ at\                               # Trap string
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
    my ($this, $vlan) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    # vlanIfIndex to vlan number (vlan tag)
    my $oid_snVLanByPortVLanId = '1.3.6.1.4.1.1991.1.1.3.2.1.1.2'; #from FOUNDRY-SN-SWITCH-GROUP-MIB

    if (!$this->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_table for extremeVlanIfVlanId: $oid_snVLanByPortVLanId");
    my $result = $this->{_sessionRead}->get_table(-baseoid => "$oid_snVLanByPortVLanId");

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

    if (!defined($result)) {
        # something went wrong: report it
        $logger->error("changing VLAN failed with: " . $this->{_sessionWrite}->error);
    } else {

        # if we are in port security mode we need to authorize the MAC in the new VLAN (and deauthorize the old stuff)
        if ($this->isPortSecurityEnabled($ifIndex)) {

            my $secureTableHashRef = $this->getSecureMacAddresses($ifIndex);
            # hash is valid and has one MAC
            if (ref($secureTableHashRef) eq 'HASH' && scalar(keys %{$secureTableHashRef}) == 1) {

                my $mac = (keys %{$secureTableHashRef})[0]; # grab MAC 
                $this->authorizeMAC($ifIndex, $mac, $mac, $oldVlan, $newVlan);
            } else {
                $logger->warn("couldn't authorize MAC for new VLAN: no secure mac or more than one already there");
            }
        }
    }
    return (defined($result));
}

sub isLearntTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return 0;
}

sub isPortSecurityEnabled {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    if (!$this->connectRead()) {
        return 0;
    }

    # from FOUNDRY-SN-SWITCH-GROUP-MIB
    my $oid_snPortMacSecurityIntfContentSecurity = "1.3.6.1.4.1.1991.1.1.3.24.1.1.3.1.2"; 

    #determine if port security is enabled
    $logger->trace("SNMP get_request for snPortMacSecurityIntfContentSecurity: "
        . "$oid_snPortMacSecurityIntfContentSecurity.$ifIndex");

    # snmp request
    my $result = $this->{_sessionRead}->get_request(
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
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # from FOUNDRY-SN-SWITCH-GROUP-MIB
    my $oid_snPortMacSecurityIntfMacVlanId = '1.3.6.1.4.1.1991.1.1.3.24.1.1.4.1.3';

    my $secureMacAddrHashRef = {};
    if (!$this->connectRead()) {
        return $secureMacAddrHashRef;
    }

    # fetch the information
    $logger->trace("SNMP get_table for snPortMacSecurityIntfMacVlanId: $oid_snPortMacSecurityIntfMacVlanId.$ifIndex");
    my $result = $this->{_sessionRead}->get_table(-baseoid => "$oid_snPortMacSecurityIntfMacVlanId.$ifIndex");

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
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # from FOUNDRY-SN-SWITCH-GROUP-MIB
    my $oid_snPortMacSecurityIntfMacVlanId = '1.3.6.1.4.1.1991.1.1.3.24.1.1.4.1.3';

    my $secureMacAddrHashRef = {};
    if (!$this->connectRead()) {
        return $secureMacAddrHashRef;
    }

    # fetch the information
    $logger->trace("SNMP get_table for snPortMacSecurityIntfMacVlanId: $oid_snPortMacSecurityIntfMacVlanId");
    my $result = $this->{_sessionRead}->get_table(-baseoid => "$oid_snPortMacSecurityIntfMacVlanId");

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
    my ($this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # TODO consider pushing this up to caller (especially if we do it in every authorizeMAC)
    if (!$this->isProductionMode()) {
        $logger->info("not in production mode ... we won't add an entry to the SecureMacAddrTable");
        return 1;
    }

    if (!$this->connectWrite()) {
        return 0;
    }

    # FIXME validate VoIP behavior
    my $voiceVlan = $this->getVoiceVlan($ifIndex);
    if (($deauthVlan == $voiceVlan) || ($authVlan == $voiceVlan)) {
        $logger->error("authorizeMAC called with voice VLAN .... this should not have happened ... "
             . "we won't add an entry to the SecureMacAddrTable");
        return 1;
    }

    # OID information
    my $oid_snPortMacSecurityIntfMacRowStatus = '1.3.6.1.4.1.1991.1.1.3.24.1.1.4.1.4';
    my $oid_snPortMacSecurityIntfMacVlanId    = '1.3.6.1.4.1.1991.1.1.3.24.1.1.4.1.3';

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
            . $deauth_oid_to_set[3] . "(" . $deauth_oid_to_set[4]  . ") => " . $deauth_oid_to_set[5]  . "\n");
        my $result = $this->{_sessionWrite}->set_request(-varbindlist => \@deauth_oid_to_set);
        if (!defined($result)) {
            $logger->warn("SNMP error tyring to perform de-auth. This could be normal. "
                . "Error message: ".$this->{_sessionWrite}->error());
        }
    }

    # deauthentication set request
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
            . $auth_oid_to_set[3] . "(" . $auth_oid_to_set[4]  . ") => " . $auth_oid_to_set[5]  . "\n");
        my $result = $this->{_sessionWrite}->set_request(-varbindlist => \@auth_oid_to_set);
        if (!defined($result)) {
            $logger->warn("SNMP error tyring to perform auth. This could be normal. "
                . "Error message: ".$this->{_sessionWrite}->error());
        }
    }
    return 1;
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

=back

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
