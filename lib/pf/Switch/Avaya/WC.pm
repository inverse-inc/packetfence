package pf::Switch::Avaya::WC;

=head1 NAME

pf::Switch::Avaya::WC

=head1 SYNOPSIS

The pf::Switch::Avaya:WC module implements an object oriented interface to
manage Avaya Wireless Controllers

=head1 BUGS AND LIMITATIONS

=over

=item Caching problems on secure connections

Performing a de-authentication does not clear the key cache.
Meaning that on reconnection the device's authorization is served straight from the cache
instead of creating a new RADIUS query.
This defeats the reason why we perform de-authentication (to change VLAN or deny access).

A client-side workaround exists: disable the PMK Caching on the client.
However this could (and should in our opinion) be fixed by the vendor.

=item SNMPv3 support is untested.

=back

=over

=cut

use strict;
use warnings;

use base ('pf::Switch');

use pf::constants;
use pf::config qw(
    $MAC
    $SSID
);
use pf::util;

sub description { 'Avaya Wireless Controller' }

=back

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item getVersion

obtain image version information from switch

=cut

sub getVersion {
    my ($self)        = @_;
    my $oid_s5ChasVer = '1.3.6.1.4.1.45.1.6.3.1.5.0';
    my $logger        = $self->logger;

    if ( !$self->connectRead() ) {
        return '';
    }

    $logger->trace("SNMP get_request for s5ChasVer: $oid_s5ChasVer");

    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_s5ChasVer] );
    if ( exists( $result->{$oid_s5ChasVer} ) && ( $result->{$oid_s5ChasVer} ne 'noSuchInstance' ) ) {
        return $result->{$oid_s5ChasVer};
    }
    return '';
}

=item deauthenticateMacDefault

deauthenticateMacDefault a MAC address from wireless network (including 802.1x)

=cut

sub deauthenticateMacDefault {
    my ($self, $mac) = @_;
    my $logger = $self->logger;
    my $oid_avWlanAssociatedClientDisassociateAction = '1.3.6.1.4.1.45.7.9.1.1.1.10';

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't write to avWlanAssociatedClientDisassociateAction");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    # append MAC to deauthenticate to oid to set
    $oid_avWlanAssociatedClientDisassociateAction .= '.' . mac2oid($mac);

    $logger->info("deauthenticate mac $mac from controller: " . $self->{_ip});
    $logger->trace("SNMP set_request for avWlanAssociatedClientDisassociateAction: $oid_avWlanAssociatedClientDisassociateAction");
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$oid_avWlanAssociatedClientDisassociateAction", Net::SNMP::INTEGER, 2 ]
    );

    if (defined($result)) {
        $logger->debug("deauthenticatation successful");
        return $TRUE;
    } else {
        $logger->warn("deauthenticatation failed with " . $self->{_sessionWrite}->error());
        return;
    }
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

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
