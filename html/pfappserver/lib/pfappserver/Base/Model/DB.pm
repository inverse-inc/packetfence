package pfappserver::Base::Model::DB;

=head1 NAME

pfappserver::Base::Model::DB

=cut

=head1 DESCRIPTION

pfappserver::Base::Model::DB
Is the Base class for Rose DB catalyst models

=cut

use Moose;
use namespace::autoclean;
use pf::log;
use Module::Load;
use HTTP::Status qw(:constants :is);

BEGIN { extends 'Catalyst::Model'; }

=head1 FIELDS

=head2 configStore

=cut

=head2 manager

The Rose::DB manager object

=cut

has manager => ( is => 'ro', lazy => 1, builder => '_build_manager' );

=head2 managerClassName

The name of the class of the Rose::DB

=cut

has managerClassName => ( is => 'ro' );

=head2 idKey

The key of the id attribute

=cut

has idKey => ( is => 'ro', default => 'id' );

=head2 itemKey

The key of a single item

=cut

has itemKey => ( is => 'ro', default => 'item' );

=head2 itemsKey

The key of the list of items

=cut

has itemsKey => ( is => 'ro', default => 'items' );

=head1 METHODS

=head2 _build_manager

=cut

sub _build_manager {
    my ($self) = @_;
    load $self->managerClassName;
    return $self->managerClassName;
}

=head2 readAllIds

Get all the sections names

=cut

sub readAllIds {
    my ($self) = @_;
    my ( $status, $status_msg );
    my $primaryKey = $self->primaryKey;
    return ( HTTP_OK,
        [ map { $_->$primaryKey } $self->manager->get_objects ] );
}

sub primaryKey {
    my ($self) = @_;
    return ( $self->manager->object_class->meta->primary_key_column_names() )
      [0];
}

=head2 readAll

Get all the sections as an array of hash refs

=cut

sub readAll {
    my ( $self, $pageNum, $perPage ) = @_;
    get_logger->debug("$pageNum, $perPage");
    my $objects = $self->manager->get_objects(
        page     => $pageNum,
        per_page => $perPage,
    );
    return ( HTTP_OK, $objects );
}

sub countAll {
    my ( $self ) = @_;
    $self->manager->get_objects_count();
}

=head2 hasId

If config has a section

=cut

sub hasId {
    my ( $self, $id ) = @_;
    my ( $status, $status_msg );
    my $primaryKey = $self->primaryKey;
    if ($self->manager->get_objects_count( query => [ $primaryKey => $id ] ) )
    {
        $status = HTTP_OK;
        $status_msg = [ "[_1] exists", $id ];
    } else {
        $status = HTTP_NOT_FOUND;
        $status_msg = [ "[_1] does not exists", $id ];
    }
    return ( $status, $status_msg );
}

=head2 read

reads a section

=cut

sub read {
    my ( $self, $id ) = @_;
    my $status     = HTTP_OK;
    my $primaryKey = $self->primaryKey;
    my ($result) =
      $self->manager->get_objects( query => [ $primaryKey => $id ] );
    if (@$result) {
        $result = pop @$result;
    } else {
        $result = [ "error reading [_1]", $id ];
        $status = HTTP_PRECONDITION_FAILED;
    }

    return ( $status, $result );
}

=head2 update

Update/edit/modify an existing section

=cut

sub update {
    my ( $self, $id, $assignments ) = @_;
    my $primaryKey = $self->primaryKey;
    my $object = $self->manager->object_class->new( $primaryKey => $id );
    my ( $status, $status_msg );
    if ( $object->load( speculative => 1 ) ) {
        delete $assignments->{ $self->idKey };
        delete $assignments->{$primaryKey};
        $object->init(%$assignments);
        if ( $object->save ) {
            $status = HTTP_OK;
            $status_msg = [ "[_1] successfully modified", $id ];
        } else {
            $status = HTTP_INTERNAL_SERVER_ERROR;
            $status_msg = [ "error modifying [_1]", $id ];
        }
    } else {
        $status = HTTP_NOT_FOUND;
        $status_msg = [ "error modifying [_1]", $id ];
    }
    return ( $status, $status_msg );
}

=head2 create

To create

=cut

sub create {
    my ( $self, $id, $assignments ) = @_;
    my ( $status, $status_msg );
    my $primaryKey = $self->primaryKey;
    delete $assignments->{ $self->idKey };
    my $object =
      $self->manager->object_class->new( %$assignments, $primaryKey => $id );
    $assignments->{$primaryKey} = $assignments;
    if ( $object->save( insert => 1 ) ) {
        $status = HTTP_OK;
        $status_msg = [ "[_1] successfully created", $id ];
    } else {
        $status = HTTP_PRECONDITION_FAILED;
        $status_msg = [ "[_1] already exists", $id ];
    }
    return ( $status, $status_msg );
}

=head2 update_or_create

=cut

sub update_or_create {
    my ( $self, $id, $assignments ) = @_;
    my $primaryKey = $self->primaryKey;
    if ($self->manager->get_objects_count( query => [ $primaryKey => $id ] ) )
    {
        return $self->update( $id, $assignments );
    } else {
        return $self->create( $id, $assignments );
    }
}

=head2 remove

Removes an existing item

=cut

sub remove {
    my ( $self, $id ) = @_;
    my ( $status, $status_msg );
    my $primaryKey = $self->primaryKey;
    my $object = $self->manager->object_class->new( $primaryKey => $id );
    if ( $object->delete ) {
        $status = HTTP_OK;
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
    my ( $self, $from, $to ) = @_;
    my ( $status, $status_msg );
    my $config = $self->configStore;
    if ( $config->copy( $from, $to ) ) {
        $status = HTTP_OK;
        $status_msg = [ '"[_1]" successfully copied to [_2]', $from, $to ];
    } else {
        $status_msg = [ '"[_]" already exists', $to ];
        $status = HTTP_PRECONDITION_FAILED;
    }
    return ( $status, $status_msg );
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

sub ACCEPT_CONTEXT {
    my ( $self, $c, %args ) = @_;
    return $self->new( \%args );
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

