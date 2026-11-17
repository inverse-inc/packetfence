#!/usr/bin/perl

=head1 NAME

kafka-init - Initialize kafka.conf

=head1 DESCRIPTION

Generates the passwords and the cluster ID of kafka.conf. In a cluster, it
writes the configuration of every server of the cluster, all the zones of a
multi-zone cluster included: Kafka runs on every server. The servers listed in
broker_only_hosts of the general section run Kafka without being part of the
controller quorum.

The controller quorum is fixed when the Kafka cluster is created: after
changing the servers or the broker only ones, the Kafka data of every server
must be removed before restarting Kafka.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::file_paths qw($kafka_config_file);
use pf::IniFiles;
use pf::cluster qw($cluster_enabled @db_cluster_servers);
use pf::kafka::cluster;
use pfconfig::manager;
use Crypt::OpenSSL::Random;
use MIME::Base64;
use Data::UUID;

my $ini = pf::IniFiles->new(-file => $kafka_config_file);
my $changed = 0;
my @setup_values = (
    {
        section => 'admin',
        param => 'pass',
        default_val => '%admin_password%',
        new_val => sub {
            return unpack("H*", Crypt::OpenSSL::Random::random_bytes(16));
        }
    },
    {
        section => 'auth client',
        param => 'pass',
        default_val => '%client_password%',
        new_val => sub {
            return unpack("H*", Crypt::OpenSSL::Random::random_bytes(16));
        }
    },
    {
        section => 'cluster',
        param => 'CLUSTER_ID',
        default_val => '%uuid%',
        new_val => sub {
            my $uuid = Data::UUID->new->create_bin();
            my $cluster_id =  encode_base64($uuid, '');
            $cluster_id =~ tr|+/=|\-_|d;
            return $cluster_id;
        }
    },

);

for my $setup (@setup_values) {
    my $val = $ini->val($setup->{section}, $setup->{param});
    if ($val eq $setup->{default_val}) {
        $ini->setval($setup->{section}, $setup->{param}, $setup->{new_val}->());
        $changed |= 1;
    }
}

if ($cluster_enabled) {
    # Every server of the cluster, all the zones included
    my @servers = map { +{ host => $_->{host}, management_ip => $_->{management_ip} } } @db_cluster_servers;
    my %servers = map { $_->{host} => 1 } @servers;

    # The host sections are rebuilt, the node IDs already assigned are kept.
    # The other sections (cluster, iptables, general, ...) are left as is.
    my %node_ids;
    for my $section ($ini->Sections) {
        my $node_id = $ini->val($section, 'KAFKA_NODE_ID');
        next if !defined $node_id && !$servers{$section};
        $node_ids{$section} = $node_id if defined $node_id;
        $changed |= 1;
        $ini->DeleteSection($section);
    }

    my $plan = pf::kafka::cluster::plan(
        servers => \@servers,
        node_ids => \%node_ids,
        broker_only_hosts => [ split /\s*,\s*/, ($ini->val('general', 'broker_only_hosts') // '') ],
        listeners => $ini->val('cluster', 'KAFKA_LISTENERS'),
        controller_listener_names => $ini->val('cluster', 'KAFKA_CONTROLLER_LISTENER_NAMES'),
    );
    print STDERR "$_\n" for @{$plan->{warnings}};

    set_or_create($ini, 'cluster', 'KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR', $plan->{replication_factor});
    set_or_create($ini, 'cluster', 'KAFKA_CONTROLLER_QUORUM_VOTERS', $plan->{quorum_voters});
    my @ips;
    for my $member (@{$plan->{members}}) {
        push @ips, $member->{mgmtip};
        my $id = $member->{host};
        set_or_create($ini, $id, 'KAFKA_NODE_ID', $member->{node_id});
        set_or_create($ini, $id, 'KAFKA_ADVERTISED_LISTENERS', $member->{advertised_listeners});
        next if $member->{controller};
        set_or_create($ini, $id, 'KAFKA_PROCESS_ROLES', $member->{process_roles});
        set_or_create($ini, $id, 'KAFKA_LISTENERS', $member->{listeners});
    }

    set_or_create($ini, 'iptables', 'cluster_ips', join(",", @ips));
    set_or_create($ini, 'iptables', 'clients', join(",", @ips));
}

sub set_or_create {
    my ($ini, $section, $param, $val) = @_;
    $changed |= 1;
    if ($ini->exists($section, $param)) {
        $ini->setval($section, $param, $val);
    } else {
        $ini->newval($section, $param, $val);
    }
}

if ($changed) {
    $ini->RewriteConfig();
    # We edited kafka.conf directly on disk, so the pfconfig cache for this
    # namespace is now stale. Expire it so that downstream consumers
    # (e.g. `pfcmd service kafka generateconfig` building var/conf/kafka.env)
    # read the values we just wrote instead of the previous cached ones.
    pfconfig::manager->new->expire("config::Kafka");
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
