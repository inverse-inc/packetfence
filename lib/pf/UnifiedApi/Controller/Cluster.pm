package pf::UnifiedApi::Controller::Cluster;

=head1 NAME

pf::UnifiedApi::Controller::Cluster -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Cluster

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::cluster;
use pf::api::unifiedapiclient;
use pf::log;
use Mojo::IOLoop;
use Mojo::Promise;

# a member that doesn't answer within this time is reported as unreachable
use constant VIPS_CONNECT_TIMEOUT_MS => 3_000;
use constant VIPS_TIMEOUT_MS => 10_000;

sub config {
    my ($self) = @_;
    $self->render(json => { item => \%ConfigCluster });
}

sub servers {
    my ($self) = @_;
    my @servers = pf::cluster::config_enabled_servers;
    $self->render(json => { items => \@servers });
}

=head2 vips_local

The virtual IPs of the cluster zone of this server as seen by this server

=cut

sub vips_local {
    my ($self) = @_;
    $self->render(json => { item => { host => $host_id, zone => $cluster_name, vips => pf::cluster::vips_status() } });
}

=head2 vips

The virtual IPs of the cluster, in every zone, with the server(s) currently
holding them (see pf::cluster::aggregate_vips_status)

The members are queried in parallel, each with a connection and a transfer
timeout, so an unreachable or hung member only shows as an error instead of
holding the request (and a worker) until it answers.

=cut

sub vips {
    my ($self) = @_;
    my @servers = $cluster_enabled ? pf::cluster::config_enabled_servers() : ();
    unless (@servers) {
        return $self->render(json => { items => [], servers => [] });
    }

    my @promises;
    foreach my $server (@servers) {
        my %info = (
            host          => $server->{host},
            management_ip => $server->{management_ip},
            zone          => $pf::cluster::clusters_hostname_map{$server->{host}},
        );
        if (($server->{host} // '') eq $host_id) {
            push @promises, Mojo::Promise->resolve({ %info, zone => $cluster_name, vips => pf::cluster::vips_status() });
            next;
        }
        push @promises, Mojo::IOLoop->subprocess->run_p(sub { fetch_member_vips($server, \%info) })->catch(sub {
            my ($err) = @_;
            chomp($err);
            get_logger->warn("Unable to get the virtual IPs status of $info{host}: $err");
            return { %info, error => "Unable to get the virtual IPs status" };
        });
    }

    $self->render_later;
    Mojo::Promise->all(@promises)->then(sub {
        my @members = map { $_->[0] } @_;
        $self->render(json => {
            items   => pf::cluster::aggregate_vips_status(\@members),
            servers => \@members,
        });
    })->catch(sub {
        my ($err) = @_;
        get_logger->error("Unable to get the virtual IPs status of the cluster: " . ($err // 'unknown error'));
        $self->render_error(500, "Unable to get the virtual IPs status of the cluster");
    });
    return;
}

=head2 fetch_member_vips

Query the virtual IPs status of a member of the cluster (vips_local)

=cut

sub fetch_member_vips {
    my ($server, $info) = @_;
    my $client = pf::api::unifiedapiclient->new(
        host               => $server->{management_ip},
        connect_timeout_ms => VIPS_CONNECT_TIMEOUT_MS,
        timeout_ms         => VIPS_TIMEOUT_MS,
    );
    my $result = eval { $client->call("GET", "/api/v1/cluster/vips/local", {}) };
    if ($@ || ref($result) ne 'HASH' || ref($result->{item}) ne 'HASH') {
        my $error = $@ || 'Invalid response';
        chomp($error);
        get_logger->warn("Unable to get the virtual IPs status of $info->{host}: $error");
        return { %$info, error => "Unable to get the virtual IPs status" };
    }
    return { %$info, zone => $result->{item}{zone} // $info->{zone}, vips => $result->{item}{vips} // [] };
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
