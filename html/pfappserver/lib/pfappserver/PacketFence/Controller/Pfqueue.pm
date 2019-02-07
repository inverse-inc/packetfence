package pfappserver::PacketFence::Controller::Pfqueue;

=head1 NAME

pfappserver::PacketFence::Controller::Pfqueue - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use Readonly;
use URI::Escape::XS qw(uri_escape uri_unescape);
use namespace::autoclean;
use pf::cluster;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head2 index

=cut

sub index :Path : Args(0) {
    my ($self, $c) = @_;
    my $model = $c->model('Pfqueue');
    $c->stash({
        stats => $model->stats,
        hostname => $pf::cluster::host_id
    });
}

sub counters :Args {
    my ($self, $c) = @_;
    my $model = $c->model('Pfqueue');
    my $counters = [ map { $_->{count} > 0 } @{$model->counters} ];
    $c->stash({
        current_view => 'JSON',
        counters => $counters,
        miss_counters => $model->miss_counters,
    });
}

sub cluster :Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash({
        servers => pf::cluster::queue_stats(),
    });
}

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
