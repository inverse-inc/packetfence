package pf::Switch::SMC::TS6128L2;

=head1 NAME

pf::Switch::SMC::TS6128L2 - Object oriented module to parse SNMP traps and manage SMC's TigerStack 6128 L2 switches

=head1 STATUS

Supports 
 linkUp / linkDown mode
 Port Security with 1.4.8.5

Developed and tested on SMC 6128L2 running on firmware (Operation Code) version 1.4.8.5

=head1 BUGS AND LIMITATIONS
 
=over

=item Firmware requirement

Minimum required firmware (Operation Code version) for Port-security is 1.4.8.5.

=item SNMPv3

SNMPv3 support was not tested.

=back

=cut

use strict;
use warnings;

use Net::SNMP;

use base ('pf::Switch::SMC');

sub description { 'SMC TigerStack 6128L2' }

# importing switch constants
use pf::Switch::constants;

use constant MODEL_OID_ID => '66';

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
