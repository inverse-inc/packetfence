package pf::Switch::Dell;

=head1 NAME

pf::Switch::Dell - Object oriented module to access SNMP enabled Dell switches

=head1 SYNOPSIS

The pf::Switch::Dell module implements an object oriented interface
to access SNMP enabled Dell switches.

=cut

use strict;
use warnings;

use base ('pf::Switch');

sub getVersion {
    my ($self) = @_;
    my $oid_productIdentificationBuildNumber
        = '1.3.6.1.4.1.674.10895.3000.1.2.100.5.0';    # Dell-Vendor-MIB
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->debug(
        "SNMP get_request for productIdentificationBuildNumber: $oid_productIdentificationBuildNumber"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [$oid_productIdentificationBuildNumber] );
    return ( $result->{$oid_productIdentificationBuildNumber} || '' );
}

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;
    if ( $trapString
        =~ /OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = INTEGER/
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } elsif ( $trapString
        =~ /\.1\.3\.6\.1\.2\.1\.2\.2\.1\.8\.(\d+) = INTEGER: (down|up)/ )
    {
        $trapHashRef->{'trapType'}    = $2;
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
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_vlanPortModeExtStatus
        = '1.3.6.1.4.1.674.10895.5000.2.89.48.40.1.2';    #RADLAN-vlan-MIB
    $logger->trace(
        "SNMP get_request for vlanPortModeExtStatus: $OID_vlanPortModeExtStatus.$ifIndex"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => ["$OID_vlanPortModeExtStatus.$ifIndex"] );
    if (( exists( $result->{"$OID_vlanPortModeExtStatus.$ifIndex"} ) )
        && ( $result->{"$OID_vlanPortModeExtStatus.$ifIndex"} ne
            'noSuchInstance' )
        && ( $result->{"$OID_vlanPortModeExtStatus.$ifIndex"} == 1 )
        )
    {
        return 2;
    } else {
        return 1;
    }
}

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
