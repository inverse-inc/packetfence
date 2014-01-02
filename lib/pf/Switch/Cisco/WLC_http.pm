package pf::Switch::Cisco::WLC_http;
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

use Log::Log4perl;
use Net::SNMP;
use Net::Telnet;
use Try::Tiny;

use base ('pf::Switch::Cisco::WLC');

use pf::config;
use pf::Switch::constants;
use pf::util;
use pf::roles::custom;
use pf::accounting qw(node_accounting_current_sessionid);
use pf::util::radius qw(perform_coa perform_disconnect);
use pf::node qw(node_attributes);


sub description { 'Cisco Wireless Controller (WLC)' }

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
sub supportsRoleBasedEnforcement { return $TRUE; }
sub supportsExternalPortal { return $TRUE; }

# disabling special features supported by generic Cisco's but not on WLCs
sub supportsSaveConfig { return $FALSE; }
sub supportsCdp { return $FALSE; }
sub supportsLldp { return $FALSE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item deauthenticateMacDefault
    
De-authenticate a MAC address from wireless network (including 802.1x).
    
Need to implement the CoA to remove the ACL and the redirect URL.

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    
    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }
    
    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    # TODO push Login-User => 1 (RFC2865) in pf::radius::constants if someone ever reads this 
    # (not done because it doesn't exist in current branch)
    return $self->radiusDisconnect( $mac );
}


=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($this, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => \&deauthenticateMacDefault,
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=item parseUrl

This is called when we receive a http request from the device and return specific attributes:

client mac address
SSID
client ip address
redirect url
grant url
status code

=cut

sub parseUrl {
    my($this, $req) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return ($$req->param('client_mac'),$$req->param('wlan'),$$req->param('client_ip'),$$req->param('redirect'),$$req->param('switch_url'),$$req->param('statusCode'));
}

=item returnRadiusAccessAccept

Overloading L<pf::Switch>'s implementation because AeroHIVE doesn't support
assigning VLANs and Roles at the same time.

=cut

sub returnRadiusAccessAccept {
    my ($this, $vlan, $mac, $port, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $radius_reply_ref = {};

    # TODO this is experimental
    try {

        $logger->debug("network device supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $this);

        # Roles are configured and the user should have one
        if (defined($role)) {
            $radius_reply_ref = {
                'Cisco-AVPair' => ["url-redirect-acl=$role","url-redirect=http://172.16.0.250"],
            };

            $logger->info("Returning ACCEPT with Role: $role");
        }


        # if Roles aren't configured, return VLAN information
        else {

            $radius_reply_ref = {
                'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
                'Tunnel-Type' => $RADIUS::VLAN,
                'Tunnel-Private-Group-ID' => $vlan,
            };

            $logger->info("Returning ACCEPT with VLAN: $vlan");
        }

    }
    catch {
        chomp($_);
        $logger->debug(
            "Exception when trying to resolve a Role for the node. Returning VLAN attributes in RADIUS Access-Accept. "
            . "Exception: $_"
        );

        $radius_reply_ref = {
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => $vlan,
        };
    };

    return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
}

=item radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Optionally you can provide other attributes as an hashref.

Uses L<pf::util::radius> for the low-level RADIUS stuff.

=cut

# TODO consider whether we should handle retries or not?


sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # Where should we send the RADIUS CoA-Request?
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
            LocalAddr => $management_network->tag('vip'),
        };

        $logger->debug("network device supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        my $acctsessionid = node_accounting_current_sessionid($mac);
        my $node_info = node_attributes($mac);
        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        # Roles are configured and the user should have one
        if (defined($role) && (defined($node_info->{'status'}) ) ) {

            $logger->info("Returning ACCEPT with Role: $role");
            my $vsa = [
                {
                vendor => "Cisco",
                attribute => "Cisco-AVPair",
                value => "audit-session-id=$acctsessionid",
                },
                vendor => "Cisco",
                attribute => "Cisco-AVPair",
                value => "subscriber:command=reauthenticate",
                },
                vendor => "Cisco",
                attribute => "Cisco-AVPair",
                value => "subscriber:reauthenticate-type=last",
                }
            ];
            $response = perform_coa($connection_info, $attributes_ref, $vsa);

        }
        else {
            $response = perform_disconnect($connection_info, $attributes_ref);
        }
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
