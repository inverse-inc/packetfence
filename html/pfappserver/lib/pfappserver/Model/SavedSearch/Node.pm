package pfappserver::Model::SavedSearch::Node;
=head1 NAME

package pfappserver::Model::SavedSearch

=cut

=head1 DESCRIPTION

SavedSearch

=cut

use strict;
use warnings;
use Moose;
use pf::savedsearch;
use URI;
use URI::QueryParam;

=head2 Methods

=over

=item create

=cut

sub create {
    my ($self,$saved_search) = @_;
    $saved_search->{namespace} = 'SavedSearch::Node';
    savedsearch_add($saved_search);
}

=item read

=cut

sub read {
    my ($self,$id);
    return _expand_query(savedsearch_view($id));
}

=item read_all

=cut

sub read_all {
    my ($self,$pid) = @_;
    return map { _expand_query($_) } savedsearch_for_pid_and_namespace($pid,'SavedSearch::Node');
}

=item update

=cut

sub update {
    my ($self,undef,$saved_search) = @_;
    return savedsearch_update($saved_search);
}

=item remove

=cut

sub remove {
    my ($self,$saved_search) = @_;
    return savedsearch_update($saved_search);
}

=item _expand_query

=cut

sub _expand_query {
    my ($saved_search) = @_;
    my $uri = URI->new($saved_search->{query});
    $saved_search->{form} = $uri->query_form_hash;
    $saved_search->{path} = $uri->path;
    return $saved_search;
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

