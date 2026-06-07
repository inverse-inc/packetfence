package pf::UnifiedApi::Controller::Logs::ClusterHistory;

=head1 NAME

pf::UnifiedApi::Controller::Logs::ClusterHistory -

=cut

=head1 DESCRIPTION

Cluster fan-out wrapper around pf::UnifiedApi::Controller::Logs::History.
On standalone installs (cluster disabled) it runs the local query
in-process and wraps the response as a single-item list, so the frontend
always sees the same {items: [{host, events, cursor}]} shape regardless
of topology.

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';

use pf::cluster;
use pf::api::unifiedapiclient;
use pf::UnifiedApi::Controller::Logs::History;
use pf::log;

sub query {
    my ($self) = @_;
    my $body = $self->req->json // {};

    if (!$pf::cluster::cluster_enabled) {
        my $local = pf::UnifiedApi::Controller::Logs::History->new(%$self);
        my $resp  = $local->_query($body);
        if ($resp->{status} != 200) {
            return $self->render(json => $resp->{json}, status => $resp->{status});
        }
        return $self->render(json => {
            items => [{
                host => pf::cluster::get_host_id() // 'localhost',
                %{$resp->{json}},
            }],
        });
    }

    my @items;
    my @errors;
    for my $server (pf::cluster::enabled_servers()) {
        my $client = pf::api::unifiedapiclient->new(
            host       => $server->{management_ip},
            timeout_ms => 30_000,
        );
        my $resp = eval { $client->call("POST", "/api/v1/logs/history", $body) };
        if ($@ || !$resp) {
            my $err = $@ || 'unknown error';
            get_logger->warn("ClusterHistory: peer $server->{host} failed: $err");
            push @errors, { host => $server->{host}, error => "$err" };
            push @items,  { host => $server->{host}, events => [], cursor => {} };
            next;
        }
        push @items, { host => $server->{host}, %$resp };
    }

    return $self->render(json => {
        items  => \@items,
        errors => \@errors,
    });
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
