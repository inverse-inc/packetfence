package pf::Switch::Cisco::Catalyst_2960_http;
=head1 NAME

pf::Switch::Cisco::Catalyst_2960_http - Object oriented module to parse and manage
Catalyst 2960 with http redirect

=head1 STATUS

Developped and tested on IOS 15.0(2)SE5

=head1 SUPPORTS

=head2 Deauthentication with RADIUS Disconnect (RFC3576)

=head1 BUGS AND LIMITATIONS

=head2 Version specific issues

=head1 SEE ALSO

=cut

use strict;
use warnings;

use Log::Log4perl;
use Net::SNMP;
use Net::Telnet;
use Try::Tiny;

use base ('pf::Switch::Cisco::Catalyst_2960');

use pf::constants;
use pf::config;
use pf::Switch::constants;
use pf::util;

use pf::roles::custom;
use pf::accounting qw(node_accounting_current_sessionid);
use pf::util::radius qw(perform_coa perform_disconnect);
use pf::node qw(node_attributes node_view);
use pf::web::util;
use pf::violation qw(violation_count_trap);
use pf::locationlog;

sub description { 'Cisco Catalyst 2960 with Web Auth' }

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported


sub supportsRoleBasedEnforcement { return $TRUE; }
sub supportsExternalPortal { return $TRUE; }
sub supportsWiredMacAuth { return $TRUE; }

# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=head2 handleReAssignVlanTrapForWiredMacAuth

Called when a ReAssignVlan trap is received for a switch-port in Wired MAC Authentication.

=cut

sub handleReAssignVlanTrapForWiredMacAuth {
    my ($this, $ifIndex, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $this->radiusDisconnect($mac);
}

=head2 parseUrl

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

=head2 returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($this) = @_;

    return 'Airespace-ACL-Name';
}

=head2 returnRadiusAccessAccept

Overide to support the captive portal special RADIUS accept

=cut

sub returnRadiusAccessAccept {
    my ($this, $vlan, $mac, $port, $connection_type, $user_name, $ssid, $wasInline, $user_role) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $radius_reply_ref = {};

    # If we're doing 802.1x then instead of doing web auth, we'll do classic VLAN isolation
    # This allows to have different VLANs for the roles
    if ($connection_type == $WIRED_802_1X){
        $radius_reply_ref = {
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => $vlan,
        };

        return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
    }

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
                $session_id{switch_id} = $this->{_id};
                pf::locationlog::locationlog_set_session($mac, $session_id{_session_id});
                $radius_reply_ref = {
                    'User-Name' => $mac,
                    'Cisco-AVPair' => ["url-redirect-acl=$role","url-redirect=".$this->{'_portalURL'}."/cep$session_id{_session_id}"],
                };
            }
            $logger->info("[$mac] (".$this->{'_id'}.") Returning ACCEPT with Role: $role");
        }


        # if Roles aren't configured, return VLAN information
        else {

            $radius_reply_ref = {
                'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
                'Tunnel-Type' => $RADIUS::VLAN,
                'Tunnel-Private-Group-ID' => $vlan,
            };

            $logger->info("[$mac] (".$this->{'_id'}.") Returning ACCEPT with VLAN: $vlan");
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

=head2 radiusDisconnect

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
            "[$mac] Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    my $send_disconnect_to = $self->{'_ip'}; 
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $management_network->tag('vip'),
            nas_port => '3799',
        };

        $logger->debug("[$mac] network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");
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

            $response = perform_coa($connection_info, $attributes_ref, [{ 'vendor' => 'Cisco', 'attribute' => 'Cisco-AVPair', 'value' => 'subscriber:command=reauthenticate' }]);
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
        $logger->warn("[$mac] Unable to perform RADIUS CoA-Request on (".$self->{'_id'}.") : $_");
        $logger->error("[$mac] Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.") ...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

    $logger->warn(
        "[$mac] Unable to perform RADIUS Disconnect-Request on (".$self->{'_id'}.")."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}


=head2 parseRequest

Redefinition of pf::Switch::parseRequest due to specific attribute being used for webauth

=cut

sub parseRequest {
    my ( $this, $radius_request ) = @_;
    my $client_mac      = clean_mac($radius_request->{'Calling-Station-Id'});
    my $user_name       = $radius_request->{'TLS-Client-Cert-Common-Name'} || $radius_request->{'User-Name'};
    my $nas_port_type   = $radius_request->{'NAS-Port-Type'};
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );
    
    my $session_id;
    if (defined($radius_request->{'Cisco-AVPair'})) {
        if ($radius_request->{'Cisco-AVPair'} =~ /audit-session-id=(.*)/ig ) {
            $session_id =$1;
        }
    }
    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, $session_id);
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

