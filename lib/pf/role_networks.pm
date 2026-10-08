package pf::role_networks;

=head1 NAME

pf::role_networks - networks associated to a role across the switch configuration

=cut

=head1 DESCRIPTION

A role ACL may name another role as its destination instead of a network:

    #permit ip any net Printer

The line is commented out so that a switch module that does not know the
C<net E<lt>RoleE<gt>> keyword ignores it. This module expands such a line into
one ACL per CIDR network mapped to the destination role (the C<E<lt>RoleE<gt>Network>
attribute of every switch with C<NetworkMap> enabled), merging adjacent networks.

The role to networks map is kept in the C<role_networks> distributed cache, one
entry per role. It is populated when the switch configuration is committed
(see L<pf::ConfigStore::Switch>) and only the roles whose networks changed are
rewritten, so a device connecting never has to walk the switch configuration.
A cache miss falls back to a computation from the current switch configuration
and primes the cache.

=cut

use strict;
use warnings;

use NetAddr::IP;
use pf::log;
use pf::CHI;
use pf::util();
use pfconfig::cached_hash;

our $CACHE_NAMESPACE = 'role_networks';

# Key holding the list of roles currently cached, so a refresh can drop the
# roles that no longer have any network.
our $ROLES_INDEX_KEY = '__roles__';

# A destination written as "net <Role>" in a commented out ACL. The line may
# carry a direction prefix and anything after the role (ports, flags).
our $NET_ROLE_RE = qr/^#\s*((?:in\||out\|)?)(.*?)\s+net\s+(\S+)(.*)$/;

tie our %SwitchConfig, 'pfconfig::cached_hash', 'config::Switch';

=head1 SUBROUTINES

=head2 cache

The CHI cache holding the role to networks map.

=cut

sub cache {
    return pf::CHI->new(namespace => $CACHE_NAMESPACE);
}

=head2 compute_role_networks

Compute the role to networks map from a switch configuration hash (the
C<config::Switch> pfconfig namespace). Only switches with C<NetworkMap>
enabled are considered, IPv6 networks are skipped and the networks of a role
are merged when they are adjacent.

Returns a hashref: role => [ 'cidr', ... ] (sorted).

=cut

sub compute_role_networks {
    my ($switches) = @_;
    my $logger = get_logger();
    my %raw;
    for my $id (keys %{$switches // {}}) {
        next if $id eq 'default' || $id =~ /^group /;
        my $switch = $switches->{$id};
        next if !defined $switch || ref($switch) ne 'HASH';
        next unless pf::util::isenabled($switch->{NetworkMap});
        my $networks = $switch->{networks};
        next unless ref($networks) eq 'HASH';
        for my $role (keys %$networks) {
            my $value = $networks->{$role};
            next unless defined $value && length $value;
            for my $network (split /\s*[,\s]\s*/, $value) {
                next unless length $network;
                my $ip = NetAddr::IP->new($network);
                if (!defined $ip) {
                    $logger->warn("Invalid network '$network' for role $role on switch $id, skipping it");
                    next;
                }
                next if $ip->version != 4;
                push @{$raw{$role}}, $ip->network;
            }
        }
    }

    my %result;
    while (my ($role, $ips) = each %raw) {
        my @merged = NetAddr::IP::Compact(@$ips);
        $result{$role} = [ sort map { $_->cidr } @merged ];
    }
    return \%result;
}

=head2 refresh_cache

Recompute the role to networks map from the switch configuration and store in
the cache the roles whose networks changed. Roles that no longer have any
network are removed from the cache.

Takes the switch configuration hash; defaults to the C<config::Switch>
namespace. Returns the list of roles that were updated or removed.

=cut

sub refresh_cache {
    my ($switches) = @_;
    my $logger = get_logger();
    $switches //= \%SwitchConfig;
    my $map = compute_role_networks($switches);
    my $cache = cache();
    my $known = $cache->get($ROLES_INDEX_KEY) // [];
    my @changed;

    while (my ($role, $networks) = each %$map) {
        my $current = $cache->get($role);
        if (ref($current) eq 'ARRAY' && _same_networks($current, $networks)) {
            next;
        }
        $cache->set($role, $networks);
        $logger->info("Networks of role $role updated: " . join(",", @$networks));
        push @changed, $role;
    }

    for my $role (@$known) {
        next if exists $map->{$role};
        $cache->remove($role);
        $logger->info("Role $role has no network anymore, removed from the cache");
        push @changed, $role;
    }

    $cache->set($ROLES_INDEX_KEY, [ sort keys %$map ]);
    return @changed;
}

sub _same_networks {
    my ($current, $new) = @_;
    return 0 if @$current != @$new;
    for my $i (0 .. $#$current) {
        return 0 if $current->[$i] ne $new->[$i];
    }
    return 1;
}

=head2 networks_for_role

The CIDR networks of a role, from the cache. On a miss the networks of that
role are computed from the switch configuration and cached, a role without
any network as an empty list so the switch configuration is not walked again
for it. Other entries are left alone: only L</refresh_cache>, run when the
switch configuration is committed, rewrites or removes them.

Returns an arrayref, empty when the role has no network.

=cut

sub networks_for_role {
    my ($role) = @_;
    return [] unless defined $role && length $role;
    my $cache = cache();
    my $networks = $cache->get($role);
    return $networks if ref($networks) eq 'ARRAY';

    get_logger->debug("Networks of role $role not in the cache, computing them from the switch configuration");
    $networks = compute_role_networks(\%SwitchConfig)->{$role} // [];
    $cache->set($role, $networks);
    return $networks;
}

=head2 acl_destinations

Format the networks of a role as ACL destinations: C<host A.B.C.D> for a /32,
C<A.B.C.D W.X.Y.Z> (address and wildcard) otherwise.

=cut

sub acl_destinations {
    my ($role) = @_;
    my @destinations;
    for my $cidr (@{networks_for_role($role)}) {
        my $ip = NetAddr::IP->new($cidr) or next;
        if ($ip->masklen == 32) {
            push @destinations, "host " . $ip->addr;
        } else {
            my ($addr, $wildcard) = $ip->wildcard;
            push @destinations, "$addr $wildcard";
        }
    }
    return @destinations;
}

=head2 expand_acls

Replace every C<#... net E<lt>RoleE<gt> ...> line of an ACL text with one
uncommented line per network of the role. A line whose role has no network is
left untouched (still commented out) so the switch module skips it.

Takes and returns the ACL text (lines separated by newlines).

=cut

sub expand_acls {
    my ($acls) = @_;
    return $acls unless defined $acls && $acls =~ /\snet\s/;
    my @expanded;
    for my $line (split /\n/, $acls) {
        if ($line =~ $NET_ROLE_RE) {
            my ($direction, $before, $role, $after) = ($1, $2, $3, $4);
            my @destinations = acl_destinations($role);
            if (!@destinations) {
                get_logger->warn("No network found for destination role $role, skipping ACL: $line");
                push @expanded, $line;
                next;
            }
            $after =~ s/\s+$//;
            push @expanded, map { "$direction$before $_$after" } @destinations;
            next;
        }
        push @expanded, $line;
    }
    return join("\n", @expanded);
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
