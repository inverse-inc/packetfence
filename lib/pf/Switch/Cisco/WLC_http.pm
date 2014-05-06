package pf::Switch::Cisco::WLC_http;
=head1 NAME

pf::Switch::Cisco::WLC_http - Object oriented module to parse manage
Cisco Wireless Controllers (WLC) and Wireless Service Modules (WiSM) with http redirect

=head1 STATUS

Developed and tested on firmware version 7.6.100 (should work on 7.4.100).
With CWA mode (not available for LWA)

=over

=item Supports

=over

=item Deauthentication with RADIUS Disconnect (RFC3576)

=back

=back

=head1 BUGS AND LIMITATIONS

=over

=item Version specific issues

=over

=back

=head1 SEE ALSO

=over

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
use pf::node qw(node_attributes node_view);
use pf::web::util;
use pf::violation qw(violation_count_trap);

sub description { 'Cisco Wireless Controller (WLC HTTP)' }

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
        $SNMP::RADIUS => 'deauthenticateMacDefault',
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
    my ($this, $vlan, $mac, $port, $connection_type, $user_name, $ssid, $wasInline, $user_role) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $radius_reply_ref = {};
    # TODO this is experimental
    try {

        my $role = $this->getRoleByName($user_role);
        # Roles are configured and the user should have one
        if (defined($role)) {
            my $node_info = node_view($mac);
            if ($node_info->{'status'} eq $pf::node::STATUS_REGISTERED) {
                $radius_reply_ref = {
                    'User-Name' => $mac,
                    $this->returnRoleAttribute => $role,
                };
            }
            else {
                my (%session_id);
                pf::web::util::session(\%session_id,undef,6);
                $session_id{client_mac} = $mac;
                $session_id{wlan} = $ssid;
                $session_id{switch} = \$this;
                $radius_reply_ref = {
                    'User-Name' => $mac,
                    'Cisco-AVPair' => ["url-redirect-acl=$role","url-redirect=".$this->{'_portalURL'}."/cep$session_id{_session_id}"],
                };
            }
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
            nas_port => '1700',
        };

        $logger->debug("network device supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        my $acctsessionid = node_accounting_current_sessionid($mac);
        my $node_info = node_view($mac);
        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        # Standard Attributes

        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
            'NAS-Port' => $node_info->{'last_port'},
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        # Roles are configured and the user should have one.
        # We send a regular disconnect if there is an open trapping violation
        # to ensure the VLAN is actually changed to the isolation VLAN.
        if (  defined($role) &&
            ( violation_count_trap($mac) == 0 )  &&
            ( $node_info->{'status'} eq 'reg' )
           ) {
            $logger->info("Returning ACCEPT with Role: $role");

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
                {
                vendor => "Cisco",
                attribute => "Cisco-AVPair",
                value => "subscriber:reauthenticate-type=last",
                }
            ];
            $response = perform_coa($connection_info, $attributes_ref, $vsa);

        }
        else {
            $connection_info = {
                nas_ip => $send_disconnect_to,
                secret => $self->{'_radiusSecret'},
                LocalAddr => $management_network->tag('vip'),
                nas_port => '3799',
            };
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


=item parseRequest

Takes FreeRADIUS' RAD_REQUEST hash and process it to return
NAS Port type (Ethernet, Wireless, etc.)
Network Device IP
EAP
MAC
NAS-Port (port)
User-Name

=cut

sub parseRequest {
    my ($this, $radius_request) = @_;
    my $client_mac = clean_mac($radius_request->{'Calling-Station-Id'});
    my $user_name = $radius_request->{'User-Name'};
    my $nas_port_type = $radius_request->{'NAS-Port-Type'};
    my $port = $radius_request->{'NAS-Port'};
    my $eap_type = 0;
    if (exists($radius_request->{'EAP-Type'})) {
        $eap_type = $radius_request->{'EAP-Type'};
    }
    my $nas_port_id;
    if (defined($radius_request->{'NAS-Port-Id'})) {
        $nas_port_id = $radius_request->{'NAS-Port-Id'};
    }
    my $session_id;
    if (defined($radius_request->{'Cisco-AVPair'})) {
        if ($radius_request->{'Cisco-AVPair'} =~ /audit-session-id=(.*)/ig ) {
            $session_id =$1;
        }
    }
    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, $session_id);
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

