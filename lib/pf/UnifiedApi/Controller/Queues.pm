package pf::UnifiedApi::Controller::Queues;

=head1 NAME

pf::UnifiedApi::Controller::Queues -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Queues

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::pfqueue::stats;


sub stats {
    my ($self) = @_;
    my $stats = pf::pfqueue::stats->new;
    # build hashref
    my %queue = ();
    foreach my $item (@{ $stats->queue_counts }) {
        $queue{$item->{name}} = { count => $item->{count}, outstanding => [], expired => [] };
    }
    foreach my $item (@{ $stats->counters }) {
        push @{ $queue{$item->{queue}}{outstanding} }, { name => $item->{name}, count => $item->{count} };
    }
    foreach my $item (@{ $stats->miss_counters }) {
        push @{ $queue{$item->{queue}}{expired} }, { name => $item->{name}, count => $item->{count} };
    }
    #build json
    my $json = [];
    while( my( $key, $value ) = each %queue ){
        # rebuild hash,
        #   replace empty []'s w/ undef
        push @{ $json }, { queue => $key, stats => $value };
    }
    
    return $self->render(status => 200, json => { items => $json });
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
