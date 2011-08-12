package pf::SNMP::LG;

=head1 NAME

pf::SNMP::LG - Object oriented module to access SNMP enabled LG-Ericsson switches.

=head1 STATUS

This modules holds functions common to the LG-Ericsson switches but details and documentation are in each sub-module. 
Refer to them for more information.

=head1 BUGS AND LIMITATIONS

This modules holds functions common to the LG-Ericsson switches but details and documentation are in each sub-module. 
Refer to them for more information.

=cut

use strict;
use warnings;
use diagnostics;

use POSIX;
use Log::Log4perl;

use base ('pf::SNMP');

# importing switch constants
use pf::config;
use pf::SNMP::constants;
use pf::util;

# CAPABILITIES
# access technology supported
sub supportsSnmpTraps { return $FALSE; }
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }

=head1 SUBROUTINES
            
=over   

=cut

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # link up/down
    if ( $trapString =~ /BEGIN VARIABLEBINDINGS [^|]+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|.1.3.6.1.2.1.2.2.1.1.([0-9]+)/) {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    # secure MAC violation
    } elsif ( $trapString =~ /BEGIN VARIABLEBINDINGS [^|]+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.2\.1\.0\.36[^:]+[:] ([0-9]+)[^:]+[:] ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2})/ ) {
        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef -> {'trapIfIndex'} = $1;
        $trapHashRef -> {'trapMac'} = lc($2);
        $trapHashRef -> {'trapMac'} =~ s/ /:/g;
        $trapHashRef -> {'trapVlan'} = $this->getVlan( $trapHashRef->{'trapIfIndex'} );

    # unhandled traps
    } else {
        $logger->debug("trap currently no handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }

    return $trapHashRef;
}

=back

=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>

Francois Gaudreault <fgaudreault@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

=head1 LICENCE

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
