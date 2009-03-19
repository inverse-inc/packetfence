#
# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::Cisco::Catalyst_2950;

=head1 NAME

pf::SNMP::Cisco::Catalyst_2950 - Object oriented module to access SNMP enabled Cisco Catalyst 2950 switches

=head1 SYNOPSIS

The pf::SNMP::Cisco::Catalyst_2950 module implements an object oriented interface
to access SNMP enabled Cisco::Catalyst_2950 switches.

NOTE: the following modules are identical: Cisco::Catalyst_2950; Cisco::Catalyst_2960; Cisco::Catalyst_2970

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP::Cisco');
use Log::Log4perl;
use Carp;
use Net::Appliance::Session;
use Net::SNMP;
use Data::Dumper;

sub getMinOSVersion {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return '12.1(22)EA10';
}

sub getManagedPorts {
    my $this       = shift;
    my $logger     = Log::Log4perl::get_logger( ref($this) );
    my $oid_ifType = '1.3.6.1.2.1.2.2.1.3';                     # MIB: ifTypes
    my $oid_ifName = '1.3.6.1.2.1.31.1.1.1.1';
    my @nonUpLinks;
    my @UpLinks = $this->getUpLinks();    # fetch the UpLink list

    if ( !$this->connectRead() ) {
        return @nonUpLinks;
    }
    $logger->trace("SNMP get_table for ifType: $oid_ifType");
    my $ifTypes = $this->{_sessionRead}
        ->get_table(    # fetch the ifTypes list of the ports
        -baseoid => $oid_ifType
        );
    if ( defined($ifTypes) ) {

        foreach my $port ( keys %{$ifTypes} ) {
            if ( $ifTypes->{$port} == 6 )
            {           # skip non ethernetCsmacd port type

                $port =~ /^$oid_ifType\.(\d+)$/;
                if ( grep( { $_ == $1 } @UpLinks ) == 0 ) {    # skip UpLinks

                    my $portVlan = $this->getVlan($1);
                    if ( defined $portVlan ) {    # skip port with no VLAN

                        my $port_type = $this->getVmVlanType($1);
                        if ( ( $port_type == 1 ) || ( $port_type == 4 ) )
                        {                         # skip non static

                            if (grep(
                                    { $_ == $portVlan } @{ $this->{_vlans} } )
                                != 0 )
                            {    # skip port in a non-managed VLAN
                                $logger->trace(
                                    "SNMP get_request for ifName: $oid_ifName.$1"
                                );
                                my $ifNames
                                    = $this->{_sessionRead}->get_request(
                                    -varbindlist =>
                                        ["$oid_ifName.$1"]    # MIB: ifNames
                                    );
                                push @nonUpLinks,
                                    $ifNames->{"$oid_ifName.$1"};
                            }
                        }
                    }
                }
            }
        }
    }
    return @nonUpLinks;
}

#obtain hashref from result of getMacAddr
sub _getIfDescMacVlan {
    my ( $this, @macAddr ) = @_;
    my $ifDescMacVlan;
    foreach my $line ( grep( {/DYNAMIC/} @macAddr ) ) {
        my ( $vlan, $mac, $ifDesc ) = unpack( "A4x4A14x16A*", $line );
        $mac =~ s/\./:/g;
        $mac
            = uc(
                  substr( $mac, 0, 2 ) . ':'
                . substr( $mac, 2,  5 ) . ':'
                . substr( $mac, 7,  5 ) . ':'
                . substr( $mac, 12, 2 ) );
        if ( !( $vlan =~ /ALL/i ) ) {
            push @{ $ifDescMacVlan->{$ifDesc}->{$mac} }, int($vlan);
        }
    }
    return $ifDescMacVlan;
}

sub clearMacAddressTable {
    my ( $this, $ifIndex, $vlan ) = @_;
    my $command;
    my $session;
    my $oid_ifName = '1.3.6.1.2.1.31.1.1.1.1';
    my $logger     = Log::Log4perl::get_logger( ref($this) );

    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport}
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
        $session->begin_privileged( $this->{_cliEnablePwd} );
    };

    if ($@) {
        $logger->error(
            "ERROR: Can not connect to switch $this->{'_ip'} using "
                . $this->{_cliTransport} );
        return 0;
    }

    # First we fetch ifName(ifIndex)
    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace("SNMP get_request for ifName: $oid_ifName");
    my $ifNames = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_ifName.$ifIndex"] );
    my $port = $ifNames->{"$oid_ifName.$ifIndex"};

    # then we clear the table with for ifDescr
    $command = "clear mac-address-table interface $port vlan $vlan";

    eval { $session->cmd( String => $command, Timeout => '10' ); };
    if ($@) {
        $logger->error(
            "ERROR: Error while clearing MAC Address table on port $ifIndex for switch $this->{'_ip'} using "
                . $this->{_cliTransport} );
        $session->close();
        return;
    }
    $session->close();
    return 1;
}

