package pf::connector::radius_cache;

=head1 NAME

pf::connector::radius_cache

=head1 DESCRIPTION

Invalidation of the RADIUS replies the remote connectors cache.

A connector-remote in cache-first mode answers the MAB requests of a device
from the reply PacketFence gave it last time, without asking PacketFence
again. Whenever a device's access may have changed (registration, role,
status, security event, bypass settings, deletion...), PacketFence calls
L</invalidate> and every remote connector drops the device's cached replies,
so the device's next request reaches PacketFence and is cached again.

The call is best-effort and asynchronous (a pfqueue job), except right before
a CoA/Disconnect (C<< sync => 1 >>): the entry must be gone before the device
re-authenticates, otherwise it would be answered from the stale reply until
the connector's own freshness limit.

Every remote connector is told (broadcast): a device may have roamed to
another site, and a delete of an unknown device costs nothing. The connectors
are grouped by the pfconnector server instance holding their tunnel, so a
classic install makes one HTTP call.

=cut

use strict;
use warnings;

use pf::log;
use pf::util qw(clean_mac valid_mac isenabled);
use pf::config qw(%Config);
use pf::AtFork;

our $DEDUP_WINDOW = 2;    # seconds: the hooks overlap (node_modify + reevaluate_access + deauth)

my %recent;               # mac => time of the last asynchronous request, per process

sub CLONE {
    %recent = ();
}

pf::AtFork->add_to_child(\&CLONE);
CLONE();

=head2 enabled

Whether PacketFence invalidates the connectors' RADIUS cache at all: there must
be remote connectors, and C<pfconnector.radius_cache_invalidation> must not be
disabled.

=cut

sub enabled {
    return 0 if !isenabled($Config{pfconnector}{radius_cache_invalidation} // 'enabled');
    require pf::factory::connector;
    return pf::factory::connector->has_remote_connectors ? 1 : 0;
}

=head2 invalidate

  pf::connector::radius_cache::invalidate(\@macs, %opts)

Drops the cached replies of the devices on every remote connector. Options:

  sync   => 1          do it now (before a CoA/Disconnect) instead of queueing a job
  reason => 'string'   logged, for the audit trail

Returns the number of devices for which a request was made or queued.

=cut

sub invalidate {
    my ($macs, %opts) = @_;
    return 0 if !enabled();
    my @macs = _clean_macs($macs);
    return 0 if !@macs;
    if ($opts{sync}) {
        return invalidate_now(\@macs, %opts);
    }
    my $now = time;
    @macs = grep { !defined $recent{$_} || $now - $recent{$_} >= $DEDUP_WINDOW } @macs;
    return 0 if !@macs;
    $recent{$_} = $now for @macs;
    # keep the per-process memory small
    delete @recent{ grep { $now - $recent{$_} >= $DEDUP_WINDOW } keys %recent } if keys %recent > 1000;
    require pf::api::queue;
    pf::api::queue->new(queue => 'priority')->notify('pfconnector_radius_cache_invalidate', macs => \@macs, reason => $opts{reason});
    return scalar @macs;
}

=head2 invalidate_now

  pf::connector::radius_cache::invalidate_now(\@macs, %opts)

Does the work: one POST per pfconnector server instance holding tunnels, each
with the connectors it owns. Errors are logged and swallowed (the connector's
freshness limit bounds the staleness of a lost invalidation, and the server
keeps undelivered invalidations for a connector's next connection).

=cut

sub invalidate_now {
    my ($macs, %opts) = @_;
    my $logger = get_logger();
    my @macs = _clean_macs($macs);
    return 0 if !@macs;
    my $groups = _connectors_by_server();
    return 0 if !%$groups;
    my $reason = $opts{reason} // 'unknown';
    for my $server (sort keys %$groups) {
        my ($client, @ids) = @{ $groups->{$server} };
        eval {
            $client->call("POST", "/api/v1/pfconnector/radius-cache-invalidate", {
                connector_ids => \@ids,
                macs          => \@macs,
                sync          => $opts{sync} ? \1 : \0,
            });
        };
        if ($@) {
            $logger->warn("Failed to ask connector(s) " . join(", ", @ids) . " to drop the cached RADIUS replies of " . join(", ", @macs) . " ($reason): $@");
        }
        else {
            $logger->info("Asked connector(s) " . join(", ", @ids) . " to drop the cached RADIUS replies of " . join(", ", @macs) . " ($reason)" . ($opts{sync} ? ", synchronously" : ""));
        }
    }
    return scalar @macs;
}

=head2 _clean_macs

Cleans and deduplicates the MAC addresses, dropping the invalid ones.

=cut

sub _clean_macs {
    my ($macs) = @_;
    my %seen;
    my @out;
    for my $mac (@{ $macs // [] }) {
        my $clean = clean_mac($mac // '');
        next if !defined $clean || !valid_mac($clean) || $seen{$clean}++;
        push @out, $clean;
    }
    return @out;
}

=head2 _connectors_by_server

The remote connectors, grouped by the pfconnector server instance holding
their tunnel: { "host:port" => [ $client, @connector_ids ] }.

=cut

sub _connectors_by_server {
    require pf::factory::connector;
    require pf::ConfigStore::Connector;
    my %groups;
    for my $id (@{ pf::ConfigStore::Connector->new->readAllIds // [] }) {
        next if $id eq 'local_connector';
        my $connector = pf::factory::connector->new($id) or next;
        my ($client) = $connector->connectorServerApiClientWithOwnership;
        next if !$client;
        my $key = join(":", $client->proto // '', $client->host // '', $client->port // '');
        $groups{$key} //= [$client];
        push @{ $groups{$key} }, $id;
    }
    return \%groups;
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
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;
