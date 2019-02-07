package pf::Switch::Dlink::DWS_3026;

=head1 NAME

pf::Switch::Dlink::DWS_3026

=head1 SYNOPSIS

The pf::Switch::Dlink::DWS_3026 module implements an object oriented interface
to manage Dlink DWS 3026 controller.

=head1 STATUS

Model 8500 version 2.2.0.19 or 3.0.0.16 are known to work fine

Model 8600 version 3.0.0.16 is known to work fine with secure SSIDs only

=head1 BUGS AND LIMITATIONS

=over

=item Caching problems on secure connections

Performing a de-authentication does not clear the key cache.
Meaning that on reconnection the device's authorization is served straight from the cache
instead of creating a new RADIUS query.
This defeats the reason why we perform de-authentication (to change VLAN or deny access).

A client-side workaround exists: disable the PMK Caching on the client.
However this could (and should in our opinion) be fixed by the vendor.

Versions above and below 2.2.0.19 are know to cause these problems.

Version 3.0.0.16 is known to work fine.

=item No RADIUS VLAN assignment in MAC Authentication (Open SSIDs) on AP 8600

Firmware 3.0.0.13 and 3.0.0.16 are known to be affected.

=back

=cut

use strict;
use warnings;

use Net::SNMP;

use base ('pf::Switch::Dlink');

use pf::constants;
use pf::config qw(
    $MAC
    $SSID
);
use pf::util;

sub description { 'D-Link DWS 3026' }

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

sub deauthenticateMacDefault {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;
    my $OID_wsAssociatedClientDisassociateAction = '1.3.6.1.4.1.171.10.73.30.9.1.1.9';

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't write to wsAssociatedClientDisassociateAction");
        return 1;
    }

    # handles if deauth should be performed against controller or actual device. Returns sessionWrite hash key to use.
    my $performDeauthOn = $self->getDeauthSnmpConnectionKey();
    if ( !defined($performDeauthOn) ) {
        return;
    }

    my $deauth_oid = $OID_wsAssociatedClientDisassociateAction . "." . mac2oid($mac);

    $logger->trace("SNMP set_request for wsAssociatedClientDisassociateAction: $deauth_oid");
    my $result = $self->{$performDeauthOn}->set_request( -varbindlist => [ $deauth_oid, Net::SNMP::INTEGER, 2 ] );

    # if $result is defined, it works we can return $TRUE
    return $TRUE if (defined($result));

    # otherwise report failure
    $logger->warn("deauthentication for $mac failed with " . $self->{$performDeauthOn}->error());
    return;
}

sub isLearntTrapsEnabled {
    my ( $self, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub setLearntTrapsEnabled {
    my ( $self, $ifIndex, $trueFalse ) = @_;
    my $logger = $self->logger;
    $logger->error("function is NOT implemented");
    return -1;
}

sub isRemovedTrapsEnabled {
    my ( $self, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub setRemovedTrapsEnabled {
    my ( $self, $ifIndex, $trueFalse ) = @_;
    my $logger = $self->logger;
    $logger->error("function is NOT implemented");
    return -1;
}

sub getVmVlanType {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    $logger->error("function is NOT implemented");
    return -1;
}

sub setVmVlanType {
    my ( $self, $ifIndex, $type ) = @_;
    my $logger = $self->logger;
    $logger->error("function is NOT implemented");
    return -1;
}

sub isTrunkPort {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    $logger->error("function is NOT implemented");
    return -1;
}

sub getVlans {
    my ($self) = @_;
    my $vlans  = {};
    my $logger = $self->logger;
    $logger->error("function is NOT implemented");
    return $vlans;
}

sub isDefinedVlan {
    my ( $self, $vlan ) = @_;
    my $logger = $self->logger;
    $logger->error("function is NOT implemented");
    return 0;
}

sub isVoIPEnabled {
    my ($self) = @_;
    return 0;
}

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::SNMP;
    my %tech = (
        $SNMP::SNMP => 'deauthenticateMacDefault',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
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
