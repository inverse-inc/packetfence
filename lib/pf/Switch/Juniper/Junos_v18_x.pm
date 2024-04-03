package pf::Switch::Juniper::Junos_v18_x;

=head1 NAME

pf::SNMP::Juniper::Junos_v18_x - Object oriented module to manage Juniper's EX Series switches

=head1 STATUS

Supports
 MAC Authentication (MAC RADIUS in Juniper's terms)
 802.1X

Developed and tested on Juniper ex2300 running on JUNOS 18.2

=head1 BUGS AND LIMITATIONS

=head2 VoIP is only supported in untagged mode

VoIP devices will use the defined voiceVlan but in untagged mode.
A computer and a phone in the same port can still be on two different VLANs since Juniper supports multiple VLANs per port.

=head2 VSTP and RADIUS dynamic VLAN assignment

Currently, these two technologies cannot be enabled at the same time on the ports and VLANs on which PacketFence is enabled.

=cut

use strict;
use warnings;

use base ('pf::Switch::Juniper::Junos_v15_x');

use pf::constants;
sub description { 'Junos v18.x' }

# importing switch constants
use pf::Switch::constants;
use pf::node qw(node_attributes);
use pf::util::radius qw(perform_disconnect perform_coa);
use Try::Tiny;
use pf::util;

=head2 radiusDisconnect

Send a Disconnect request to disconnect a mac

=cut

=head2 getVoipVsa

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).
For now it returns the voiceVlan untagged since Juniper supports multiple untagged VLAN in the same interface

=cut

sub getVoipVsa{
    my ($self) = @_;
    my $logger = $self->logger;
    my $voiceVlan = $self->{'_voiceVlan'};
    
    $logger->info("Accepting phone with Access-Accept on voiceVlan $voiceVlan");
    
    return (
        'Juniper-VoIP-Vlan' => "$voiceVlan",
    );
}

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

    # translating to expected format 00-11-22-33-CA-FE
    $mac = uc($mac);
    $mac =~ s/:/-/g;

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    my $response;
    try {
        my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = perform_disconnect($connection_info, $attributes_ref, []);

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

=head2 setAdminStatus - bounce switch port with radius CoA technique

Send a CoA request to bounce switch port

=cut

sub setAdminStatus {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    #We need to fetch the MAC on the ifIndex in order to bounce switch port with CoA.
    my @locationlog = locationlog_view_open_switchport_no_VoIP( $self->{_ip}, $ifIndex );
    my $mac = $locationlog[0]->{'mac'};
    if (!$mac) {
        @locationlog = locationlog_view_open_switchport_only_VoIP( $self->{_ip}, $ifIndex );
        $mac = $locationlog[0]->{'mac'};
    }
    
    if (!$mac) {
        $logger->info("Can't find MAC address in the locationlog... we won't perform port bounce");
        return $TRUE;
    }

    if ( !$self->isProductionMode() ) {
        $logger->info("Switch not in production mode... we won't perform port bounce");
        return $TRUE;
    }

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on $self->{'_id'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("bouncing $mac using RADIUS CoA-Request method");

    # translating to expected format 00-11-22-33-CA-FE
    $mac = uc($mac);
    $mac =~ s/:/-/g;

    my $response;
    my $send_disconnect_to = $self->{'_controllerIp'} || $self->{'_ip'};
    try {
        my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);

        $response = perform_coa( $connection_info,
            {
                'Acct-Terminate-Cause' => 'Admin-Reset',
                'NAS-IP-Address' => $self->{'_switchIp'},
                'Calling-Station-Id' => $mac,
            },
            [{ 'vendor' => 'Juniper', 'attribute' => 'Juniper-AV-Pair', 'value' => 'Port-Bounce' }],
        );
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

    $logger->warn(
        "Unable to perform RADIUS CoA-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=item bouncePort

Performs a shut / no-shut on the port.
Usually used to force the operating system to do a new DHCP Request after a VLAN change.

=cut

sub bouncePort {
    my ($self, $ifIndex) = @_;

    $self->setAdminStatus( $ifIndex );

    return $TRUE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
