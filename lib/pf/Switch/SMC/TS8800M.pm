package pf::Switch::SMC::TS8800M;

=head1 NAME

pf::Switch::SMC::TS8800M

=head1 DESCRIPTION

Object oriented module to parse SNMP traps and manage SMC's TigerStack II SMC8824M and SMC8848M switches.

=head1 STATUS

Supports 
 linkUp / linkDown mode
 Port Security with 2.4.5.13

Developed and tested on SMC 8824M running on firmware (Operation Code) version 2.4.5.13.

=head1 BUGS AND LIMITATIONS
 
=over

=item Firmware requirement

Minimum required firmware (Operation Code version) for Port-security is 2.4.5.13.

=item SNMPv3

SNMPv3 support was not tested.

=back

=cut

use strict;
use warnings;
use Net::SNMP;

use base ('pf::Switch::SMC');

sub description { 'SMC TigerStack 8800 Series' }

# importing switch constants
use pf::Switch::constants;

use constant MODEL_OID_ID => '57';

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut

sub getVersion {
    my ($self) = @_;
    my $OID_swProdVersion = '1.3.6.1.4.1.202.20.'.MODEL_OID_ID.'.1.1.5.4.0';    #swProdVersion
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->debug("SNMP get_request for swProdVersion: $OID_swProdVersion");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => [$OID_swProdVersion] );
    return ( $result->{$OID_swProdVersion} || '' );
}

# TODO: this is for port-security support. At some point we'll have to seperate required OS version by feature
#sub getMinOSVersion {
#    my ($self) = @_;
#    return '2.4.5.13';
#}

sub isPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    # portSecPortStatus
    # by looking at other SMC MIBS, I noticed that portSecPortStatus is always like .1.3.6.1.4.1.202.20.yy.1.17.2.1.1.2
    # Only yy is different from one SMC switch type to another
    my $OID_portSecPortStatus = '1.3.6.1.4.1.202.20.'.MODEL_OID_ID.'.1.17.2.1.1.2';

    if ( !$self->connectRead() ) {
        return 0;
    }

    #determine if port security is enabled
    $logger->trace("SNMP get_request for portSecPortStatus: $OID_portSecPortStatus.$ifIndex");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [ "$OID_portSecPortStatus.$ifIndex" ] );
    return ( exists(
             $result->{"$OID_portSecPortStatus.$ifIndex"} )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} ne 'noSuchInstance' )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} ne 'noSuchObject' )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} == 1 ) );
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
