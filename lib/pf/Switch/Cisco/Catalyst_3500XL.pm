package pf::Switch::Cisco::Catalyst_3500XL;

=head1 NAME

pf::Switch::Cisco::Catalyst_3500XL - Object oriented module to access SNMP enabled Cisco Catalyst 3500XL switches

=head1 SYNOPSIS

The pf::Switch::Cisco::Catalyst_3500XL module implements an object oriented interface
to access SNMP enabled Cisco::Catalyst_3500XL switches.

The minimum required firmware version is 12.0(5)WC15.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;

use base ('pf::Switch::Cisco');
use Carp;
use Net::SNMP;
use Data::Dumper;

use pf::Switch::constants;

sub description { 'Cisco Catalyst 3500XL Series' }

sub getMinOSVersion {
    my $self   = shift;
    my $logger = $self->logger;
    return '12.0(5)WC15';
}

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut

# return the list of managed ports
sub getManagedPorts {
    my $self        = shift;
    my $logger      = $self->logger;
    my $oid_ifType  = '1.3.6.1.2.1.2.2.1.3';                    # MIB: ifTypes
    my $oid_ifDescr = '1.3.6.1.2.1.2.2.1.2';
    my @nonUpLinks;
    my @UpLinks = $self->getUpLinks();    # fetch the UpLink list

    if ( !$self->connectRead() ) {
        return @nonUpLinks;
    }
    $logger->trace("SNMP get_Table for ifType: $oid_ifType");
    my $ifTypes = $self->{_sessionRead}
        ->get_table(    # fetch the ifTypes list of the ports
        -baseoid => $oid_ifType
        );
    if ( defined($ifTypes) ) {

        foreach my $port ( keys %{$ifTypes} ) {
            if ( $ifTypes->{$port} == $SNMP::ETHERNET_CSMACD )
            {           # skip non ethernetCsmacd port type

                $port =~ /^$oid_ifType\.(\d+)$/;
                if ( grep( { $_ == $1 } @UpLinks ) == 0 ) {    # skip UpLinks

                    my $portVlan = $self->getVlan($1);
                    if ( defined $portVlan ) {    # skip ports with no VLAN

                        my $port_type = $self->getVmVlanType($1);
                        if ( ( $port_type == 1 ) || ( $port_type == 4 ) )
                        {                         # skip non static

                            if (grep(
                                    { $_ == $portVlan } values %{ $self->{_vlans} } )
                                != 0 )
                            {    # skip port in a non-managed VLAN
                                $logger->trace(
                                    "SNMP get_request for ifDesc: $oid_ifDescr.$1"
                                );
                                my $ifDescr
                                    = $self->{_sessionRead}->get_request(
                                    -varbindlist =>
                                        ["oid_ifDescr.$1"]    # MIB: ifDescr
                                    );
                                push @nonUpLinks,
                                    $ifDescr->{"oid_ifDescr.$1"};
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
    my ( $self, @macAddr ) = @_;
    my $ifDescMacVlan;
    foreach my $line ( grep( {/Dynamic/} @macAddr ) ) {
        my ( $mac, $vlan, $ifDesc ) = unpack( "A14x21A4x2A*", $line );
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

=item clearMacAddressTable

Warning: this method should _never_ be called in a thread. Net::Appliance::Session is not thread 
safe: 

L<http://www.cpanforum.com/threads/6909/>

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

=cut

sub clearMacAddressTable {
    my ( $self, $ifIndex, $vlan ) = @_;
    my $command;
    my $session;
    my $oid_ifDescr = '1.3.6.1.2.1.2.2.1.2';
    my $logger      = $self->logger;

    eval {
        require Net::Appliance::Session;
        $session = Net::Appliance::Session->new(
            Host      => $self->{_ip},
            Timeout   => 5,
            Transport => $self->{_cliTransport}
        );
        $session->connect(
            Name     => $self->{_cliUser},
            Password => $self->{_cliPwd}
        );
        # Session not already privileged are not supported at this point. See #1370
        #$session->begin_privileged( $self->{_cliEnablePwd} );
    };
    if ($@) {
        $logger->error(
            "ERROR: Can not connect to switch $self->{'_ip'} using "
                . $self->{_cliTransport} );
        return 0;
    }

    # First we fetch ifDescr(ifIndex)
    if ( !$self->connectRead() ) {
        return 0;
    }
    $logger->trace("SNMP get_request for $oid_ifDescr.$ifIndex");
    my $ifDescr = $self->{_sessionRead}->get_request(
        -varbindlist => ["$oid_ifDescr.$ifIndex"]    # MIB: ifDescr
    );
    my $port = $ifDescr->{"$oid_ifDescr.$ifIndex"};

    # then we clear the table with for ifDescr
    $command = "clear mac-address-table interface $port vlan $vlan";

    eval { $session->cmd( String => $command, Timeout => '10' ); };
    if ($@) {
        $logger->error(
            "ERROR: Error while clearing MAC Address table on port $ifIndex for switch $self->{'_ip'} using "
                . $self->{_cliTransport} );
        $session->close();
        return;
    }
    $session->close();
    return 1;
}

sub getMaxMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    #CISCO-C2900-MIB
    my $OID_c2900PortUsageApplication       = '1.3.6.1.4.1.9.9.87.1.4.1.1.3';
    my $OID_c2900PortIfIndex                = '1.3.6.1.4.1.9.9.87.1.4.1.1.25';
    my $OID_c2900PortAddrSecureMaxAddresses = '1.3.6.1.4.1.9.9.87.1.4.1.1.10';

    if ( !$self->connectRead() ) {
        return -1;
    }

    #determine c2900PortModuleIndex and c2900PortIndex from ifIndex
    $logger->trace(
        "SNMP get_table for c2900PortIfIndex: $OID_c2900PortIfIndex");
    my $portIfIndexes = $self->{_sessionRead}
        ->get_table( -baseoid => $OID_c2900PortIfIndex );

    my $c2900PortModuleIndex = undef;
    my $c2900PortIndex       = undef;
    if ( defined($portIfIndexes) ) {
        foreach my $complete_oid ( keys %{$portIfIndexes} ) {
            if ( $portIfIndexes->{$complete_oid} == $ifIndex ) {
                if ( $complete_oid
                    =~ /^$OID_c2900PortIfIndex\.([0-9]+)\.([0-9]+)$/ )
                {
                    $c2900PortModuleIndex = $1;
                    $c2900PortIndex       = $2;
                }
            }
        }
    }

    if ( !defined($c2900PortModuleIndex) ) {
        $logger->error(
            "ERROR: could not resolve ifIndex into PortModuleIndex");
        return -1;
    }

    #determine if port security is enabled
    $logger->trace(
        "SNMP get_request for c2900PortUsageApplication: $OID_c2900PortUsageApplication"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [
            "$OID_c2900PortUsageApplication.$c2900PortModuleIndex.$c2900PortIndex"
        ]
    );
    if ((   !exists(
                $result->{
                    "$OID_c2900PortUsageApplication.$c2900PortModuleIndex.$c2900PortIndex"
                    }
            )
        )
        || ($result->{
                "$OID_c2900PortUsageApplication.$c2900PortModuleIndex.$c2900PortIndex"
            } eq 'noSuchInstance'
        )
        )
    {
        $logger->error("ERROR: could not obtain PortUsageApplication");
        return -1;
    }
    if ($result->{
            "$OID_c2900PortUsageApplication.$c2900PortModuleIndex.$c2900PortIndex"
        } != 2
        )
    {
        $logger->info("PortUsageApplication is not 'security'");
        return -1;
    }

    #determine max number of MAC addresses allowed
    $logger->trace(
        "SNMP get_request for c2900PortAddrSecureMaxAddresses: $OID_c2900PortAddrSecureMaxAddresses"
    );
    $result = $self->{_sessionRead}->get_request(
        -varbindlist => [
            "$OID_c2900PortAddrSecureMaxAddresses.$c2900PortModuleIndex.$c2900PortIndex"
        ]
    );
    if ((   !exists(
                $result->{
                    "$OID_c2900PortAddrSecureMaxAddresses.$c2900PortModuleIndex.$c2900PortIndex"
                    }
            )
        )
        || ($result->{
                "$OID_c2900PortAddrSecureMaxAddresses.$c2900PortModuleIndex.$c2900PortIndex"
            } eq 'noSuchInstance'
        )
        )
    {
        $logger->error("ERROR: could not obtain PortAddrSecureMaxAddresses");
        return -1;
    }
    return $result->{
        "$OID_c2900PortAddrSecureMaxAddresses.$c2900PortModuleIndex.$c2900PortIndex"
        };

}

sub ping {
    my ( $self, $ip ) = @_;
    my $logger = $self->logger;
    my $result;
    my $random;

    my $oid_ciscoPingEntryStatus     = '1.3.6.1.4.1.9.9.16.1.1.1.16';
    my $oid_ciscoPingEntryOwner      = '1.3.6.1.4.1.9.9.16.1.1.1.15';
    my $oid_ciscoPingPacketCount     = '1.3.6.1.4.1.9.9.16.1.1.1.4';
    my $oid_ciscoPingProtocol        = '1.3.6.1.4.1.9.9.16.1.1.1.2';
    my $oid_ciscoPingAddress         = '1.3.6.1.4.1.9.9.16.1.1.1.3';
    my $oid_ciscoPingSentPackets     = '1.3.6.1.4.1.9.9.16.1.1.1.9';
    my $oid_ciscoPingReceivedPackets = '1.3.6.1.4.1.9.9.16.1.1.1.10';

    if ( !$self->connectRead() ) {
        return 0;
    }
    if ( !$self->connectWrite() ) {
        return 0;
    }

    #generate random line number for ping
    do {
        $random = 1 + int( rand(1000000) );
        $logger->trace(
            "SNMP get_request for ciscoPingEntryStatus: $oid_ciscoPingEntryStatus.$random"
        );
        $result = $self->{_sessionRead}->get_request(
            -varbindlist => [ "$oid_ciscoPingEntryStatus.$random" ] );
        if ( defined($result) ) {
            $logger->debug(
                "Ping Table row $random is already used - let's generate a new random number"
            );
        } else {
            $logger->debug(
                "Ping Table row $random is free - starting to create it");
        }
    } while ( defined($result) );

    #generate Ping table row
    my @ip = split( /\./, $ip );
    for ( my $i = 0; $i < scalar(@ip); $i++ ) {
        $ip[$i] = sprintf( "%02x", $ip[$i] );
    }
    $logger->trace(
        "SNMP set_request for ciscoPingEntryStatus: $oid_ciscoPingEntryStatus.$random"
    );
    $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [
            "$oid_ciscoPingEntryStatus.$random",
            Net::SNMP::INTEGER,
            5,
            "$oid_ciscoPingEntryOwner.$random",
            Net::SNMP::OCTET_STRING,
            'Perl',
            "$oid_ciscoPingPacketCount.$random",
            Net::SNMP::INTEGER,
            1,
            "$oid_ciscoPingProtocol.$random",
            Net::SNMP::INTEGER,
            1,
            "$oid_ciscoPingAddress.$random",
            Net::SNMP::OCTET_STRING,
            pack( 'H2' x scalar(@ip), @ip ),
        ]
    );

    if ( defined($result) ) {
        $logger->debug("Ping Table row $random successfully created");
        $logger->trace(
            "SNMP get_request for ciscoPingEntryStatus: $oid_ciscoPingEntryStatus.$random"
        );
        $result = $self->{_sessionRead}->get_request(
            -varbindlist => [ "$oid_ciscoPingEntryStatus.$random" ] );
        if ( $result->{"$oid_ciscoPingEntryStatus.$random"} == 2 ) {
            $logger->trace(
                "SNMP set_request for ciscoPingEntryStatus: $oid_ciscoPingEntryStatus.$random"
            );
            $result = $self->{_sessionWrite}->set_request(
                -varbindlist => [
                    "$oid_ciscoPingEntryStatus.$random", Net::SNMP::INTEGER,
                    1
                ]
            );
            if ( defined($result) ) {
                $logger->debug("ping of $ip launched");
                $logger->trace(
                    "SNMP get_request for ciscoPingSentPackets: $oid_ciscoPingSentPackets.$random and ciscoPingReceivedPackets: $oid_ciscoPingReceivedPackets.$random"
                );
                $result = $self->{_sessionRead}->get_request(
                    -varbindlist => [
                        "$oid_ciscoPingSentPackets.$random",
                        "$oid_ciscoPingReceivedPackets.$random"
                    ]
                );
                if ( defined($result) ) {
                    $logger->debug( "number of packets sent: "
                            . $result->{"$oid_ciscoPingSentPackets.$random"}
                            . " - received: "
                            . $result->{
                            "$oid_ciscoPingReceivedPackets.$random"} );
                }
            }
        } else {
            $logger->debug( "ping entry status is "
                    . $result->{"$oid_ciscoPingEntryStatus.$random"}
                    . " - unable to launch ping" );
        }
        $logger->debug("deleting ping table row $random");
        $logger->trace(
            "SNMP set_request for ciscoPingEntryStatus: $oid_ciscoPingEntryStatus.$random"
        );
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$oid_ciscoPingEntryStatus.$random", Net::SNMP::INTEGER, 6
            ]
        );
    } else {
        $logger->debug("could not fill Ping Table row $random");
    }

    return 1;
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

