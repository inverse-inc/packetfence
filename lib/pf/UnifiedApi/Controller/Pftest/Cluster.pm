package pf::UnifiedApi::Controller::Pftest::Cluster;

=head1 NAME

pf::UnifiedApi::Controller::Pftest::Cluster -

=cut

=head1 DESCRIPTION

Cluster fan-out wrapper around pf::UnifiedApi::Controller::Pftest. Without
`cluster: true` in the body — or on standalone installs — only the local
node runs the subcommand and the response is wrapped as a single
{items: [{host, ...}]} payload so the frontend always sees the same shape.

Fan-out is opt-in because one `pftest authentication` run means a *real*
bind attempt against the configured sources on every node: N attempts per
click can trip account-lockout policies and looks like a distributed
brute force from the directory's perspective. When fanning out, the local
share runs in-process and the remaining peers are called in parallel via
Mojo::IOLoop subprocesses, so total wall-clock matches the slowest peer
rather than the sum. Authentication runs are additionally rate-limited
per tested user (see pf::UnifiedApi::Controller::Pftest).

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
    # Opt-in: without `cluster: true` only the local node is tested. The
    # flag is removed from the body so the per-peer calls cannot recurse.
    my $fan_out = delete $body->{cluster};

    # Entry-point rate limit: one authentication run per tested user per
    # window, checked before any work (and before the fan-out multiplies
    # it). The local share below runs in-process so this check cannot
    # trip itself; remote peers enforce their own window on their public
    # endpoint as defense in depth.
    if ($action eq 'authentication') {
        my $user = $body->{user};
        if (defined $user && length $user
            && pf::UnifiedApi::Controller::Pftest::auth_rate_limit_exceeded($user)) {
            return $self->render(
                json   => pf::UnifiedApi::Controller::Pftest::rate_limited_json(),
                status => 429,
            );
        }
    }

    # run_* are package subs (pure functions of the body) — no controller
    # instance needed, so no shared tx/stash state to worry about.
    my $runner = pf::UnifiedApi::Controller::Pftest->can("run_$action");

    if (!$pf::cluster::cluster_enabled || !$fan_out) {
        my $resp = $runner->($body);
        if ($resp->{status} != 200) {
            return $self->render(json => $resp->{json}, status => $resp->{status});
        }
        return $self->render(json => {
            items => [{
                # || not //: get_host_id() is '' on standalone installs.
                host => pf::cluster::get_host_id() || 'localhost',
                %{$resp->{json}},
            }],
        });
    }

    my $host_id = pf::cluster::get_host_id() || 'localhost';
    my @servers = grep { ($_->{host} // '') ne $host_id } pf::cluster::enabled_servers();
    my @promises;

    # Local share: same subprocess pattern as the peers so a slow source
    # cannot block the event loop, but in-process — no HTTP hop to
    # ourselves and no second rate-limit hit on this node.
    {
        my $sub = Mojo::IOLoop->subprocess;
        my $p   = $sub->run_p(sub {
            my $resp = $runner->($body);
            if ($resp->{status} != 200) {
                # Validation error — shape it like a failed item so it is
                # visible instead of silently flattened into the 200 list.
                my $msg = $resp->{json}{message} // 'validation failed';
                return {
                    host       => $host_id,
                    output     => "ERROR: $msg",
                    output_raw => "ERROR: $msg",
                    exit_code  => -1,
                };
            }
            return { host => $host_id, %{$resp->{json}} };
        });
        push @promises, $p->catch(sub {
            my ($err) = @_;
            chomp $err;
            return {
                host       => $host_id,
                output     => "ERROR in subprocess: $err",
                output_raw => "ERROR in subprocess: $err",
                exit_code  => -1,
            };
        });
    }

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
