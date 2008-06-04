#
# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::Cisco::Catalyst_2960;

=head1 NAME

pf::SNMP::Cisco::Catalyst_2960 - Object oriented module to access SNMP enabled Cisco Catalyst 2960 switches


=head1 SYNOPSIS

The pf::SNMP::Cisco::Catalyst_2960 module implements an object oriented interface
to access SNMP enabled Cisco::Catalyst_2960 switches.

This modules extends pf::SNMP::Cisco::Catalyst_2950

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;

use lib '/usr/local/pf/lib/';

use base ('pf::SNMP::Cisco::Catalyst_2950');

sub getAllSecureMacAddresses {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Cisco::Catalyst_2960");
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';    

    my $secureMacAddrHashRef = {};
    if (! $this->connectRead()) {
        return $secureMacAddrHashRef;
    }
    $logger->trace("SNMP get_table for cpsIfVlanSecureMacAddrRowStatus: $oid_cpsIfVlanSecureMacAddrRowStatus");
    my $result = $this->{_sessionRead}->get_table(
        -baseoid => "$oid_cpsIfVlanSecureMacAddrRowStatus"
    );
    foreach my $oid_including_mac (keys %{$result}) {
        if ($oid_including_mac =~ /^$oid_cpsIfVlanSecureMacAddrRowStatus\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/) {
            my $oldMac = sprintf("%02x:%02x:%02x:%02x:%02x:%02x", $2, $3, $4, $5, $6, $7);
            my $oldVlan = $8;
            my $ifIndex = $1;
            push @{$secureMacAddrHashRef->{$oldMac}->{$ifIndex}}, $oldVlan;
        }
    }

    #my $voiceSecureMacAddrHashRef;
    #my $session;
    #eval {
    #    $session = Net::Telnet::Cisco->new(Host => $this->{_ip}, Timeout=>5);
    #    $session->login($this->{_telnetUser}, $this->{_telnetPwd});
    #    $session->enable($this->{_telnetEnablePwd});
    #};
    #
    #if ($@) {
    #    $logger->error("ERROR: Can not connect to switch $this->{'_ip'} using Telnet");
    #    return;
    #}
    #
    #eval {
    #    my @output = $session->cmd(String => 'show run | include ((^interface)|(switchport voice vlan)|(switchport port-security mac-address.+vlan voice))', Timeout => '10');
    #    my $switchPort;
    #    my $mac;
    #    my $voiceVlan;
    #    foreach my $line (@output) {
    #        if ($line =~ /^\s*interface (.+)$/i) {
    #            $switchPort = $1;
    #            $voiceVlan = undef;
    #            $mac = undef;
    #        } elsif ($line =~ /switchport voice vlan (\d+)$/) {
    #            $voiceVlan = $1;
    #        } elsif ($line =~ /switchport port-security mac-address ([A-Z0-9]{2})([A-Z0-9]{2})\.([A-Z0-9]{2})([A-Z0-9]{2})\.([A-Z0-9]{2})([A-Z0-9]{2}) vlan voice/i) {
    #            $mac = lc("$1:$2:$3:$4:$5:$6");
    #        }
    #        if (defined($switchPort) && defined($mac) && defined($voiceVlan)) {
    #            push @{$voiceSecureMacAddrHashRef->{$mac}->{$switchPort}}, $voiceVlan;
    #            $switchPort = undef;
    #            $voiceVlan = undef;
    #            $mac = undef;
    #        }
    #    }
    #};
    #if (scalar(keys(%$voiceSecureMacAddrHashRef)) > 0) {
    #    my $oid_ifDescr = '1.3.6.1.2.1.2.2.1.2';
    #    $result = $this->{_sessionRead}->get_table(
    #        -baseoid => $oid_ifDescr
    #    );
    #    my $ifDescrHashRef;
    #    if (defined($result)) {
    #        foreach my $port (keys %$result) {
    #            $port =~ /^$oid_ifDescr\.(\d+)$/;
    #            $ifDescrHashRef->{$result->{$port}} = $1;
    #        }
    #    }
    #    foreach my $mac (keys %$voiceSecureMacAddrHashRef) {
    #        foreach my $ifDescr (keys %{$voiceSecureMacAddrHashRef->{$mac}}) {
    #            my $ifIndex;
    #            if (exists($ifDescrHashRef->{$ifDescr})) {
    #                $ifIndex = $ifDescrHashRef->{$ifDescr};
    #            }
    #            foreach my $vlan (@{$voiceSecureMacAddrHashRef->{$mac}->{$ifDescr}}) {
    #                if (defined($ifIndex)) {
    #                    push @{$secureMacAddrHashRef->{$mac}->{$ifIndex}}, $vlan;
    #                }
    #            }
    #        }
    #    }
    #}
    return $secureMacAddrHashRef;
}

