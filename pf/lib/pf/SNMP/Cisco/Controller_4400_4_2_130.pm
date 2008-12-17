#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::Cisco::Controller_4400_4_2_130;

=head1 NAME

pf::SNMP::Cisco::Controller_4400_4_2_130 - Object oriented module to access SNMP enabled Cisco Controller 4400 with IOS version 4.2.130


=head1 SYNOPSIS

The pf::SNMP::Cisco::Controller_4400_4_2_130 module implements an object oriented interface
to access SNMP enabled Cisco Controller 4400 with IOS version 4.2.130

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP::Cisco');
use Log::Log4perl;
use Carp;
use Net::SNMP;

sub deauthenticateMac {
    my ($this, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    my $OID_bsnMobileStationDeleteAction = '1.3.6.1.4.1.14179.2.1.4.1.22';

    if (! $this->isProductionMode()) {
        $logger->info("not in production mode ... we won't write to the bnsMobileStationTable");
        return 1;
    }

    if (! $this->connectWrite()) {
        return 0;
    }

    #format MAC
    if (length($mac) == 17) {
        my @macArray = split(/:/, $mac);
        my $completeOid = $OID_bsnMobileStationDeleteAction;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        $logger->trace("SNMP set_request for bsnMobileStationDeleteAction: $completeOid");
        my $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                $completeOid, Net::SNMP::INTEGER, 1
            ]
        );
        return (defined($result));
    } else {
        $logger->error("ERROR: MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx");
        return 1;
    }
}

sub isLearntTrapsEnabled {
    my ($this, $ifIndex) = @_;
    return (0==1);
}

sub setLearntTrapsEnabled {
    my ($this, $ifIndex, $trueFalse) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->error("function is NOT implemented");
    return -1;
}

sub isRemovedTrapsEnabled {
    my ($this, $ifIndex) = @_;
    return (0==1);
}

sub setRemovedTrapsEnabled {
    my ($this, $ifIndex, $trueFalse) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->error("function is NOT implemented");
    return -1;
}

sub getVmVlanType {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->error("function is NOT implemented");
    return -1;
}

sub setVmVlanType {
    my ($this, $ifIndex, $type) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->error("function is NOT implemented");
    return -1;
}

sub isTrunkPort {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->error("function is NOT implemented");
    return -1;
}

sub getVlans {
    my ($this) = @_;
    my $vlans = {};
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->error("function is NOT implemented");
    return $vlans;
}

sub isDefinedVlan {
    my ($this, $vlan) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->error("function is NOT implemented");
    return 0;
}

sub getPhonesDPAtIfIndex {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    my @phones = ();
    if (! $this->isVoIPEnabled()) {
        $logger->debug("VoIP not enabled on switch " . $this->{_ip} . ". getPhonesDPAtIfIndex will return empty list.");
        return @phones;
    }
    $logger->debug("no DP is available on Controller 4400");
    return @phones;
}

sub isVoIPEnabled {
    my ($this) = @_;
    return 0;
}

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
