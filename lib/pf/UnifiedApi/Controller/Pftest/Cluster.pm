package pf::UnifiedApi::Controller::Pftest::Cluster;

=head1 NAME

pf::UnifiedApi::Controller::Pftest::Cluster -

=cut

=head1 DESCRIPTION

Cluster fan-out wrapper around pf::UnifiedApi::Controller::Pftest. Runs
the requested subcommand on every enabled cluster peer in parallel using
Mojo::IOLoop subprocesses, so total wall-clock matches the slowest peer
rather than the sum. On standalone installs (cluster disabled) the local
controller is invoked in-process and the response is wrapped as a single
{items: [{host, ...}]} payload so the frontend always sees the same shape.

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use Mojo::IOLoop;
use Mojo::Promise;

use pf::cluster;
use pf::api::unifiedapiclient;
use pf::UnifiedApi::Controller::Pftest;
use pf::log;

use constant PEER_TIMEOUT_MS => 30_000;

sub authentication { $_[0]->_dispatch('authentication') }
sub profile_filter { $_[0]->_dispatch('profile_filter') }

sub _dispatch {
    my ($self, $action) = @_;
    my $body = $self->req->json // {};

    if (!$pf::cluster::cluster_enabled) {
        my $local = pf::UnifiedApi::Controller::Pftest->new(%$self);
        my $method = "_run_$action";
        my $resp = $local->$method($body);
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

    my @servers = pf::cluster::enabled_servers();
    my @promises;
    for my $server (@servers) {
        my $sub = Mojo::IOLoop->subprocess;
        my $p   = $sub->run_p(sub {
            my $client = pf::api::unifiedapiclient->new(
                host       => $server->{management_ip},
                timeout_ms => PEER_TIMEOUT_MS,
            );
            my $resp = eval { $client->call("POST", "/api/v1/pftest/$action", $body) };
            if ($@ || !$resp) {
                my $err = $@ || 'no response';
                chomp $err;
                return {
                    host       => $server->{host},
                    output     => "ERROR contacting peer: $err",
                    output_raw => "ERROR contacting peer: $err",
                    exit_code  => -1,
                };
            }
            return { host => $server->{host}, %$resp };
        });
        # run_p resolves with the subprocess result; convert any process-level
        # failure into a structured error so Promise->all does not short-circuit.
        push @promises, $p->catch(sub {
            my ($err) = @_;
            chomp $err;
            return {
                host       => $server->{host},
                output     => "ERROR in subprocess: $err",
                output_raw => "ERROR in subprocess: $err",
                exit_code  => -1,
            };
        });
    }

    $self->render_later;
    Mojo::Promise->all(@promises)->then(sub {
        my @items = map { $_->[0] } @_;
        $self->render(json => { items => \@items });
    })->catch(sub {
        my $err = shift // 'unknown error';
        get_logger->error("Pftest::Cluster fan-out failed: $err");
        $self->render_error(500, "Cluster fan-out failed: $err");
    });
    return;
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
