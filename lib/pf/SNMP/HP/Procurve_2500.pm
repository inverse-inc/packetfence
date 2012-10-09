package pf::SNMP::HP::Procurve_2500;

=head1 NAME

pf::SNMP::HP::Procurve_2500 - Object oriented module to access SNMP enabled HP Procurve 2500 switches

=head1 SYNOPSIS

The pf::SNMP::HP::Procurve_2500 module implements an object 
oriented interface to access SNMP enabled HP Procurve 2500 switches.

=head1 STATUS

We've got reports that the HP ProCurve's 5412zl and 8212zl work correctly with this module.

Some clients report that 802.1x and Mac Authentication should work, however we did not test it lab.
We are also not sure about the VoIP using 802.1X/Mac Auth.

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::HP');

# importing switch constants
use pf::SNMP::constants;
use pf::util;
use pf::config;

# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

sub getMaxMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger                  = Log::Log4perl::get_logger( ref($this) );
    my $OID_hpSecPtAddressLimit = '1.3.6.1.4.1.11.2.14.2.10.3.1.3';
    my $OID_hpSecPtLearnMode    = '1.3.6.1.4.1.11.2.14.2.10.3.1.4';
    my $hpSecCfgAddrGroupIndex  = 1;

    if ( !$this->connectRead() ) {
        return -1;
    }

    #determine if port security is enabled
    $logger->trace(
        "SNMP get_request for hpSecPtLearnMode: $OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"
    );
    my $result = $this->{_sessionRead}->get_request( -varbindlist =>
            [ "$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex" ] );
    if ((   !exists(
                $result->{
                    "$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"}
            )
        )
        || ($result->{
                "$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"} eq
            'noSuchInstance' )
        )
    {
        $logger->error("ERROR: could not obtain hpSecPtLearnMode");
        return -1;
    }
    if ( $result->{"$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"}
        != 2 )
    {
        $logger->debug("hpSecPtLearnMode is not static(2)");
        return -1;
    }

    #determine max number of MAC addresses allowed
    $logger->trace(
        "SNMP get_request for hpSecPtAddressLimit: $OID_hpSecPtAddressLimit.$hpSecCfgAddrGroupIndex.$ifIndex"
    );
    $result = $this->{_sessionRead}->get_request( -varbindlist =>
            [ "$OID_hpSecPtAddressLimit.$hpSecCfgAddrGroupIndex.$ifIndex" ] );
    if ((   !exists(
                $result->{
                    "$OID_hpSecPtAddressLimit.$hpSecCfgAddrGroupIndex.$ifIndex"
                    }
            )
        )
        || ($result->{
                "$OID_hpSecPtAddressLimit.$hpSecCfgAddrGroupIndex.$ifIndex"}
            eq 'noSuchInstance' )
        )
    {
        print "and down here\n";
        $logger->error("ERROR: could not obtain hpSecPtAddressLimit");
        return -1;
    }
    return $result->{
        "$OID_hpSecPtAddressLimit.$hpSecCfgAddrGroupIndex.$ifIndex"};
}

sub isPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_hpSecPtLearnMode   = '1.3.6.1.4.1.11.2.14.2.10.3.1.4';
    my $OID_hpSecPtAlarmEnable = '1.3.6.1.4.1.11.2.14.2.10.3.1.6';
    my $hpSecCfgAddrGroupIndex = 1;

    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace(
        "SNMP get_next_request for hpSecPtLearnMode: $OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex and hpSecPtAlarmEnable: $OID_hpSecPtAlarmEnable.$hpSecCfgAddrGroupIndex.$ifIndex"
    );
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [
            "$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex",
            "$OID_hpSecPtAlarmEnable.$hpSecCfgAddrGroupIndex.$ifIndex"
        ]
    );
    return (
        defined(
            $result->{
                "$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"}
            )
            && defined(
            $result->{
                "$OID_hpSecPtAlarmEnable.$hpSecCfgAddrGroupIndex.$ifIndex"}
            )
            && (
            $result->{
                "$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"}
            == 2 )
            && (
            $result->{
                "$OID_hpSecPtAlarmEnable.$hpSecCfgAddrGroupIndex.$ifIndex"}
            == 2 )
    );
}

sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_hpSecCfgStatus
        = '1.3.6.1.4.1.11.2.14.2.10.4.1.4';    #HP-ICF-GENERIC-RPTR
    my $OID_hpSecPtIntrusionFlag
        = '1.3.6.1.4.1.11.2.14.2.10.3.1.7';    #HP-ICF-GENERIC-RPTR
    my $hpSecCfgAddrGroupIndex = 1;

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't add or delete an entry from the hpSecureCfgAddrTable"
        );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my @oid_value;
    if ($deauthMac) {
        my @MACArray = split( /:/, $deauthMac );
        my $MACDecString = '';
        foreach my $hexPiece (@MACArray) {
            if ( $MACDecString ne '' ) {
                $MACDecString .= ".";
            }
            $MACDecString .= hex($hexPiece);
        }
        my $completeOid
            = "$OID_hpSecCfgStatus.$hpSecCfgAddrGroupIndex.$ifIndex.$MACDecString";
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 6 );
    }

    if ($authMac) {
        my @MACArray = split( /:/, $authMac );
        my $MACDecString = '';
        foreach my $hexPiece (@MACArray) {
            if ( $MACDecString ne '' ) {
                $MACDecString .= ".";
            }
            $MACDecString .= hex($hexPiece);
        }
        my $completeOid
            = "$OID_hpSecCfgStatus.$hpSecCfgAddrGroupIndex.$ifIndex.$MACDecString";
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 4 );
    }

    #add flag reset
    push @oid_value,
        (
        "$OID_hpSecPtIntrusionFlag.$hpSecCfgAddrGroupIndex.$ifIndex",
        Net::SNMP::INTEGER, 2
        );

    $logger->trace(
        "SNMP set_request for hpSecCfgStatus: $OID_hpSecCfgStatus.$hpSecCfgAddrGroupIndex.$ifIndex"
    );
    my $result
        = $this->{_sessionWrite}->set_request( -varbindlist => \@oid_value );
    return ( defined($result) );
}

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2011 Inverse inc.

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
