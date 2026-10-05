package pf::firewallsso;

=head1 NAME

pf::firewallsso

=cut

=head1 DESCRIPTION

Sends firewall SSO request to pfsso engine

=cut

use strict;
use warnings;

use pf::api::jsonrpcclient;
use pf::config qw(
    %ConfigFirewallSSO
    %Config
);
use pf::constants qw(
    $TRUE
);
use pf::constants::api;
use pf::constants::firewallsso qw($UNKNOWN);
use pf::log;
use pf::node();
use pf::util();
use pf::CHI;


=head1 SUBROUTINES

=over


=item do_sso

=cut

sub do_sso {
    my ( %postdata ) = @_;
    my $logger = pf::log::get_logger();

    unless ( scalar keys %ConfigFirewallSSO && pf::util::isenabled($Config{'services'}{'pfsso'}) ) {
        $logger->debug("Trying to do firewall SSO without any firewall SSO configured. Exiting");
        return;
    }

    # A VPN session has no MAC address: the caller gives the status and the
    # role of the user, and the endpoint that identifies the session.
    my $mac = pf::util::clean_mac($postdata{mac});
    my $has_mac = pf::util::valid_mac($mac);
    my $node = $has_mac ? pf::node::node_attributes($mac) : {};

    if ($has_mac) {
        $logger->info("Sending a firewall SSO '$postdata{method}' request for MAC '$mac' and IP '$postdata{ip}'");
    } else {
        $mac = $postdata{endpoint} // '';
        $logger->info("Sending a firewall SSO '$postdata{method}' request for endpoint '$mac' and IP '$postdata{ip}'");
    }
    my $username;
    if (exists($postdata{username}) && !pf::util::valid_mac($postdata{username})) {
        $username = $postdata{username};
    } else {
        $username = $node->{pid};
    }
    my ($stripped_username, $realm) = pf::util::strip_username($username);
    my $apiClient = pf::api::unifiedapiclient->management_client;
    if (!pf::util::isenabled($Config{'active_active'}{'firewall_sso_on_management'})) {
        $apiClient = pf::api::unifiedapiclient->default_client;
    }

    $apiClient->call("POST", "/api/v1/firewall_sso/".lc($postdata{method}), {
        ip                => $postdata{ip},
        mac               => $mac,
        # All values must be string for pfsso
        timeout           => ($postdata{timeout} // "" ) ."",
        role              => $postdata{role} // $node->{category},
        username          => $username,
        stripped_username => $stripped_username,
        realm             => $realm,
        status            => $postdata{status} // $node->{status},
        device_version    => $node->{device_version} || $UNKNOWN,
        device_class      => $node->{device_class} || $UNKNOWN,
        device_type       => $node->{device_type} || $UNKNOWN,
        computername      => $node->{computername} || $UNKNOWN,
        source            => ($postdata{source} // "" ) ."",
    });

    return $TRUE;
}

=head2 vpn_role_cache_key

The key of the role of a VPN user in the accounting cache

=cut

sub vpn_role_cache_key {
    my ($nas_ip, $username) = @_;
    return "vpn_role:" . ($nas_ip // '') . ":" . lc($username // '');
}

=head2 cache_vpn_role

Remember the role given to a VPN user when it was authorized, for the firewall
SSO of its accounting: a VPN session has no MAC address, so no node to read the
role from.

=cut

sub cache_vpn_role {
    my ($nas_ip, $username, $role) = @_;
    return if !defined($username) || $username eq '' || !defined($role) || $role eq '';
    pf::CHI->new(namespace => 'accounting')->set(vpn_role_cache_key($nas_ip, $username), $role, "24 hours");
}

=head2 vpn_role

The role given to a VPN user when it was authorized

=cut

sub vpn_role {
    my ($nas_ip, $username) = @_;
    return pf::CHI->new(namespace => 'accounting')->get(vpn_role_cache_key($nas_ip, $username));
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

