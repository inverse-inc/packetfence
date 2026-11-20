package pf::kafka::cluster;

=head1 NAME

pf::kafka::cluster - The members of the Kafka cluster of a PacketFence cluster

=head1 DESCRIPTION

Computes the Kafka configuration of each server of a PacketFence cluster,
every zone of a multi-zone cluster included. Kafka runs on every server, since
the PacketFence services use the broker of their own server. The servers listed
as broker only run Kafka without being part of the controller quorum.

=cut

use strict;
use warnings;
use List::Util qw(max);

our $DEFAULT_CONTROLLER_LISTENER_NAMES = 'CONTROLLER';

=head2 plan

    my $plan = pf::kafka::cluster::plan(
        servers           => [ { host => 'pf1', management_ip => '192.0.2.1' }, ... ],
        node_ids          => { pf1 => 1, ... },   # KAFKA_NODE_ID already assigned
        broker_only_hosts => [ 'pf4' ],
        listeners         => 'INTERNAL://0.0.0.0:29092,CONTROLLER://0.0.0.0:9093,...',
        controller_listener_names => 'CONTROLLER',
    );

Returns the members (host, node_id, mgmtip, controller, advertised_listeners,
and for the broker only ones process_roles and listeners), the quorum voters,
the replication factor of the offsets topic and the warnings to show.
A server keeps the node ID it already has, a new one gets the next free ID.
Dies when no server is left in the controller quorum.

=cut

sub plan {
    my (%args) = @_;
    my @servers = sort { $a->{host} cmp $b->{host} } @{ $args{servers} // [] };
    my %node_ids = %{ $args{node_ids} // {} };
    my %broker_only = map { $_ => 1 } grep { defined && length } @{ $args{broker_only_hosts} // [] };
    my %hosts = map { $_->{host} => 1 } @servers;
    my @warnings = map { "Broker only server $_ is not a member of the cluster, ignoring it" } sort grep { !$hosts{$_} } keys %broker_only;

    # Keep the IDs of the servers already in the Kafka cluster
    my %used;
    for my $server (@servers) {
        my $id = $node_ids{$server->{host}};
        if (defined $id && $id =~ /^\d+$/ && !$used{$id}) {
            $used{$id} = 1;
        } else {
            delete $node_ids{$server->{host}};
        }
    }
    # IDs of servers no longer in the cluster are also off-limits so a new server
    # won't reuse them and collide with their stale KRaft registration
    $used{$_} = 1 for grep { /^\d+$/ } grep { defined } values %node_ids;
    my $next_id = max(0, keys %used) + 1;

    my $controller_listener_names = $args{controller_listener_names} || $DEFAULT_CONTROLLER_LISTENER_NAMES;
    my $broker_listeners = broker_listeners($args{listeners}, $controller_listener_names);
    my @members;
    for my $server (@servers) {
        my $host = $server->{host};
        my $ip = $server->{management_ip};
        my $node_id = $node_ids{$host} // $next_id++;
        my $controller = $broker_only{$host} ? 0 : 1;
        my $member = {
            host => $host,
            node_id => $node_id,
            mgmtip => $ip,
            controller => $controller,
            # Every broker advertises its management IP for the PF listener:
            # a client connected to its local broker reaches the partition
            # leaders on the other servers through it.
            advertised_listeners => qq{INTERNAL://${ip}:29092,EXTERNAL://${ip}:9092,PF://${ip}:9095,PFCONNECTOR://127.0.0.1:9096},
        };
        if (!$controller) {
            $member->{process_roles} = 'broker';
            # A broker only server refuses to start with a controller listener
            $member->{listeners} = $broker_listeners;
        }
        push @members, $member;
    }

    my @controllers = grep { $_->{controller} } @members;
    die "No server left in the Kafka controller quorum: at least one server must not be broker only\n" if @servers && !@controllers;

    return {
        members => \@members,
        quorum_voters => join(",", map { "$_->{node_id}\@$_->{mgmtip}:9093" } sort { $a->{node_id} <=> $b->{node_id} } @controllers),
        replication_factor => int(@controllers / 2) + 1,
        warnings => \@warnings,
    };
}

=head2 broker_listeners

The listeners without the controller listeners

=cut

sub broker_listeners {
    my ($listeners, $controller_listener_names) = @_;
    my %controller = map { $_ => 1 } split /\s*,\s*/, ($controller_listener_names || $DEFAULT_CONTROLLER_LISTENER_NAMES);
    return join(",", grep { my ($name) = m{^([^:]+)://}; !defined($name) || !$controller{$name} } split /\s*,\s*/, ($listeners // ''));
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
