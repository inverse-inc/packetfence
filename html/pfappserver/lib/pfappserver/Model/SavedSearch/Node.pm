package pfappserver::Model::SavedSearch::Node;
=head1 NAME

package pfappserver::Model::SavedSearch add documentation

=cut

=head1 DESCRIPTION

SavedSearch

=cut

use strict;
use warnings;
use Moose;

use pf::savedsearch;

sub create {
    my ($self,$saved_search) = @_;
    $saved_search->{namespace} = 'SavedSearch::Node';
    savedsearch_add($saved_search);
}

sub read {
    my ($self,$id);
    return savedsearch_view($id);
}

sub read_all {
    my ($self,$pid) = @_;
    return savedsearch_for_pid_and_namespace($pid,'SavedSearch::Node');
}

sub update {
    my ($self,undef,$saved_search) = @_;
    return savedsearch_update($saved_search);
}

sub remove {
    my ($self,$saved_search) = @_;
    return savedsearch_update($saved_search);
}

__PACKAGE__->meta->make_immutable;

=back

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

