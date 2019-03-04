package pf::pfmon::task::cleanup_chi_database_cache;

=head1 NAME

pf::pfmon::task::cleanup_chi_database_cache - class for pfmon task cleanup chi database cache

=cut

=head1 DESCRIPTION

pf::pfmon::task::cleanup_chi_database_cache

=cut

use strict;
use warnings;
use pf::log;
use pf::dal::chi_cache;
use pf::error qw(is_error);
use Moose;
extends qw(pf::pfmon::task);

has 'batch' => ( is => 'rw', default => 1000 );
has 'timeout' => ( is => 'rw', default => 10 );


my $logger = get_logger();

=head2 run

run the cleanup chi database cache task

=cut

sub run {
    my ($self) = @_;
    my $batch = $self->batch;
    my $time_limit = $self->timeout;
    my $now        = pf::dal->now();
    my %search = (
        -where => {
            expires_at  => {
                "<=" => $now,
            },
        },
        -limit => $batch,
    );
    pf::dal::chi_cache->batch_remove(\%search, $time_limit);

    $logger->debug("Done expiring database CHI cache");
}

=head1 AUTHOR


Inverse inc. <info@inverse.ca>

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

1;
