package pfappserver::Model::Pfqueue;

=head1 NAME

pfappserver::Model::Pfqueue - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;
use namespace::autoclean;
use pf::pfqueue::stats;

extends 'Catalyst::Model';

has stats => (
    is      => 'rw',
    default => sub {
        return pf::pfqueue::stats->new;
    },
    handles => [qw(counters miss_counters queue_counts)],
);

sub ACCEPT_CONTEXT {
    my ( $self, $c, @args ) = @_;
    return $self->new(@args);
}

=head1 METHODS

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
