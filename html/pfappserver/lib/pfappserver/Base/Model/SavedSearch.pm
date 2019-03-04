package pfappserver::Base::Model::SavedSearch;
=head1 NAME

pfappserver::Model::SavedSearch

=head1 DESCRIPTION

Base class for SavedSearch

Example usage:

package pfappserver::Model::SavedSearch::Type;

use Moose;

extends 'pfappserver::Base::Model::SavedSearch';

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

=head2 Methods

=over

=cut

use strict;
use warnings;
use Moose;

extends 'pfappserver::Base::Model';

use pf::savedsearch;
use HTML::FormHandler::Params;
use HTTP::Status qw(:constants is_error is_success);

=item namespace

Use the class name as the default namespace

=cut

sub namespace {
    my ($self_or_class) = @_;
    return ref($self_or_class) || $self_or_class;
};

=item create

Create a new saved search

=cut

sub create {
    my ($self,$id,$saved_search) = @_;
    $saved_search->{namespace} = $self->namespace;
    if (savedsearch_name_taken($saved_search)) {
        return ($STATUS::INTERNAL_SERVER_ERROR, "name is already taken");
    }
    if( savedsearch_add($saved_search) ) {
        return ($STATUS::OK,"");
    } else {
        return ($STATUS::INTERNAL_SERVER_ERROR,"cannot create saved search");
    }

}

=item read

read a saved search

=cut

sub read {
    my ($self,$id) = @_;
    my ($saved_search) =  savedsearch_view($id);
    if($saved_search) {
        return ($STATUS::OK,_expand_query($saved_search));
    } else {
        return ($STATUS::INTERNAL_SERVER_ERROR,"cannot read saved search");
    }
}

=item read_all

read all saved search

=cut

sub read_all {
    my ($self,$pid) = @_;
    return ($STATUS::OK, [map { _expand_query($_) } savedsearch_for_pid_and_namespace($pid,$self->namespace)]);
}

=item update

update a saved search

=cut

sub update {
    my ($self,undef,$saved_search) = @_;
    return savedsearch_update($saved_search);
}

=item remove

remove a saved search

=cut

sub remove {
    my ($self,$id,$saved_search) = @_;
    if(savedsearch_delete($id)) {
        return ($STATUS::OK,savedsearch_delete($saved_search));
    } else {
        return ($STATUS::INTERNAL_SERVER_ERROR,"cannot remove saved search");
    }
}

=item _expand_query

a helper function to expand query parts

=cut

sub _expand_query {
    my ($saved_search) = @_;
    my $params_handler =  HTML::FormHandler::Params->new;
    my $query = $saved_search->{query};
    my $has_hash = $query =~ s/^#//;
    my $uri = URI->new($query);
    my $form = $uri->query_form_hash;
    $saved_search->{form} = $form;
    $saved_search->{params} = $params_handler->expand_hash($form);
    $saved_search->{path} = ($has_hash ? '#' . $uri->path : $uri->path);
    return $saved_search;
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

=back

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

