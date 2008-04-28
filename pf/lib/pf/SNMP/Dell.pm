#
# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
#

package pf::SNMP::Dell;

=head1 NAME

pf::SNMP::Dell - Object oriented module to access SNMP enabled Dell switches


=head1 SYNOPSIS

The pf::SNMP::Dell module implements an object oriented interface
to access SNMP enabled Dell switches.

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use POSIX;
use Log::Log4perl;
use Data::Dumper;

sub getVersion {
    my ($this) = @_;
    my $oid_productIdentificationBuildNumber = '1.3.6.1.4.1.674.10895.3000.1.2.100.5.0'; # Dell-Vendor-MIB
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Dell");
    if (! $this->connectRead()) {
        return '';
    }
    $logger->debug("SNMP get_request for productIdentificationBuildNumber: $oid_productIdentificationBuildNumber");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [$oid_productIdentificationBuildNumber]
    );
    return ($result->{$oid_productIdentificationBuildNumber} || '');
}

sub parseTrap {
    my ($this, $trapString) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Dell");
    if ($trapString =~ /OID: .1.3.6.1.6.3.1.1.5.([34])\|.1.3.6.1.2.1.2.2.1.1.(\d+) = INTEGER/) {
        $trapHashRef->{'trapType'} = (($1 == 3) ? "down" : "up");
        $trapHashRef->{'trapIfIndex'} = $2;
    } elsif ($trapString =~ /\.1\.3\.6\.1\.2\.1\.2\.2\.1\.8\.(\d+) = INTEGER: (down|up)/) {
        $trapHashRef->{'trapType'} = $2;
        $trapHashRef->{'trapIfIndex'} = $1;
    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

# 1 => static
# 2 => dynamic
sub getVmVlanType {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger("pf::SNMP::Dell");
    if (! $this->connectRead()) {
        return 0;
    }
    my $OID_vlanPortModeExtStatus = '1.3.6.1.4.1.674.10895.5000.2.89.48.40.1.2'; #RADLAN-vlan-MIB
    $logger->trace("SNMP get_request for vlanPortModeExtStatus: $OID_vlanPortModeExtStatus.$ifIndex");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => ["$OID_vlanPortModeExtStatus.$ifIndex"]
    );
    if ((exists($result->{"$OID_vlanPortModeExtStatus.$ifIndex"})) && ($result->{"$OID_vlanPortModeExtStatus.$ifIndex"} ne 'noSuchInstance') && ($result->{"$OID_vlanPortModeExtStatus.$ifIndex"} == 1)) {
        return 2;
    } else {
        return 1;
    }
}

1;


# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