sub isDynamicPortSecurityEnabled {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Cisco::Catalyst_2960");
    my $oid_cpsIfVlanSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.3.1.3';

    if (! $this->connectRead()) {
        return 0;
    }
    if (! $this->isPortSecurityEnabled($ifIndex)) {
        $logger->debug("port security is not enabled");
        return 0;
    }

    $logger->trace("SNMP get_table for cpsIfVlanSecureMacAddrType: $oid_cpsIfVlanSecureMacAddrType");
    my $result = $this->{_sessionRead}->get_table(
        -baseoid => "$oid_cpsIfVlanSecureMacAddrType.$ifIndex"
    );
    foreach my $oid_including_mac (keys %{$result}) {
        if (($result->{$oid_including_mac} == 1) || ($result->{$oid_including_mac} == 3)) {
            return 0;
        }
    }

    return 1;
}

sub isStaticPortSecurityEnabled {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Cisco::Catalyst_2960");
    my $oid_cpsIfVlanSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.3.1.3';

    if (! $this->connectRead()) {
        return 0;
    }
    if (! $this->isPortSecurityEnabled($ifIndex)) {
        $logger->info("port security is not enabled");
        return 0;
    }

    $logger->trace("SNMP get_table for cpsIfVlanSecureMacAddrType: $oid_cpsIfVlanSecureMacAddrType");
    my $result = $this->{_sessionRead}->get_table(
        -baseoid => "$oid_cpsIfVlanSecureMacAddrType.$ifIndex"
    );
    foreach my $oid_including_mac (keys %{$result}) {
        if (($result->{$oid_including_mac} == 1) || ($result->{$oid_including_mac} == 3)) {
            return 1;
        }
    }

    return 0;
}

sub getSecureMacAddresses {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Cisco::Catalyst_2960");
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';  

    my $secureMacAddrHashRef = {};
    if (! $this->connectRead()) {
        return $secureMacAddrHashRef;
    }
    $logger->trace("SNMP get_table for cpsIfVlanSecureMacAddrRowStatus: $oid_cpsIfVlanSecureMacAddrRowStatus");
    my $result = $this->{_sessionRead}->get_table(
        -baseoid => "$oid_cpsIfVlanSecureMacAddrRowStatus.$ifIndex"
    );
    foreach my $oid_including_mac (keys %{$result}) {
        if ($oid_including_mac =~ /^$oid_cpsIfVlanSecureMacAddrRowStatus\.$ifIndex\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/) {
            my $oldMac = sprintf("%02x:%02x:%02x:%02x:%02x:%02x", $1, $2, $3, $4, $5, $6);
            my $oldVlan = $7;
            push @{$secureMacAddrHashRef->{$oldMac}}, int($oldVlan);
        }
    }

    #my $voiceVlan = $this->getVoiceVlan($ifIndex);
    #my $ifDesc = $this->getIfDesc($ifIndex);
    #
    #my $session;
    #eval {
    #    $session = Net::Telnet::Cisco->new(Host => $this->{_ip}, Timeout=>5);
    #    $session->login($this->{_telnetUser}, $this->{_telnetPwd});
    #    $session->enable($this->{_telnetEnablePwd});
    #};
    #
    #if ($@) {
    #    $logger->error("ERROR: Can not connect to switch $this->{'_ip'} using Telnet");
    #    return;
    #}
    #
    #eval {
    #    my @output = $session->cmd(String => "show port-security interface $ifDesc address | include $voiceVlan", Timeout => '10');
    #    my $mac;
    #    foreach my $line (@output) {
    #        if ($line =~ /^\s*$voiceVlan\s+([A-Z0-9]{2})([A-Z0-9]{2})\.([A-Z0-9]{2})([A-Z0-9]{2})\.([A-Z0-9]{2})([A-Z0-9]{2})/i) {
    #            $mac = lc("$1:$2:$3:$4:$5:$6");
    #            push @{$secureMacAddrHashRef->{$mac}}, $voiceVlan;
    #        }
    #    }
    #};

    return $secureMacAddrHashRef;
}

sub authorizeMAC {
    my ($this, $ifIndex, $deauthMac, $authMac, $vlan) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Cisco::Catalyst_2960");
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    if (! $this->isProductionMode()) {
        $logger->info("not in production mode ... we won't add an entry to the SecureMacAddrTable");
        return 1;
    }

    if (! $this->connectWrite()) {
        return 0;
    }

    if ($vlan == $this->getVoiceVlan($ifIndex)) {
        $logger->error("ERROR: authorizeMAC called with voice VLAN .... this should not have happened ... we won't add an entry to the SecureMacAddrTable");
        return 1;
    }

    my @oid_value;
    if ($deauthMac) {
        my @macArray = split(/:/, $deauthMac);
        my $completeOid = $oid_cpsIfVlanSecureMacAddrRowStatus . "." . $ifIndex;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        $completeOid .= "." . $vlan;
        push @oid_value, ($completeOid, Net::SNMP::INTEGER, 6);
    }
    if ($authMac) {
        my @macArray = split(/:/, $authMac);
        my $completeOid = $oid_cpsIfVlanSecureMacAddrRowStatus . "." . $ifIndex;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        $completeOid .= "." . $vlan;
        push @oid_value, ($completeOid, Net::SNMP::INTEGER, 4);
    }

    if (scalar(@oid_value) > 0) {
        $logger->trace("SNMP set_request for cpsIfVlanSecureMacAddrRowStatus");
        my $result = $this->{_sessionWrite}->set_request(
            -varbindlist => \@oid_value
        );
    }
}                                        

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
