package pf::web::client_ip;

=head1 NAME

pf::web::client_ip - IP address of the client of the captive portal

=head1 DESCRIPTION

The captive portal is reached through haproxy-portal (and optionally load
balancers in front of PacketFence), which add the client IP address to the
X-Forwarded-For header. The header is only used when the request comes from
one of these trusted proxies, and the client IP address is the right-most
address of the header that is not a trusted proxy.

=cut

use strict;
use warnings;
use Readonly;
use pf::config qw(%CAPTIVE_PORTAL $management_network);
use pf::cluster qw($cluster_enabled);
use pf::log;

Readonly our $CONTAINERS_GATEWAY_IP => '100.64.0.1';

=head2 trusted_proxies

The addresses of the proxies whose X-Forwarded-For header is used: the load
balancers (captive_portal.loadbalancers_ip), the local host (loopback and the
containers gateway), the management IP and VIP, and the IPs of the cluster
members (their haproxy-portal can forward the requests to this server)

=cut

sub trusted_proxies {
    my %trusted = %{ $CAPTIVE_PORTAL{'loadbalancers_ip'} // {} };
    $trusted{$_} = 1 for ('127.0.0.1', '::1', $CONTAINERS_GATEWAY_IP);
    if ($management_network) {
        for my $tag (qw(ip vip)) {
            my $ip = $management_network->tag($tag);
            $trusted{$ip} = 1 if $ip;
        }
    }

    if ($cluster_enabled) {
        for my $server (pf::cluster::enabled_servers()) {
            for my $section (grep { /^interface / } keys %$server) {
                my $ip = $server->{$section}{ip};
                $trusted{$ip} = 1 if $ip;
            }
        }
    }

    return \%trusted;
}

=head2 is_trusted_proxy

Whether an IP address is one of the trusted proxies

=cut

sub is_trusted_proxy {
    my ($ip, $trusted) = @_;
    return 0 unless defined($ip) && length($ip);
    $trusted //= trusted_proxies();
    return exists $trusted->{$ip} ? 1 : 0;
}

=head2 client_ip

The IP address of the client from the address of the peer and the
X-Forwarded-For header (a comma separated list, possibly several header lines
joined with a comma): the peer when it isn't a trusted proxy, else the
right-most address of the header that isn't a trusted proxy, else the peer.

    my $ip = client_ip($remote_address, $x_forwarded_for);

=cut

sub client_ip {
    my ($peer, $forwarded_for, $trusted) = @_;
    $trusted //= trusted_proxies();
    if (!is_trusted_proxy($peer, $trusted)) {
        return $peer;
    }

    my @hops = grep { length } map { s/^\s+|\s+$//gr } split(/,/, $forwarded_for // '');
    for my $hop (reverse @hops) {
        return $hop if !is_trusted_proxy($hop, $trusted);
    }

    return $peer;
}

=head2 is_internal_preview

Whether the request comes from the portal preview of the admin interface:
haproxy-admin sets X-Forwarded-For-Packetfence to 127.0.0.1, and
haproxy-portal removes that header from the requests of the clients.

=cut

sub is_internal_preview {
    my ($peer, $forwarded_for_packetfence, $trusted) = @_;
    return 0 unless defined($forwarded_for_packetfence) && $forwarded_for_packetfence eq '127.0.0.1';
    return is_trusted_proxy($peer, $trusted);
}

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
