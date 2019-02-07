package pf::Switch::AlliedTelesis;

=head1 NAME

pf::Switch::AlliedTelesis - Object oriented module to access SNMP enabled AliedTelesis Switches

=head1 SYNOPSIS

The pf::Switch::AlliedTelesis module implements an object oriented interface
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
use Net::SNMP;
use base ('pf::Switch');

# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::constants;
use pf::config qw(
    $MAC
    $PORT
);

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
    my ($self) = @_;
    my $oid_alliedFirmwareVersion = '.1.3.6.1.4.1.89.2.4.0';
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace(
        "SNMP get_request for oid_alliedFirmwareVersion: $oid_alliedFirmwareVersion"
    );
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_alliedFirmwareVersion] );
    my $runtimeSwVersion = ( $result->{$oid_alliedFirmwareVersion} || '' );

    return $runtimeSwVersion;
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
