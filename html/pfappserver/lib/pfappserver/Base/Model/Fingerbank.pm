package pfappserver::Base::Model::Fingerbank;

=head1 NAME

pfappserver::Base::Model::Fingerbank

=cut

=head1 DESCRIPTION

pfappserver::Base::Model::Fingerbank

=cut

use Moose;
use namespace::autoclean;
use pf::log;
use pf::util qw(calc_page_count);
use HTTP::Status qw(:constants :is);

extends 'pfappserver::Base::Model::Config';

has fingerbankModel => (is => 'ro' , required => 1);

has scope => (is => 'rw', required => 1, default => sub { 'Upstream' } );

has search_fields => (is => 'rw', default => sub {[qw(value)]});

=head1 FIELDS

=cut

=head2 readAll

Get all the sections as an array of hash refs

=cut

sub readAll {
    my ( $self, $pageNum, $perPage ) = @_;
    $pageNum = 1 if $pageNum <= 0;
    my $offset = ($pageNum - 1) * $perPage;
    my ($status, $results) = $self->fingerbankModel->list_paginated({offset => $offset, nb_of_rows => $perPage, order => 'asc', order_by => 'id', schema => $self->scope });
    unless(is_success($status)) {
        get_logger->error($results);
        $results = [];
    }
    return ( HTTP_OK, $results );
}

sub countAll {
    my ( $self ) = @_;
    return $self->fingerbankModel->count($self->scope);
}

=head2 hasId

If config has a section

=cut

sub hasId {
    my ( $self, $id ) = @_;
    my ( $status, $status_msg );
    unless (defined $id)
    {
        $status = HTTP_NOT_FOUND;
        $status_msg = "Id is not valid";
    }
    else
    {
        if ( $self->fingerbankModel->read_hashref($id))
        {
            $status = HTTP_OK;
            $status_msg = [ "[_1] exists", $id ];
        }
        else {
            $status = HTTP_NOT_FOUND;
            $status_msg = [ "[_1] does not exists", $id ];
        }
    }
    return ( $status, $status_msg );
}

=head2 read

read an entry from the fingerbank model

=cut

sub read {
    my ( $self, $id ) = @_;
    my ( $status, $result );
    unless (defined $id)
    {
        $status = HTTP_NOT_FOUND;
        $result = "Id is not valid";
    }
    else
    {
        ($status, $result ) = $self->fingerbankModel->read_hashref($id);
        if ( $status != HTTP_OK )
        {
            $result = [ "[_1] does not exists", $id ];
        }
    }

    return ( $status, $result );
}

=head2 update

Update/edit/modify an existing section

=cut

sub update {
    my ( $self, $id, $assignments ) = @_;
    my $status_msg;
    my ($status,$return) = $self->fingerbankModel->update($id, $assignments);
    if($status == HTTP_OK )
    {
        $status_msg = [ "[_1] successfully modified", $id ];
    }
    else
    {
        $status_msg = [ "error modifying [_1]", $id ];
    }
    return ( $status, $status_msg );
}

=head2 create

To create

=cut

sub create {
    my ( $self, $id, $assignments ) = @_;
    my $status_msg;
    my ($status,$return) = $self->fingerbankModel->create($assignments);
    if ( $status == HTTP_OK) {
        $status_msg = [ "[_1] successfully created", $id ];
    }
    else {
        $status_msg = [ "[_1] already exists", $id ];
    }
    return ( $status, $status_msg );
}

=head2 update_or_create

=cut

sub update_or_create {
    my ( $self, $id, $assignments ) = @_;
    my $primaryKey = $self->primaryKey;
    my ($status,undef) = $self->fingerbankModel->read_hashref($id);
    if ( $status == HTTP_OK)
    {
        return $self->update( $id, $assignments );
    }
    else {
        return $self->create( $id, $assignments );
    }
}

=head2 remove

Removes an existing item

=cut

sub remove {
    my ( $self, $id ) = @_;
    my ( $status, $status_msg );
    $status = $self->fingerbankModel->delete($id);
    if ( $status == HTTP_OK ) {
        $status_msg = [ "removed [_1]", $id ];
    } else {
        $status = HTTP_PRECONDITION_FAILED;
        $status_msg = [ "error removing [_1]", $id ];
    }
    return ( $status, $status_msg );
}

=head2 Copy

Copies a section

=cut

sub copy {
    my ($self, $from, $to) = @_;
    my ($status, $status_msg);
    $status     = HTTP_BAD_REQUEST;
    $status_msg = "Items cannot be copy";
    return ($status, $status_msg);
}

=head2 renameItem

=cut

sub renameItem {
    my ( $self, $old, $new ) = @_;
    my ( $status, $status_msg );
    $status     = HTTP_BAD_REQUEST;
    $status_msg = "Items cannot be renamed";
    return ( $status, $status_msg );
}

=head2 sortItems

Sorting the items

=cut

sub sortItems {
    my ( $self, $items ) = @_;
    my ( $status, $status_msg );
    $status     = HTTP_BAD_REQUEST;
    $status_msg = "Items cannot be resorted";
    return ( $status, $status_msg );
}

=head2 commit

=cut

sub commit {
    my ($self) = @_;
    my ( $status, $status_msg );
    $status     = HTTP_OK;
    $status_msg = "Changes successfully commited";
    return ( $status, $status_msg );
}

=head2 search

=cut

sub search {
    my ($self, $query, $options) = @_;
    my $pageNum  = delete $options->{pageNum} || 1;
    my $rows     = delete $options->{perPage};
    my $offset   = ($pageNum - 1 ) * $rows;
    my $order    = delete $options->{direction} || 'asc';
    my $order_by = delete $options->{by};
    my $extra    = {offset => $offset, rows => $rows, order_by => { -asc  => 'id'}};
    my %results;
    my ($status, $resultSets_or_errormsg) = $self->fingerbankModel->search([$query,$extra], $self->scope);
    unless (is_success($status)) {
        return ($status, $resultSets_or_errormsg);
    }
    my @items;
    foreach my $resultset ( @$resultSets_or_errormsg ) {
        while ( my $row = $resultset->next ) {
            push ( @items, $row );
        }
    }
    ($status, $resultSets_or_errormsg) = $self->fingerbankModel->search([$query], $self->scope);
    unless (is_success($status)) {
        return ($status, $resultSets_or_errormsg);
    }
    my $count = 0;
    foreach my $resultset ( @$resultSets_or_errormsg ) {
        $count += $resultset->count;
    }
    $results{items} = \@items;
    $results{page_count} = calc_page_count($count, $rows);
    return ($status,\%results);
}

=head2 ACCEPT_CONTEXT

Create the fingerbank model using the current catalyst context

=cut

sub ACCEPT_CONTEXT {
    my ( $self, $c, %args ) = @_;
    return $self->new(  { scope => $c->stash->{scope} || 'Upstream', %args } );
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

