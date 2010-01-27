package pf::SNMP::Cisco::ISR_1800;

=head1 NAME

pf::SNMP::Cisco::ISR_1800

=head1 SYNOPSIS

Object oriented module to parse SNMP traps and manage Cisco 1800 routers

=head1 STATUS

No documented minimum required firmware version.

Developed and tested on Cisco 1811 12.4(15)T6

Version 12.4(24)T1 and 12.4(15)T6 doesn't support VTP MIB 

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP::Cisco');
use Log::Log4perl;
use Carp;
use Net::SNMP;

#sub getMinOSVersion {
#    my $this   = shift;
#    my $logger = Log::Log4perl::get_logger( ref($this) );
#    return '';
#}

# return the list of managed ports
#sub getManagedPorts {
#}

#obtain hashref from result of getMacAddr
#sub _getIfDescMacVlan {
#}

#sub clearMacAddressTable {
#}

#sub getMaxMacAddresses {
#}

sub isDefinedVlan {
    my ($this, $vlan) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # port assigned to VLAN (VLAN membership)
    my $oid_vmMembershipSummaryMemberPorts = "1.3.6.1.4.1.9.9.68.1.2.1.1.2"; #from CISCO-VLAN-MEMBERSHIP-MIB

    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace("SNMP get_request for vmMembershipSummaryMemberPorts: $oid_vmMembershipSummaryMemberPorts.$vlan");

    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$oid_vmMembershipSummaryMemberPorts.$vlan"] );

    return (
            defined($result)
            && exists( $result->{"$oid_vmMembershipSummaryMemberPorts.$vlan"} )
            && ($result->{"$oid_vmMembershipSummaryMemberPorts.$vlan"} ne 'noSuchInstance' )
    );
}

sub getVlan {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    if (!$this->connectRead()) {
        return 0;
    }

    my $OID_vmVlan = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB

    $logger->trace("SNMP get_request for vmVlan: $OID_vmVlan.$ifIndex");

    my $result = $this->{_sessionRead} ->get_request( -varbindlist => ["$OID_vmVlan.$ifIndex"] );
    return (
            defined($result)
            && exists( $result->{"$OID_vmVlan.$ifIndex"})
            && ( $result->{"$OID_vmVlan.$ifIndex"} ne 'noSuchInstance' )
           )
}



=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009, 2010 Inverse inc.

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

