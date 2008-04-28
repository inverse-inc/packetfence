#
# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::Intel::Express_460;

=head1 NAME

pf::SNMP::Intel::Express_460 - Object oriented module to access SNMP enabled Intel Express 460 switches


=head1 SYNOPSIS

The pf::SNMP::Intel::Express_460 module implements an object oriented interface
to access SNMP enabled Cisco switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::Intel');

sub getVersion {
    my ($this) = @_;
    my $oid_es400AgentRuntimeSwVersion = '1.3.6.1.4.1.343.6.17.1.1.1.0';
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Intel::Express_460");
    if (! $this->connectRead()) {
        return '';
    }
    $logger->trace("SNMP get_request for es400AgentRuntimeSwVersion: $oid_es400AgentRuntimeSwVersion");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [$oid_es400AgentRuntimeSwVersion]
    );
    my $runtimeSwVersion = ($result->{$oid_es400AgentRuntimeSwVersion} || '');
    if ($runtimeSwVersion =~ m/V(\d{1}\.\d{2}\.\d{2})/) {
        return $1;
    } else {
        return $runtimeSwVersion;
    }
}

sub getAllVlans {
    my ($this, @ifIndexes) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Intel::Express_460");
    my $vlanHashRef;
    if (! @ifIndexes) {
        @ifIndexes = $this->getManagedIfIndexes();
    }
    my $OID_vlan = '1.3.6.1.2.1.17.7.1.4.4.1.1';
    if (! $this->connectRead()) {
        return $vlanHashRef;
    }
    $logger->trace("SNMP get_table for $OID_vlan");
    my $result = $this->{_sessionRead}->get_table(
        -baseoid => $OID_vlan
    );
    foreach my $key (keys %{$result}) {
        my $vlan = $result->{$key};
        $key =~ /^$OID_vlan\.(\d+)$/;
        my $ifIndex = $1;
        if (grep(/^$ifIndex$/, @ifIndexes) > 0) {
            $vlanHashRef->{$ifIndex} = $vlan;
        }
    }
    return $vlanHashRef;
}                        
    
sub getVlan {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Intel::Express_460");
    if (! $this->connectRead()) {
        return 0;
    }
    my $OID_vlan = '1.3.6.1.2.1.17.7.1.4.4.1.1';
    $logger->trace("SNMP get_request for $OID_vlan.$ifIndex");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => ["$OID_vlan.$ifIndex"]
    );
    return $result->{"$OID_vlan.$ifIndex"};
}

sub _setVlan {
    my ($this,$ifIndex,$newVlan,$oldVlan,$switch_locker_ref) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Intel::Express_460");
    if (! $this->connectRead()) {
        return 0;
    }
    my $OID_pvid = '1.3.6.1.2.1.17.7.1.4.4.1.1';
    my $OID_dot1qVlanStaticEgressPorts = '1.3.6.1.2.1.17.7.1.4.3.1.2';  # Q-BRIDGE-MIB
    my $result;

    $logger->trace("locking - trying to lock \$switch_locker{" .$this->{_ip} ."} in _setVlan");
    {
        lock %{$switch_locker_ref->{$this->{_ip}}};
        $logger->trace("locking - \$switch_locker{" .$this->{_ip} ."} locked in _setVlan");
        # get current egress ports
        $this->{_sessionRead}->translate(0);
        $logger->trace("SNMP get_request for dot1qVlanStaticEgressPorts: $OID_dot1qVlanStaticEgressPorts.$oldVlan and $OID_dot1qVlanStaticEgressPorts.$newVlan");
        $result = $this->{_sessionRead}->get_request(
            -varbindlist => [
            "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
            "$OID_dot1qVlanStaticEgressPorts.$newVlan",
            ]
        );

        #calculate new settings
        my $egressPortsOldVlan = $this->modifyBitmask($result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"}, $ifIndex-1, 0);
        my $egressPortsVlan = $this->modifyBitmask($result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"}, $ifIndex-1, 1);
        $this->{_sessionRead}->translate(1);

        # set all values
        if (! $this->connectWrite()) {
            return 0;
        }
        $logger->trace("SNMP set_request for pvid and dot1qVlanStaticEgressPorts");
        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
            "$OID_pvid.$ifIndex", Net::SNMP::INTEGER, $newVlan,
            "$OID_dot1qVlanStaticEgressPorts.$oldVlan", Net::SNMP::OCTET_STRING, $egressPortsOldVlan,
            "$OID_dot1qVlanStaticEgressPorts.$newVlan", Net::SNMP::OCTET_STRING, $egressPortsVlan,
            ]
        );

        if (! defined ($result)) {
            $logger->error("error setting vlan: " . $this->{_sessionWrite}->error);
        }

        #set egress ports through web interface
        my $vlanName = $this->getVlans();
        $vlanName = $vlanName->{$newVlan};
        my $urlPath = 'http://' . $this->{_ip} . '/html/Hvlan_egresstag.html?';
        for (my $i=0; $i<length($vlanName); $i++) {
            my $char = substr($vlanName,$i,1);
            $urlPath .= ord(substr($vlanName,$i,1)) . ',';
        }
        $urlPath .= '0';

        eval {
            use LWP::UserAgent;
            use HTML::Form;

            my $ua = LWP::UserAgent->new;
            my $req = HTTP::Request->new(GET => $urlPath);
            $req->authorization_basic($this->{_htaccessUser}, $this->{_htaccessPwd});
            my $form = HTML::Form->parse($ua->request($req));
            $form->value("S$ifIndex",'3');
            $form->click('Submit');
            $req = $form->click('Submit');
            $req->authorization_basic($this->{_htaccessUser},$this->{_htaccessPwd});
            my $response = $ua->request($req);
        };

        if ($@) {
            $logger->error("error setting VLAN: $@");
        }
    }
    $logger->trace("locking - \$switch_locker{" .$this->{_ip} ."} unlocked in _setVlan");
    return 1;
}

sub setAdminStatus {
    my ($this, $ifIndex, $enabled) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Intel::Express_460");
    my $OID_es400PortConfigAdminState = '1.3.6.1.4.1.343.6.17.3.2.1.2';
    if (! $this->connectWrite()) {
        return 0;
    }
    $logger->trace("SNMP set_request for es400PortConfigAdminState: $OID_es400PortConfigAdminState");
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
        "$OID_es400PortConfigAdminState.$ifIndex", Net::SNMP::INTEGER, ($enabled ? 3 : 2),
        ]
    );
    return (defined($result));
}


1;
# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