sub getAllSecureMacAddresses {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.2.1.4';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrRowStatus: $oid_cpsSecureMacAddrRowStatus"
    );
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrRowStatus" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsSecureMacAddrRowStatus\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
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

sub isDynamicPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger                   = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.2.1.2';

    if ( !$this->connectRead() ) {
        return 0;
    }
    if ( !$this->isPortSecurityEnabled($ifIndex) ) {
        $logger->debug("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrType: $oid_cpsSecureMacAddrType");
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $result->{$oid_including_mac} == 1 ) {
            return 0;
        }
    }

    return 1;
}

sub isStaticPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger                   = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.2.1.2';

    if ( !$this->connectRead() ) {
        return 0;
    }
    if ( !$this->isPortSecurityEnabled($ifIndex) ) {
        $logger->debug("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrType: $oid_cpsSecureMacAddrType");
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $result->{$oid_including_mac} == 1 ) {
            return 1;
        }
    }

    return 0;
}

sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.2.1.4';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrRowStatus: $oid_cpsSecureMacAddrRowStatus"
    );
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrRowStatus.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsSecureMacAddrRowStatus\.$ifIndex\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
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

sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.2.1.4';

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $voiceVlan = $this->getVoiceVlan($ifIndex);
    if ( ( $deauthVlan == $voiceVlan ) || ( $authVlan == $voiceVlan ) ) {
        $logger->error(
            "ERROR: authorizeMAC called with voice VLAN .... this should not have happened ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    my @oid_value;
    if ($deauthMac) {
        my @macArray = split( /:/, $deauthMac );
        my $completeOid = $oid_cpsSecureMacAddrRowStatus . "." . $ifIndex;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 6 );
    }
    if ($authMac) {
        my @macArray = split( /:/, $authMac );
        my $completeOid = $oid_cpsSecureMacAddrRowStatus . "." . $ifIndex;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 4 );
    }

    if ( scalar(@oid_value) > 0 ) {
        $logger->trace("SNMP set_request for cpsSecureMacAddrRowStatus");
        my $result = $this->{_sessionWrite}
            ->set_request( -varbindlist => \@oid_value );
    }
    return 1;
}

sub getMaxMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    #CISCO-PORT-SECURITY-MIB
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';
    my $OID_cpsIfMaxSecureMacAddr   = '1.3.6.1.4.1.9.9.315.1.2.1.1.3';

    if ( !$this->connectRead() ) {
        return -1;
    }

    #determine if port security is enabled
    $logger->trace(
        "SNMP get_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable.$ifIndex"
    );
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cpsIfPortSecurityEnable.$ifIndex" ] );
    if (( !exists( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} ) )
        || ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} eq
            'noSuchInstance' )
        )
    {
        $logger->error("ERROR: could not obtain cpsIfPortSecurityEnable");
        return -1;
    }
    if ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} != 1 ) {
        $logger->debug("cpsIfPortSecurityEnable is not true");
        return -1;
    }

    #determine max number of MAC addresses allowed
    $logger->trace(
        "SNMP get_request for cpsIfMaxSecureMacAddr: $OID_cpsIfMaxSecureMacAddr.$ifIndex"
    );
    $result = $this->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cpsIfMaxSecureMacAddr.$ifIndex" ] );
    if (( !exists( $result->{"$OID_cpsIfMaxSecureMacAddr.$ifIndex"} ) )
        || ( $result->{"$OID_cpsIfMaxSecureMacAddr.$ifIndex"} eq
            'noSuchInstance' )
        )
    {
        $logger->error("ERROR: could not obtain cpsIfMaxSecureMacAddr");
        return -1;
    }
    return $result->{"$OID_cpsIfMaxSecureMacAddr.$ifIndex"};

}

sub ping {
    my ( $this, $ip ) = @_;
    my $session;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport}
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error(
            "ERROR: Can not connect to switch $this->{'_ip'} using "
                . $this->{_cliTransport} );
        return 1;
    }

    if ( !$session->begin_privileged( $this->{_cliEnablePwd} ) ) {
        $logger->error( "ERROR: Cannot enable: " . $session->errmsg );
        $session->close();
        return 1;
    }

    $session->cmd("ping $ip timeout 0 repeat 1");
    $session->close();

    return 1;
}

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
