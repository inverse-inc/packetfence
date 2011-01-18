package pf::SNMP::Extricom;

=head1 NAME

pf::SNMP::Extricom - Object oriented module to access SNMP enabled Extricom 
Wireless Controller

=head1 SYNOPSIS

The pf::SNMP::Extricom module implements an object oriented interface
to access SNMP enabled Extricom Wireless Controller

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use Log::Log4perl;
use Carp;
use Net::SNMP;
use pf::config;

# importing switch constants
use pf::SNMP::constants;
use pf::util;

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # clientDisassociate: .1.3.6.1.4.1.23937.2.1
    if ( $trapString =~ /\.1\.3\.6\.1\.4\.1\.23937\.2\.1 = STRING: "[0-9]+:Client ([0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2})/ ) {   
        $trapHashRef->{'trapType'} = 'dot11Deauthentication';
        $trapHashRef->{'trapMac'} = lc($1);
        $trapHashRef->{'trapMac'} =~ s/ /:/g;
    
    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub connectWrite {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( defined( $this->{_sessionWrite} ) ) {
        return 1;
    }
    $logger->debug( "opening SNMP v"
            . $this->{_SNMPVersion}
            . " write connection to $this->{_ip}" );
    if ( $this->{_SNMPVersion} eq '3' ) {
        ( $this->{_sessionWrite}, $this->{_error} ) = Net::SNMP->session(
            -hostname     => $this->{_ip},
            -version      => $this->{_SNMPVersion},
            -timeout      => 2,
            -retries      => 1,
            -username     => $this->{_SNMPUserNameWrite},
            -authprotocol => $this->{_SNMPAuthProtocolWrite},
            -authpassword => $this->{_SNMPAuthPasswordWrite},
            -privprotocol => $this->{_SNMPPrivProtocolWrite},
            -privpassword => $this->{_SNMPPrivPasswordWrite}
        );
    } else {
        ( $this->{_sessionWrite}, $this->{_error} ) = Net::SNMP->session(
            -hostname  => $this->{_ip},
            -version   => $this->{_SNMPVersion},
            -timeout   => 2,
            -retries   => 1,
            -community => $this->{_SNMPCommunityWrite}
        );
    }
    if ( !defined( $this->{_sessionWrite} ) ) {
        $logger->error( "error creating SNMP v"
                . $this->{_SNMPVersion}
                . " write connection to "
                . $this->{_ip} . ": "
                . $this->{_error} );
        return 0;
    } else {
       my $oid_readSNMPCommunity = '.1.3.6.1.4.1.23937.2.9.3.0';
        $logger->trace("SNMP get_request for sysLocation: $oid_readSNMPCommunity");
        my $result = $this->{_sessionWrite}
            ->get_request( -varbindlist => [$oid_readSNMPCommunity] );
        if ( !defined($result) ) {
            $logger->error( "error creating SNMP v"
                    . $this->{_SNMPVersion}
                    . " write connection to "
                    . $this->{_ip} . ": "
                    . $this->{_sessionWrite}->error() );
            $this->{_sessionWrite} = undef;
            return 0;
        } else {
            my $sysLocation = $result->{$oid_readSNMPCommunity} || '';
            $logger->trace(
                "SNMP set_request for OID: $oid_readSNMPCommunity to $sysLocation"
            );
            $result = $this->{_sessionWrite}->set_request(
                -varbindlist => [
                    "$oid_readSNMPCommunity", Net::SNMP::OCTET_STRING,
                    $sysLocation
                ]
            );
            if ( !defined($result) ) {
                $logger->error( "error creating SNMP v"
                        . $this->{_SNMPVersion}
                        . " write connection to "
                        . $this->{_ip} . ": "
                        . $this->{_sessionWrite}->error()
                        . " it looks like you specified a read-only community instead of a read-write one"
                );
                $this->{_sessionWrite} = undef;
                return 0;
            }
       }
    }
    return 1;
}


sub deauthenticateMac {
    my ( $this, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_clearDot11Client = '1.3.6.1.4.1.23937.9.12.0';

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't write to the clearDot11Client OID"
        );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    #format MAC
    if ( length($mac) == 17 ) {
        $logger->trace(
            "SNMP set_request for clear_dot11_client: $OID_clearDot11Client"
        );
        my $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [ $OID_clearDot11Client, Net::SNMP::OCTET_STRING, "$mac" ] );
        # TODO: validate result
        $logger->info("deauthenticate mac $mac from controller: ".$this->{_ip});
        return ( defined($result) );
    } else {
        $logger->error(
            "ERROR: MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx"
        );
        return 1;
    }
}

=head1 AUTHOR

Francois Gaudreault <fgaudreault@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2008, 2010 Inverse inc.

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
