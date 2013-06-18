package pfappserver::Base::Model::Config;

=head1 NAME

pfappserver::Base::Model::Config

=cut

=head1 DESCRIPTION

pfappserver::Base::Model::Config
Is the Generic class for the cached config

=cut

use Moose;
use namespace::autoclean;
use pf::config::cached;
use pf::log;
use HTTP::Status qw(:constants :is);

BEGIN { extends 'Catalyst::Model'; }

=head1 FIELDS

=head2 configStore

=cut

has configStore => (
   is => 'ro',
   lazy => 1,
   isa => 'pf::ConfigStore',
   builder => '_buildConfigStore'
);

has configStoreClass => (is => 'ro');

=head2 idKey

The key of the id attribute

=cut

has idKey => ( is => 'ro', default => 'id');

=head2 itemKey

The key of a single item

=cut

has itemKey => ( is => 'ro', default => 'item');

=head2 itemsKey

The key of the list of items

=cut

has itemsKey => ( is => 'ro', default => 'items');

=head2 configFile

=cut

has configFile => ( is => 'ro');


=head1 METHODS

=head2 rollback

Rollback changes that were made

=cut

sub rollback {
    my ($self) = @_;
    my ($status, $status_msg);
    my $config = $self->configStore;
    $config->Rollback();
    return (HTTP_OK,"Config rollbacked");
}

=head2 readAllIds

Get all the sections names

=cut

sub readAllIds {
    my ($self) = @_;
    my ($status, $status_msg);
    my $config = $self->configStore;
    my @sections = $config->_Sections();
    return (HTTP_OK, [$config->_Sections()]);
}

=head2 readAll

Get all the sections as an array of hash refs

=cut

sub readAll {
    my ($self) = @_;
    my ($status, $status_msg);
    my $config = $self->configStore;
    return (HTTP_OK, $config->readAll($self->idKey));
}

=head2 hasId

If config has a section

=cut

sub hasId {
    my ($self, $id) = @_;
    my ($status, $status_msg);
    my $config = $self->configStore;
    if ( $config->hasId($id) ) {
        $status = HTTP_OK;
        $status_msg = ["[_1] exists",$id];
    } else {
        $status = HTTP_NOT_FOUND;
        $status_msg = ["[_1] does not exists",$id];
    }
    return ($status,$status_msg);
}

=head2 read

reads a section

=cut

sub read {
    my ($self, $id ) = @_;
    my ($status,$result) = $self->hasId($id);
    if(is_success($status)) {
        unless ($result =  $self->configStore->read($id,$self->idKey) ) {
            $result = ["error reading [_1]",$id];
            $status =  HTTP_PRECONDITION_FAILED;
        }
    }
    return ($status, $result);
}

=head2 update

Update/edit/modify an existing section

=cut

sub update {
    my ($self, $id, $assignments) = @_;
    my ($status,$status_msg) = $self->hasId($id);
    if(is_success($status)) {
        delete $assignments->{$self->idKey};
        if ($self->configStore->update($id,$assignments)) {
            $status_msg = ["[_1] successfully modified",$id];
        } else {
            $status = HTTP_INTERNAL_SERVER_ERROR;
            $status_msg = ["error modifying [_1]",$id];
        }
    }
    return ($status, $status_msg);
}


=head2 create

To create

=cut

sub create {
    my ($self, $id, $assignments) = @_;
    my ($status, $status_msg) = (HTTP_OK, "");
    delete $assignments->{$self->idKey};
    my $config = $self->configStore;
    if ($config->create($id,$assignments)) {
        $status_msg = ["[_1] successfully created",$id];
    } else {
        $status_msg = ["[_1] already exists",$id];
        $status =  HTTP_PRECONDITION_FAILED;
    }
    return ($status, $status_msg);
}

=head2 update_or_create

=cut

sub update_or_create {
    my ($self, $id, $assignments) = @_;
    if ( $self->configStore->hasId($id) ) {
        return $self->update($id, $assignments);
    } else {
        return $self->create($id, $assignments);
    }
}

=head2 remove

Removes an existing item

=cut

sub remove {
    my ($self, $id) = @_;
    my ($status,$status_msg) = $self->hasId($id);
    if(is_success($status)) {
        unless($self->configStore->remove($id)) {
            $status_msg = ["error removing [_1]",$id];
            $status =  HTTP_PRECONDITION_FAILED;
        } else {
            $status_msg = ["removed [_1]",$id];
        }
    }
    return ($status, $status_msg);
}

=head2 Copy

Copies a section

=cut

sub copy {
    my ($self,$from,$to) = @_;
    my ($status,$status_msg);
    my $config = $self->configStore;
    if ( $config->copy($from,$to) ) {
        $status = HTTP_OK;
        $status_msg = ['"[_1]" successfully copied to [_2]',$from,$to];
    } else {
        $status_msg = ['"[_]" already exists',$to];
        $status = HTTP_PRECONDITION_FAILED;
    }
    return ($status, $status_msg);
}

=head2 renameItem

=cut

sub renameItem {
    my ( $self, $old, $new ) = @_;
    my ($status,$status_msg);
    my $config = $self->configStore;
    if ( $config->renameItem($old,$new) ) {
        $status_msg = ["[_1] successfully renamed to [_2]",$old,$new];
        $status = HTTP_OK;
    } else {
        $status = HTTP_NOT_FOUND;
        $status_msg = ["[_1] does not exists",$old];
    }
    return ($status,$status_msg);
}

=head2 sortItems

Sorting the items

=cut

sub sortItems {
    my ( $self, $items ) = @_;
    my ($status,$status_msg);
    my $idKey  = $self->idKey;
    my $config = $self->configStore;
    my @sections = map {$_->{$idKey} } @$items;
    if ( $config->sortItems(\@sections)) {
        $status = HTTP_OK;
        $status_msg = "Items re-sorted successfully";
    } else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "Items cannot be resorted";
    }

    return ($status,$status_msg);
}

=head2 commit

=cut

sub commit {
    my ($self) = @_;
    my ($status,$status_msg);
    if($self->configStore->commit()) {
        $status = HTTP_OK;
        $status_msg = "Changes successfully commited";
    }
    else {
        $status = HTTP_INTERNAL_SERVER_ERROR;
        $status_msg = $@;
    }
    return ($status,$status_msg);
}

sub ACCEPT_CONTEXT {
    my ( $self,$c,%args) = @_;
    return $self->new(\%args);
}

sub _buildConfigStore {
    my ($self) = @_;
    return $self->configStoreClass->new;
}


__PACKAGE__->meta->make_immutable;

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

