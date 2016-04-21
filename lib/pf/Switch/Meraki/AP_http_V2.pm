package pf::Switch::Meraki::AP_http_V2;

=head1 NAME

pf::Switch::Meraki::AP_http_V2

=head1 SYNOPSIS

The pf::Switch::Meraki::AP_http_V2 module implements an object oriented interface to
manage the external captive portal on Meraki access points

=head1 STATUS

Developed and tested on a MR12 access point

=head1 BUGS AND LIMITATIONS

In the current BETA version, VLAN assignment is broken in Mac Authentication Bypass.
You can work around this by using the following RADIUS filter (conf/radius_filters.conf)

    [your_ssid]
    filter = ssid
    operator = is
    value = Meraki-Mac-Auth-SSID

    [open_ssid_meraki_hack:your_ssid]
    scope = returnRadiusAccessAccept
    merge_answer = no
    answer1 = Airespace-ACL-Name => VLAN$vlan

Then creating a policy named VLANXYZ where XYZ is the VLAN ID you want to assign.

Using this, you will be able to configure the VLAN ids in PacketFence and simply disable the RADIUS filter when the issue is fixed on the Meraki controller. 

=cut

use strict;
use warnings;

use base ('pf::Switch::Cisco::WLC');

=head2 getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->info("we don't know how to determine the version through SNMP !");
    return '1';
}

=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    return 'Airespace-ACL-Name';
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
            "Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating");

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    if (defined($self->{'_controllerPort'}) && $self->{'_controllerPort'} ne '') {
        $logger->info("controllerPort is set, we will use port $self->{_controllerPort} to perform deauth");
        $port_to_disconnect = $self->{'_controllerPort'};
    }
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip(),
            nas_port => '1700',
        };

        $logger->debug("network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        my $node_info = node_view($mac);
        # Standard Attributes

        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

		my $vsa = [
            {
            vendor => "Cisco",
            attribute => "Cisco-AVPair",
            value => "audit-session-id=$node_info->{'sessionid'}",
            },
            {
            vendor => "Cisco",
            attribute => "Cisco-AVPair",
            value => "subscriber:command=reauthenticate",
            },
        ];
        $response = perform_coa($connection_info, $attributes_ref, $vsa);

    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): $_");
        $logger->error("Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.")...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request on (".$self->{'_id'}.")."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
