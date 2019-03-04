package pf::Switch::Extricom;

=head1 NAME

pf::Switch::Extricom

=head1 SYNOPSIS

Module to parse SNMP traps and manage Extricom Wireless Switches

=head1 STATUS

Developed and tested on Extricom EXSW800 Wireless Switch running firmware version 4.2.46.11

=head1 BUGS AND LIMITATIONS

The vendor doesn't include the SSID in their RADIUS-Request. VLAN assignment per SSID is not possible.

SNMPv3 has not been tested.

=cut

use strict;
use warnings;

use Carp;
use Net::SNMP;

use base ('pf::Switch');

use pf::constants;
use pf::config qw(
    $MAC
    $SSID
);
# importing switch constants
use pf::Switch::constants;
use pf::util;

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item getVersion

obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $oid_inventoryswver = '1.3.6.1.4.1.23937.6.11.0'; # EXTRICOM-SNMP-MIB::inventoryswver
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_inventoryswver");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_inventoryswver] );
    my $inventoryswver = ( $result->{$oid_inventoryswver} || '' );

    # inventoryswver sample output: v4.2.46.11~xs_2010-Jul-21-1657

    if ( $inventoryswver =~ m/v(\d+\.\d+\.\d+\.\d+)~.*/ ) {
        return $1;
    } else {
        return $inventoryswver;
    }
}

=item parseTrap

=cut

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    # EXTRICOM-SNMP-MIB::clientDisassociate: .1.3.6.1.4.1.23937.2.1
    if ( $trapString =~ /\.1\.3\.6\.1\.4\.1\.23937\.2\.1 = STRING: "[0-9]+:Client ([0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2})/ ) {
        $trapHashRef->{'trapType'} = 'dot11Deauthentication';
        $trapHashRef->{'trapMac'} = lc($1);

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

=item connectWrite

WARNING: Overriding connectWrite {} because the default test write fails on these devices.
Writing to the read community instead (then putting back appropriate in place)

=cut

sub connectWrite {
    my $self   = shift;
    my $logger = $self->logger;
    if ( defined( $self->{_sessionWrite} ) ) {
        return 1;
    }
    $logger->debug( "opening SNMP v"
            . $self->{_SNMPVersion}
            . " write connection to $self->{_id}" );
    if ( $self->{_SNMPVersion} eq '3' ) {
        ( $self->{_sessionWrite}, $self->{_error} ) = Net::SNMP->session(
            -hostname     => $self->{_ip},
            -version      => $self->{_SNMPVersion},
            -timeout      => 2,
            -retries      => 1,
            -username     => $self->{_SNMPUserNameWrite},
            -authprotocol => $self->{_SNMPAuthProtocolWrite},
            -authpassword => $self->{_SNMPAuthPasswordWrite},
            -privprotocol => $self->{_SNMPPrivProtocolWrite},
            -privpassword => $self->{_SNMPPrivPasswordWrite},
            -maxmsgsize => 4096
        );
    } else {
        ( $self->{_sessionWrite}, $self->{_error} ) = Net::SNMP->session(
            -hostname  => $self->{_ip},
            -version   => $self->{_SNMPVersion},
            -timeout   => 2,
            -retries   => 1,
            -community => $self->{_SNMPCommunityWrite},
            -maxmsgsize => 4096
        );
    }
    if ( !defined( $self->{_sessionWrite} ) ) {
        $logger->error( "error creating SNMP v"
                . $self->{_SNMPVersion}
                . " write connection to "
                . $self->{_id} . ": "
                . $self->{_error} );
        return 0;
    } else {
       my $oid_readSNMPCommunity = '.1.3.6.1.4.1.23937.2.9.3.0';
        $logger->trace("SNMP get_request for sysLocation: $oid_readSNMPCommunity");
        my $result = $self->{_sessionWrite}
            ->get_request( -varbindlist => [$oid_readSNMPCommunity] );
        if ( !defined($result) ) {
            $logger->error( "error creating SNMP v"
                    . $self->{_SNMPVersion}
                    . " write connection to "
                    . $self->{_id} . ": "
                    . $self->{_sessionWrite}->error() );
            $self->{_sessionWrite} = undef;
            return 0;
        } else {
            my $sysLocation = $result->{$oid_readSNMPCommunity} || '';
            $logger->trace(
                "SNMP set_request for OID: $oid_readSNMPCommunity to $sysLocation"
            );
            $result = $self->{_sessionWrite}->set_request(
                -varbindlist => [
                    "$oid_readSNMPCommunity", Net::SNMP::OCTET_STRING,
                    $sysLocation
                ]
            );
       }
       # We no longer check the $result here since it is always false even when the call succeeds.
    }
    return 1;
}

=item deauthenticateMacDefault

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;
    my $OID_clearDot11Client = '1.3.6.1.4.1.23937.9.12.0'; # EXTRICOM-SNMP-MIB::clearDot11Client

    if ( !$self->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't write to the clearDot11Client OID"
        );
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    #format MAC
    if ( length($mac) == 17 ) {
        $logger->trace(
            "SNMP set_request for clear_dot11_client: $OID_clearDot11Client"
        );
        my $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [ $OID_clearDot11Client, Net::SNMP::OCTET_STRING, "$mac" ]
        );

        # TODO: validate result
        $logger->info("deauthenticate mac $mac from controller: ".$self->{_id});
        return ( defined($result) );
    } else {
        $logger->error(
            "ERROR: MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx"
        );
        return 1;
    }
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::SNMP;
    my %tech = (
        $SNMP::SNMP => 'deauthenticateMacDefault',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
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
