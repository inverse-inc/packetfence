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

The virtual IPs of the cluster as seen by this server

=cut

sub vips_local {
    my ($self) = @_;
    $self->render(json => { item => { host => $host_id, vips => pf::cluster::vips_status() } });
}

=head2 vips

The virtual IPs of the cluster with the server(s) currently holding them

=cut

sub vips {
    my ($self) = @_;
    my (%vips, @servers);
    foreach my $server ($cluster_enabled ? pf::cluster::enabled_servers() : ()) {
        my $result = eval {
            my $client = pf::api::unifiedapiclient->new;
            $client->host($server->{management_ip});
            $client->call("GET", "/api/v1/cluster/vips/local", {});
        };
        my %info = (host => $server->{host}, management_ip => $server->{management_ip});
        if ($@ || ref($result) ne 'HASH' || ref($result->{item}) ne 'HASH') {
            my $error = $@ || 'Invalid response';
            chomp($error);
            $self->log->warn("Unable to get the virtual IPs status of $server->{host}: $error");
            push @servers, { %info, error => "Unable to get the virtual IPs status" };
            next;
        }

        my $server_vips = $result->{item}{vips} // [];
        push @servers, { %info, vips => $server_vips };
        foreach my $v (@$server_vips) {
            my $vip = $vips{$v->{vip}} //= {
                vip        => $v->{vip},
                interface  => $v->{interface},
                management => $v->{management},
                owners     => [],
                since      => undef,
            };
            next unless $v->{owner};
            push @{$vip->{owners}}, $server->{host};
            if (defined $v->{since} && ($v->{state} // '') eq 'master') {
                $vip->{since} = $v->{since} if !defined $vip->{since} || $v->{since} > $vip->{since};
            }
        }
    }

    $self->render(json => {
        items   => [ map { $vips{$_} } sort keys %vips ],
        servers => \@servers,
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
