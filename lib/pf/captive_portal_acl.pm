package pf::captive_portal_acl;

=head1 NAME

pf::captive_portal_acl - access lists confining the registration and isolation networks to the captive portal

=head1 DESCRIPTION

Generates, for the registration and isolation roles, the access list a switch
mapping roles to access lists ("Role by Access List") returns to a device of
that role: it only lets the device reach what it needs to go through the
captive portal, and denies everything else, so devices parked in the
registration or isolation network can't reach each other (#7824).

The access list permits:

=over

=item DHCP (UDP 67 and 68) to any destination, the server can be a relay;

=item DNS (UDP and TCP 53) and the portal (TCP 80 and 443) to every address
of PacketFence a device can use: the IP and virtual IP of the internal
interfaces and of the interfaces running the portal, plus the DNS servers of
the networks of that type (registration or isolation);

=item the passthroughs of that type (C<fencing.passthroughs>, the domains of the
OAuth and billing sources and of the provisioners for registration,
C<fencing.isolation_passthroughs> for isolation), resolved when the access list
is built. Wildcard passthroughs can't be expressed in an access list and are
skipped.

=back

and ends with a deny of everything. It is enabled per role with
C<fencing.registration_access_list> and C<fencing.isolation_access_list>.

=cut

use strict;
use warnings;

use List::MoreUtils qw(uniq);
use pf::log;
use pf::constants;
use pf::constants::role qw($REGISTRATION_ROLE $ISOLATION_ROLE);
use pf::config qw(
    %Config
    %ConfigNetworks
    @internal_nets
    @portal_ints
);
use pf::util qw(isenabled resolve valid_ip);
use pf::util::dns;

our %SETTING = (
    $REGISTRATION_ROLE => 'registration_access_list',
    $ISOLATION_ROLE    => 'isolation_access_list',
);

our %PASSTHROUGHS = (
    $REGISTRATION_ROLE => \%pf::util::dns::passthroughs,
    $ISOLATION_ROLE    => \%pf::util::dns::isolation_passthroughs,
);

our @PORTAL_PORTS = (80, 443);

# The resolved passthroughs are kept for a minute per process, so a burst of
# devices joining the registration network doesn't resolve every domain again
our $PASSTHROUGHS_CACHE_TTL = 60;
our %PASSTHROUGHS_CACHE;

=head2 enabled

Whether the generated access list is enabled for a role (registration or
isolation only)

=cut

sub enabled {
    my ($role) = @_;
    my $setting = $SETTING{$role // ''};
    return defined $setting && isenabled($Config{fencing}{$setting} // 'disabled');
}

=head2 acls

The access list of a role for a switch, as an array ref of ACL lines in the
switch's ACL template, or undef when it isn't enabled for that role

=cut

sub acls {
    my ($switch, $role) = @_;
    return undef unless enabled($role);
    my @acls = (
        $switch->generateACL({allow => 1, proto => 'udp', dst_port => 67}),
        $switch->generateACL({allow => 1, proto => 'udp', dst_port => 68}),
    );
    foreach my $address (addresses($role)) {
        push @acls, $switch->generateACL({allow => 1, proto => 'udp', dst_host => $address, dst_port => 53});
        push @acls, $switch->generateACL({allow => 1, proto => 'tcp', dst_host => $address, dst_port => 53});
        push @acls, map { $switch->generateACL({allow => 1, proto => 'tcp', dst_host => $address, dst_port => $_}) } @PORTAL_PORTS;
    }
    foreach my $passthrough (passthroughs($role)) {
        push @acls, $switch->generateACL({allow => 1, proto => $passthrough->{proto}, dst_host => $passthrough->{address}, dst_port => $passthrough->{port}});
    }
    push @acls, $switch->generateACL({allow => 0, proto => 'ip'});
    # the template leaves a trailing space when there is no port
    s/\s+$// for @acls;
    return \@acls;
}

=head2 addresses

The addresses of PacketFence a device of the role can use for DNS and the
portal, sorted and unique

=cut

sub addresses {
    my ($role) = @_;
    my @addresses;
    foreach my $interface (@internal_nets, @portal_ints) {
        push @addresses, $interface->tag('ip'), $interface->tag('vip');
    }
    push @addresses, network_dns_servers($role);
    return sort { $a cmp $b } uniq grep { defined $_ && valid_ip($_) } @addresses;
}

=head2 network_dns_servers

The DNS servers of the networks of the role's type: the registration (and DNS
enforcement) networks, or the isolation networks

=cut

sub network_dns_servers {
    my ($role) = @_;
    my $is_type = ($role // '') eq $ISOLATION_ROLE
        ? \&pf::config::is_network_type_vlan_isol
        : sub { pf::config::is_network_type_vlan_reg($_[0]) || pf::config::is_network_type_dns_enforcement($_[0]) };
    return map { split(/\s*,\s*/, $ConfigNetworks{$_}{dns} // '') } grep { $is_type->($_) } keys %ConfigNetworks;
}

=head2 passthroughs

The passthroughs of the role resolved to addresses: a list of hashes with
address, proto (tcp or udp) and port, in the order of the configuration

=cut

sub passthroughs {
    my ($role) = @_;
    my $cached = $PASSTHROUGHS_CACHE{$role // ''};
    return @{ $cached->{entries} } if $cached && $cached->{expires} > time;
    my @entries = _resolve_passthroughs($role);
    $PASSTHROUGHS_CACHE{$role // ''} = { entries => \@entries, expires => time + $PASSTHROUGHS_CACHE_TTL };
    return @entries;
}

sub _resolve_passthroughs {
    my ($role) = @_;
    my $logger = get_logger;
    my $passthroughs = $PASSTHROUGHS{$role // ''};
    return () unless $passthroughs;
    my @entries;
    foreach my $domain (sort keys %{ $passthroughs->{normal} // {} }) {
        my $addresses = valid_ip($domain) ? [$domain] : resolve($domain);
        unless ($addresses && @$addresses) {
            $logger->warn("Unable to resolve the passthrough $domain: it is left out of the $role access list");
            next;
        }
        foreach my $port_spec (uniq @{ $passthroughs->{normal}{$domain} }) {
            my ($proto, $port) = split(/:/, $port_spec);
            next unless defined $port && $port =~ /^\d+$/;
            push @entries, map { { address => $_, proto => $proto, port => $port } } sort { $a cmp $b } uniq @$addresses;
        }
    }
    my @wildcards = sort keys %{ $passthroughs->{wildcard} // {} };
    if (@wildcards) {
        $logger->debug("Wildcard passthroughs can't be expressed in the $role access list, skipping: " . join(', ', map { "*.$_" } @wildcards));
    }
    return @entries;
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
