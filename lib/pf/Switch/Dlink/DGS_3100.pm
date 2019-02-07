package pf::Switch::Dlink::DGS_3100;

=head1 NAME

pf::Switch::Dlink::DGS_3100 - Object oriented module to access SNMP enabled Dlink DES 3100 switches

=head1 SYNOPSIS

The pf::Switch::Dlink::DGS_3100 module implements an object oriented interface
to access SNMP enabled Dlink DGS 3100 switches.

=head1 STATUS

=over

=item Supports

=over

=item 802.1X/Mac Authentication without VoIP

=back

=back

=head1 BUGS AND LIMITATIONS

The minimum required firmware version is 3.60.28 (PROM: 1.0.1.05) to support RADIUS
Dynamic VLAN Assignments.

NOT tested against stacked switch

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Net::SNMP;
use base ('pf::Switch::Dlink');

sub description { 'D-Link DGS 3100' }

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
    my $oid_dlinkFirmwareVersion = '1.3.6.1.4.1.171.10.94.89.89.2.4.0';
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace(
        "SNMP get_request for oid_dlinkFirmwareVersion: $oid_dlinkFirmwareVersion"
    );
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_dlinkFirmwareVersion] );
    my $runtimeSwVersion = ( $result->{$oid_dlinkFirmwareVersion} || '' );

    return $runtimeSwVersion;
}

=item NasPortToIfIndex

Translate RADIUS NAS-Port into the physical port ifIndex

=cut

sub NasPortToIfIndex {
    my ($self, $NAS_port) = @_;
    my $logger = $self->logger;

    #NAS-Port is ifIndex (Stacked switch not tested!!)
    return $NAS_port;
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
