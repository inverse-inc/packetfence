package pf::Switch::Juniper::EX2300;

=head1 NAME

pf::SNMP::Juniper::EX2300 - Object oriented module to manage Juniper's EX Series switches

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

use base ('pf::Switch::Juniper::EX2200');

use pf::constants;
sub description { 'Juniper EX 2300 Series' }

# importing switch constants
use pf::Switch::constants;
use pf::node qw(node_attributes);
use pf::util::radius qw(perform_disconnect);
use Try::Tiny;
use pf::util;

=head2 radiusDisconnect

Send a Disconnect request to disconnect a mac

=cut

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
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
        };

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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

