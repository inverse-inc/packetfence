package pfappserver::Base::Controller::Crud;
=head1 NAME

pfappserver::Base::Controller::Crud

=head1 DESCRIPTION

Basic Crud Controller Roles

=cut

use strict;
use warnings;
use HTTP::Status qw(:constants is_error is_success);
use MooseX::MethodAttributes::Role;
use namespace::autoclean;

=head1 METHODS

=head2 create

=cut

sub create :Local :Args(0) {
    my ($self, $c) = @_;
    if ($c->request->method eq 'POST') {
        $self->_processCreatePost($c);
        # check if exists
        # Create the source from the update action
    } else {
        # Show an empty form
        $c->forward('view');
    }
}

=head2 audit_current_action

Adds the object_id to the audit log

=cut

around audit_current_action => sub {
    my ($orig, $self, $c, @args) = @_;
    my $model = $self->getModel($c);
    my $idKey = $model->idKey();
    $self->$orig($c, (defined $c->stash->{$idKey} ? (object_id => $c->stash->{$idKey}) :()), @args);
};

sub _processCreatePost {
    my ($self,$c) =@_;
    my $form = $self->getForm($c);
    my $model = $self->getModel($c);
    $c->stash( current_view => 'JSON');
    my ($status, $status_msg);
    $form->process(params => $c->request->params);
    $c->stash->{form} = $form;
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = $form->field_errors;
    }
    else {
        my $item = $form->value;
        my $idKey = $model->idKey;
        my $itemKey = $model->itemKey;
        my $id = $item->{$idKey};
        $c->stash(
            $itemKey => $item,
            $idKey   => $id,
        );
        ($status, $status_msg) = $model->create($id, $item);
        $self->audit_current_action($c, status => $status);
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg;
}

=head2 _setup_object

=cut

sub _setup_object {
    my ($self,$c,$id) = @_;
    my $model = $self->getModel($c);
    my ($status, $item) = $model->read($id);
    if ( is_error($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $item;
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
    my $itemKey = $model->itemKey;
    my $idKey = $model->idKey;
    $c->stash(
        $itemKey  => $item,
        $idKey    => $id,
    );
}

=head2 object

=cut

sub object {
    my ($self,$c,@args) = @_;
    $self->_setup_object($c,@args);
}

=head2 update

=cut

sub update :Chained('object') :PathPart :Args(0) {
    my ($self,$c) = @_;
    my ($status,$status_msg,$form);
    $c->stash->{current_view} = 'JSON';
    $form = $self->getForm($c);
    $form->process(params => $c->request->params);
    $c->stash->{form} = $form;
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = $form->field_errors;
    } else {
        my $model = $self->getModel($c);
        my $idKey = $model->idKey;
        my $current_id = $c->stash->{$idKey};
        my $value = $form->value;
        my $new_id;
        if(exists $value->{$idKey} && defined $value->{$idKey} ) {
            $new_id = $value->{$idKey};
        } else {
            $new_id = $current_id;
        }
        ($status,$status_msg) = $model->update(
            $current_id,
            $value
        );
        $self->audit_current_action($c, status => $status);
        if (is_success($status) && ($new_id ne $current_id)) {
            ($status, my $rename_status_msg) = $model->renameItem(
                $current_id,
                $new_id
            );
            $status_msg .= " and $rename_status_msg";
        }
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg; # TODO: localize error message
}


=head2 rename_item

=cut

sub rename_item :Chained('object') :PathPart :Args(1) {
    my ($self,$c,$new_id) = @_;
    my ($status,$status_msg,$form);
    my $model = $self->getModel($c);
    my $idKey = $model->idKey;
    my $current_id = $c->stash->{$idKey};
    if ($new_id ne $current_id) {
        ($status,$status_msg) = $model->renameItem( $current_id,$new_id);
        $self->audit_current_action($c, status => $status);
    } else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "cannot renamed $current_id to itself";
    }
    $c->response->status($status);
    $c->stash(
        status_msg => $status_msg,
        current_view => 'JSON',
    )
}

=head2 remove

=cut


sub remove :Chained('object') :PathPart('delete'): Args(0) {
    my ($self,$c) = @_;
    my $model = $self->getModel($c);
    my $idKey = $model->idKey;
    my $itemKey = $model->itemKey;
    my ($status,$result) = $self->getModel($c)->remove($c->stash->{$idKey},$c->stash->{$itemKey});
    $c->stash(
        status_msg   => $result,
        current_view => 'JSON',
    );
    $self->audit_current_action($c, status => $status);
    $c->response->status($status);
}

=head2 view

=cut

sub view :Chained('object') :PathPart('read') :Args(0) {
    my ($self,$c) = @_;
    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    my $item = $c->stash->{$itemKey};
    my $form = $self->getForm($c);
    $form->process(init_object => $item);
    $c->stash(
        $itemKey => $item,
        form     => $form,
    );
}


=head2 list

=cut

sub list :Local :Args(0) {
    my ( $self, $c ) = @_;
    my $model = $self->getModel($c);
    my ($status,$result) = $model->readAll();
    if (is_error($status)) {
        $c->res->status($status);
        $c->error($c->loc($result));
    } else {
        my $itemsKey = $model->itemsKey;
        $c->stash(
            $itemsKey => $result,
            itemsKey  => $itemsKey,
        )
    }
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

1;

