package pf::SNMP::SMC::SMC8800M;

=head1 NAME

pf::SNMP::SMC::SMC8800M - Object oriented module to access SNMP 
enabled SMC Switch - TigerStack II SMC8824M and SMC8848M switches

=head1 SYNOPSIS

The pf::SNMP::SMC::SMC8800M module implements an object 
oriented interface to access SNMP enabled 
SMC Switch - TigerStack II 8824M and 8848M switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::SMC');

sub getVersion {
    my ($this) = @_;
    my $OID_swProdVersion = '1.3.6.1.4.1.202.20.57.1.1.5.4.0';    #swProdVersion
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->debug("SNMP get_request for swProdVersion: $OID_swProdVersion");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => [$OID_swProdVersion] );
    return ( $result->{$OID_swProdVersion} || '' );
}

sub isPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # portSecPortStatus
    # by looking at other SMC MIBS, I noticed that portSecPortStatus is always like .1.3.6.1.4.1.202.20.yy.1.17.2.1.1.2
    # Only yy is different from one SMC switch type to another
    my $OID_portSecPortStatus = '1.3.6.1.4.1.202.20.57.1.17.2.1.1.2';

    if ( !$this->connectRead() ) {
        return 0;
    }

    #determine if port security is enabled
    $logger->trace("SNMP get_request for portSecPortStatus: $OID_portSecPortStatus.$ifIndex");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [ "$OID_portSecPortStatus.$ifIndex" ] );
    return ( exists(
             $result->{"$OID_portSecPortStatus.$ifIndex"} )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} ne 'noSuchInstance' )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} ne 'noSuchObject' )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} == 1 ) );
}

=head1 AUTHOR

Regis Balzard <rbalzard@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010 Inverse inc.

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
