#!/usr/bin/perl

=head1 NAME

cluster

=head1 DESCRIPTION

pf::kafka::cluster: every server of the cluster is a Kafka broker, the broker
only ones are left out of the controller quorum

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 20;
use Test::Exception;
use pf::kafka::cluster;

#This test will running last
use Test::NoWarnings;

my $listeners = 'INTERNAL://0.0.0.0:29092,CONTROLLER://0.0.0.0:9093,EXTERNAL://0.0.0.0:9092,PF://0.0.0.0:9095,PFCONNECTOR://0.0.0.0:9096';

# Two zones: pf1, pf2 and pf3 in DC1, pf4 in DC2
my @servers = (
    { host => 'pf4', management_ip => '198.51.100.4' },
    { host => 'pf1', management_ip => '192.0.2.1' },
    { host => 'pf2', management_ip => '192.0.2.2' },
    { host => 'pf3', management_ip => '192.0.2.3' },
);

sub by_host {
    my ($plan) = @_;
    return { map { $_->{host} => $_ } @{$plan->{members}} };
}

# Every server is a controller
my $plan = pf::kafka::cluster::plan(servers => \@servers, listeners => $listeners);
is_deeply([map { $_->{host} } @{$plan->{members}}], [qw(pf1 pf2 pf3 pf4)], 'every server of every zone is a member');
is_deeply([map { $_->{node_id} } @{$plan->{members}}], [1, 2, 3, 4], 'node IDs follow the host names');
is($plan->{quorum_voters}, '1@192.0.2.1:9093,2@192.0.2.2:9093,3@192.0.2.3:9093,4@198.51.100.4:9093', 'every server votes');
is($plan->{replication_factor}, 3, 'replication factor: majority of the brokers');
is(by_host($plan)->{pf4}{advertised_listeners}, 'INTERNAL://198.51.100.4:29092,EXTERNAL://198.51.100.4:9092,PF://198.51.100.4:9095,PFCONNECTOR://127.0.0.1:9096', 'brokers advertise their management IP');
ok(!exists by_host($plan)->{pf1}{process_roles}, 'a controller keeps the roles of the cluster section');

# pf4 is broker only
$plan = pf::kafka::cluster::plan(servers => \@servers, listeners => $listeners, broker_only_hosts => ['pf4']);
my $pf4 = by_host($plan)->{pf4};
is($plan->{quorum_voters}, '1@192.0.2.1:9093,2@192.0.2.2:9093,3@192.0.2.3:9093', 'a broker only server does not vote');
is($pf4->{process_roles}, 'broker', 'a broker only server has the broker role only');
is($pf4->{listeners}, 'INTERNAL://0.0.0.0:29092,EXTERNAL://0.0.0.0:9092,PF://0.0.0.0:9095,PFCONNECTOR://0.0.0.0:9096', 'a broker only server has no controller listener');
is($plan->{replication_factor}, 3, 'a broker only server still holds replicas');
is(scalar @{$plan->{members}}, 4, 'a broker only server is still a member');

# The node IDs already assigned are kept, a new server gets the next one
$plan = pf::kafka::cluster::plan(
    servers => \@servers,
    listeners => $listeners,
    node_ids => { pf1 => 3, pf2 => 1, pf3 => 2, gone => 7 },
);
my $members = by_host($plan);
is_deeply([map { $members->{$_}{node_id} } qw(pf1 pf2 pf3 pf4)], [3, 1, 2, 4], 'existing node IDs are kept, the new server gets the next free one');

# A duplicated or invalid node ID is reassigned
$plan = pf::kafka::cluster::plan(servers => \@servers, listeners => $listeners, node_ids => { pf1 => 1, pf2 => 1, pf3 => 'x' });
$members = by_host($plan);
is_deeply([map { $members->{$_}{node_id} } qw(pf1 pf2 pf3 pf4)], [1, 2, 3, 4], 'duplicated and invalid node IDs are reassigned');

# Unknown broker only servers are reported
$plan = pf::kafka::cluster::plan(servers => \@servers, listeners => $listeners, broker_only_hosts => ['pf9', '']);
is_deeply($plan->{warnings}, ['Broker only server pf9 is not a member of the cluster, ignoring it'], 'an unknown broker only server is reported');
is(scalar(grep { $_->{controller} } @{$plan->{members}}), 4, 'an unknown broker only server changes nothing');

# At least one controller
throws_ok {
    pf::kafka::cluster::plan(servers => \@servers, listeners => $listeners, broker_only_hosts => [qw(pf1 pf2 pf3 pf4)]);
} qr/No server left in the Kafka controller quorum/, 'every server broker only is refused';

# The controller listeners can be renamed
is(
    pf::kafka::cluster::broker_listeners('CTRL://0.0.0.0:9093,PF://0.0.0.0:9095,QUORUM://0.0.0.0:9094', 'CTRL, QUORUM'),
    'PF://0.0.0.0:9095',
    'every controller listener is removed'
);
is(pf::kafka::cluster::broker_listeners($listeners, undef), 'INTERNAL://0.0.0.0:29092,EXTERNAL://0.0.0.0:9092,PF://0.0.0.0:9095,PFCONNECTOR://0.0.0.0:9096', 'CONTROLLER by default');

# Standalone
$plan = pf::kafka::cluster::plan(servers => [], listeners => $listeners);
is_deeply($plan->{members}, [], 'no server, no member');

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
