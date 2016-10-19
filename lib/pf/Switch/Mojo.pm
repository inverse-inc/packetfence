package pf::Switch::Mojo;
=head1 NAME

pf::Switch::Cisco::WLC - Object oriented module to parse SNMP traps and manage
Cisco Wireless Controllers (WLC) and Wireless Service Modules (WiSM)

=head1 STATUS

Developed and tested on firmware version 4.2.130 altought the new RADIUS RFC3576 support requires firmware v5 and later.

=over

=item Supports

=over

=item Deauthentication with RADIUS Disconnect (RFC3576)

=item Deauthentication with SNMP

=back

=back

=head1 BUGS AND LIMITATIONS

=over

=item Version specific issues

=over

=item < 5.x

Issue with Windows 7: 802.1x+WPA2. It's not a PacketFence issue.

=item 6.0.182.0

We had intermittent issues with DHCP. Disabling DHCP Proxy resolved it. Not
a PacketFence issue.

=item 7.0.116 and 7.0.220

SNMP deassociation is not working in WPA2.  It only works if using an Open
(unencrypted) SSID.

NOTE: This is no longer relevant since we rely on RADIUS Disconnect by
default now.

=item 7.2.103.0 (and maybe up but it is currently the latest firmware)

SNMP de-authentication no longer works. It it believed to be caused by the
new firmware not accepting SNMP requests with 2 bytes request-id. Doing the
same SNMP set with `snmpset` command issues a 4 bytes request-id and the
controllers are happy with these. Not a PacketFence issue. I would think it
relates to the following open caveats CSCtw87226:
http://www.cisco.com/en/US/docs/wireless/controller/release/notes/crn7_2.html#wp934687

NOTE: This is no longer relevant since we rely on RADIUS Disconnect by
default now.

=back

=item FlexConnect (H-REAP) limitations before firmware 7.2

Access Points in Hybrid Remote Edge Access Point (H-REAP) mode, now known as
FlexConnect, don't support RADIUS dynamic VLAN assignments (AAA override).

Customer specific work-arounds are possible. For example: per-SSID
registration, auto-registration, etc. The goal being that only one VLAN
is ever 'assigned' and that is the local VLAN set on the AP for the SSID.

Update: L<FlexConnect AAA Override support was introduced in firmware 7.2 series|https://supportforums.cisco.com/message/3605608#3605608>

=item FlexConnect issues with firmware 7.2.103.0

There's an issue with this firmware regarding the AAA Override functionality
required by PacketFence. The issue is fixed in 7.2.104.16 which is not
released as the time of this writing.

The workaround mentioned by Cisco is to downgrade to 7.0.230.0 but it
doesn't support the FlexConnect AAA Override feature...

So you can use 7.2.103.0 with PacketFence but not in FlexConnect mode.

Caveat CSCty44701

=back

=head1 SEE ALSO

=over

=item L<Version 7.2 - Configuring AAA Overrides for FlexConnect|http://www.cisco.com/en/US/docs/wireless/controller/7.2/configuration/guide/cg_flexconnect.html#wp1247954>

=item L<Cisco's RADIUS Packet of Disconnect documentation|http://www.cisco.com/en/US/docs/ios/12_2t/12_2t8/feature/guide/ft_pod1.html>

=back

=cut

use strict;
use warnings;

use Net::SNMP;
use Try::Tiny;

use base ('pf::Switch');

use pf::constants;
use pf::config qw(
    $MAC
    $SSID
);
use pf::web::util;
use pf::util;
use pf::node;
use pf::util::radius qw(perform_coa perform_disconnect);
use pf::violation qw(violation_count_reevaluate_access);
use pf::radius::constants;
use pf::accounting qw(node_accounting_dynauth_attr);
use pf::locationlog;

sub description { 'Mojo Networks AP' }

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }

=item deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1x).

New implementation using RADIUS Disconnect-Request.

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    # TODO push Login-User => 1 (RFC2865) in pf::radius::constants if someone ever reads this
    # (not done because it doesn't exist in current branch)
    return $self->radiusDisconnect( $mac, { 'Service-Type' => 'Login-User'} );
}

=item radiusDisconnect

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
    # On which port we have to send the CoA-Request ?
    my $nas_port = $self->{'_controllerPort'} || '3799';
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $locationlog = locationlog_view_open_mac($mac);
use Data::Dumper;
$logger->info(Dumper($locationlog));
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip(),
            nas_port => $nas_port,
        };

        $logger->debug("network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");

        my $node_info = node_view($mac);
        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        # Standard Attributes

        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-Identifier' => uc($locationlog->{switch_mac})."-".$locationlog->{ssid} ,
        };

        $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip(),
            nas_port => $nas_port,
        };
        $response = perform_disconnect($connection_info, $attributes_ref);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS Disconnect-Request on (".$self->{'_id'}."): $_");
        $logger->error("Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.")...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'Disconnect-ACK');

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request on (".$self->{'_id'}.")."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=item extractSsid

Find RADIUS SSID parameter out of RADIUS REQUEST parameters

SSID are not provided by a standardized parameter name so we encapsulate that complexity here.
If your AP is not supported look in /usr/share/freeradius/dictionary* for vendor specific attributes (VSA).

Most standard way we encountered is in Called-Station-Id in the format: "xx-xx-xx-xx-xx-xx:SSID".

We support also:

  "xx:xx:xx:xx:xx:xx:SSID"
  "xxxxxxxxxxxx:SSID"

=cut

sub extractSsid {
    my ($self, $radius_request) = @_;
    my $logger = $self->logger;

    # it's put in Called-Station-Id
    # ie: Called-Station-Id = "aa-bb-cc-dd-ee-ff:Secure SSID" or "aa:bb:cc:dd:ee:ff:Secure SSID"
    if (defined($radius_request->{'Called-Station-Id'})) {
        if ($radius_request->{'Called-Station-Id'} =~ /^
            # below is MAC Address with supported separators: :, - or nothing
            [a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}
            -                                                                                           # : delimiter
            (.*)                                                                                        # SSID
        $/ix) {
            return $1;
        } else {
            $logger->info("Unable to extract SSID of Called-Station-Id: ".$radius_request->{'Called-Station-Id'});
        }
    }

    $logger->warn(
        "Unable to extract SSID for module " . ref($self) . ". SSID-based VLAN assignments won't work. "
        . "Please let us know so we can add support for it."
    );
    return;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
