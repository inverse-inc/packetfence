package pf::Switch::Enterasys::V2110;


=head1 NAME

V2110

=head1 SYNOPSIS

The pf::Switch::Enterasys::V2110 module manages access to Enterasys controller

=head1 STATUS

Should work on the hostapd version started 2.0

=cut

use strict;
use warnings;

use POSIX;
use Try::Tiny;

use base ('pf::Switch::Enterasys');

use pf::constants;
use pf::config qw(
    $MAC
    $SSID
);
sub description { 'Enterasys V2110' }

# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::util::radius qw(perform_disconnect);

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
sub supportsRoleBasedEnforcement { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=head2 getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->info("we don't know how to determine the version through SNMP !");
    return '2.0.13';
}

=head2 deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => 'deauthenticateMacRadius',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=head2 deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1x).

New implementation using RADIUS Disconnect-Request.

=cut

sub deauthenticateMacRadius {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect($mac);
}

=head2 radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Optionally you can provide other attributes as an hashref.

Uses L<pf::util::radius> for the low-level RADIUS stuff.

=cut

# TODO consider whether we should handle retries or not?
sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger;

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS Disconnect-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # Where should we send the RADIUS Disconnect-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
        };

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        my $time = time;

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'Event-Timestamp' => $time,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = perform_disconnect($connection_info, $attributes_ref);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS Disconnect-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ( ($response->{'Code'} eq 'Disconnect-ACK') || ($response->{'Code'} eq 'CoA-ACK') );

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}


=head2 extractSsid

Find RADIUS SSID parameter out of RADIUS REQUEST parameters

Enterasys specific parser. See pf::SNMP for base implementation.

=cut

sub extractSsid {
    my ($self, $radius_request) = @_;
    my $logger = $self->logger;

    if (defined($radius_request->{'Siemens-SSID'})) {
        return $radius_request->{'Siemens-SSID'};
    }

    $logger->warn(
        "Unable to extract SSID for module " . ref($self) . ". SSID-based VLAN assignments won't work. "
        . "Please let us know so we can add support for it."
    );
    return;
}

=head2 returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Filter-Id';
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
