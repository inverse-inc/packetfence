#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::HP::Procurve_2500;

=head1 NAME

pf::SNMP::HP::Procurve_2500 - Object oriented module to access SNMP enabled HP Procurve 2500 switches


=head1 SYNOPSIS

The pf::SNMP::HP::Procurve_2500 module implements an object 
oriented interface to access SNMP enabled HP Procurve 2500 switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::HP');

sub getMaxMacAddresses {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::HP::Procurve_2500");
    my $OID_hpSecPtAddressLimit = '1.3.6.1.4.1.11.2.14.2.10.3.1.3';
    my $OID_hpSecPtLearnMode = '1.3.6.1.4.1.11.2.14.2.10.3.1.4';
    my $hpSecCfgAddrGroupIndex = 1;

    if (! $this->connectRead()) {
        return -1;
    }

    #determine if port security is enabled
    $logger->trace("SNMP get_request for hpSecPtLearnMode: $OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [
        "$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"
        ]
    );
    if ((! exists($result->{"$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"})) || ($result->{"$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"} eq 'noSuchInstance')) {
        $logger->error("ERROR: could not obtain hpSecPtLearnMode");
        return -1;
    }
    if ($result->{"$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"} != 2) {
        $logger->debug("hpSecPtLearnMode is not static(2)");
        return -1;
    }

    #determine max number of MAC addresses allowed
    $logger->trace("SNMP get_request for hpSecPtAddressLimit: $OID_hpSecPtAddressLimit.$hpSecCfgAddrGroupIndex.$ifIndex");
    $result = $this->{_sessionRead}->get_request(
        -varbindlist => [
        "$OID_hpSecPtAddressLimit.$hpSecCfgAddrGroupIndex.$ifIndex"
        ]
    );
    if ((! exists($result->{"$OID_hpSecPtAddressLimit.$hpSecCfgAddrGroupIndex.$ifIndex"})) || ($result->{"$OID_hpSecPtAddressLimit.$hpSecCfgAddrGroupIndex.$ifIndex"} eq 'noSuchInstance')) {
        print "and down here\n";
        $logger->error("ERROR: could not obtain hpSecPtAddressLimit");
        return -1;
    }
    return $result->{"$OID_hpSecPtAddressLimit.$hpSecCfgAddrGroupIndex.$ifIndex"};
}

sub isPortSecurityEnabled {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::HP::Procurve_2500");

    my $OID_hpSecPtLearnMode = '1.3.6.1.4.1.11.2.14.2.10.3.1.4';
    my $OID_hpSecPtAlarmEnable = '1.3.6.1.4.1.11.2.14.2.10.3.1.6';
    my $hpSecCfgAddrGroupIndex = 1;

    if (! $this->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_next_request for hpSecPtLearnMode: $OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex and hpSecPtAlarmEnable: $OID_hpSecPtAlarmEnable.$hpSecCfgAddrGroupIndex.$ifIndex");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [
                           "$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex",
                           "$OID_hpSecPtAlarmEnable.$hpSecCfgAddrGroupIndex.$ifIndex"
                         ]
    );
    return (defined($result->{"$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"}) && defined($result->{"$OID_hpSecPtAlarmEnable.$hpSecCfgAddrGroupIndex.$ifIndex"}) && ($result->{"$OID_hpSecPtLearnMode.$hpSecCfgAddrGroupIndex.$ifIndex"} == 2) && ($result->{"$OID_hpSecPtAlarmEnable.$hpSecCfgAddrGroupIndex.$ifIndex"} == 2));
}

sub authorizeMAC {
    my ($this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::HP::Procurve_2500");

    my $OID_hpSecCfgStatus = '1.3.6.1.4.1.11.2.14.2.10.4.1.4'; #HP-ICF-GENERIC-RPTR
    my $OID_hpSecPtIntrusionFlag = '1.3.6.1.4.1.11.2.14.2.10.3.1.7'; #HP-ICF-GENERIC-RPTR
    my $hpSecCfgAddrGroupIndex = 1;

    if (! $this->isProductionMode()) {
        $logger->info("not in production mode ... we won't add or delete an entry from the hpSecureCfgAddrTable");
        return 1;
    }

    if (! $this->connectWrite()) {
        return 0;
    }

    my @oid_value;
    if ($deauthMac) {
        my @MACArray = split(/:/, $deauthMac);
        my $MACDecString = '';
        foreach my $hexPiece (@MACArray) {
            if ($MACDecString ne '') {
                $MACDecString .= ".";
            }
            $MACDecString .= hex($hexPiece);
        }
        my $completeOid = "$OID_hpSecCfgStatus.$hpSecCfgAddrGroupIndex.$ifIndex.$MACDecString";
        push @oid_value, ($completeOid, Net::SNMP::INTEGER, 6);
    }

    if ($authMac) {
        my @MACArray = split(/:/, $authMac);
        my $MACDecString = '';
        foreach my $hexPiece (@MACArray) {
            if ($MACDecString ne '') {
                $MACDecString .= ".";
            }
            $MACDecString .= hex($hexPiece);
        }
        my $completeOid = "$OID_hpSecCfgStatus.$hpSecCfgAddrGroupIndex.$ifIndex.$MACDecString";
        push @oid_value, ($completeOid, Net::SNMP::INTEGER, 4);
    }

    #add flag reset
    push @oid_value, ("$OID_hpSecPtIntrusionFlag.$hpSecCfgAddrGroupIndex.$ifIndex", Net::SNMP::INTEGER, 2);

    $logger->trace("SNMP set_request for hpSecCfgStatus: $OID_hpSecCfgStatus.$hpSecCfgAddrGroupIndex.$ifIndex");
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => \@oid_value
    );
    return (defined($result));
}

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
