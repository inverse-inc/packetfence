package pf::SNMP::AlliedTelesis;

=head1 NAME

pf::SNMP::AlliedTelesis - Object oriented module to access SNMP enabled AliedTelesis Switches

=head1 SYNOPSIS

The pf::SNMP::AlliedTelesis module implements an object oriented interface
to access SNMP enabled AlliedTelesis switches.

=head1 STATUS

=over 

=item Supports

=over

=item 802.1X/Mac Authentication without VoIP

=back

Stacked switch support has not been tested.

=back

Tested on a AT8000GS with firmware 2.0.0.26.

=head1 BUGS AND LIMITATIONS

The minimum required firmware version is 2.0.0.26.

Dynamic VLAN assignment on ports with voice is not supported by vendor.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP');

# importing switch constants
use pf::SNMP::constants;
use pf::util;
use pf::config;

=head1 SUBROUTINES

=over

=cut
# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

=item getVersion

=cut
sub getVersion {
    my ($this) = @_;
    my $oid_alliedFirmwareVersion = '.1.3.6.1.4.1.89.2.4.0';
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace(
        "SNMP get_request for oid_alliedFirmwareVersion: $oid_alliedFirmwareVersion"
    );
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid_alliedFirmwareVersion] );
    my $runtimeSwVersion = ( $result->{$oid_alliedFirmwareVersion} || '' );

    return $runtimeSwVersion;
}

=back

=head1 AUTHOR

Francois Gaudreault <fgaudreault@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse Inc.

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
