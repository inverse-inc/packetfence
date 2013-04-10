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

=head2 getForm

=cut

sub getForm {
    my ($self,$c) = @_;
    return $c->form();
}

=head2 getModel

=cut

sub getModel {
    my ($self,$c) = @_;
    return $c->model();
}

=head2 create

=cut

sub create : Local: Args(0) {
    my ($self,$c) = @_;
    my $form = $self->getForm($c);
    my $model = $self->getModel($c);
    if ($c->request->method eq 'POST') {
        $c->stash( current_view => 'JSON');
        my ($status, $status_msg);
        $form->process(params => $c->request->params);
        if ($form->has_errors) {
            $status = HTTP_BAD_REQUEST;
            $status_msg = $form->field_errors;
        }
        else {
            my $item = $form->value;
            my $idKey = $model->idKey;
            my $id = $item->{$idKey};
            $c->stash->{item} = $item;
            $c->stash->{$idKey} = $id;
            ($status, $status_msg) = $model->create($id, $item);
        }
        $c->response->status($status);
        $c->stash->{status_msg} = $status_msg;
        # check if exists
        # Create the source from the update action
    } else {
        # Show an empty form
        $c->stash(
            form => $form,
        );
        $c->forward('view');
    }
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
    $c->stash(
        item  => $item,
        $model->idKey    => $id,
    );
}

=head2 update

=cut

sub update :Chained('object') :PathPart :Args(0) {
    my ($self,$c) = @_;
    my ($status,$status_msg,$form);
    $c->stash->{current_view} = 'JSON';
    $form = $self->getForm($c);
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = $form->field_errors;
    } else {
        my $model = $self->getModel($c);
        my $idKey = $model->idKey;
        ($status,$status_msg) = $model->update(
            $c->stash->{$idKey},
            $form->value
        );
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg; # TODO: localize error message
}


=head2 remove

=cut


sub remove :Chained('object') :PathPart('delete'): Args(0) {
    my ($self,$c) = @_;
    my $model = $self->getModel($c);
    my $idKey = $model->idKey;
    my ($status,$result) = $self->getModel($c)->remove($c->stash->{$idKey},$c->stash->{item});
    $c->stash(
        status_msg   => $result,
        current_view => 'JSON',
    );
    $c->response->status($status);
}

=head2 view

=cut

sub view :Chained('object') :PathPart('read') :Args(0) {
    my ($self,$c) = @_;
    my $item = $c->stash->{item};
    my $form = $self->getForm($c);
    $form->process(init_object => $item);
    $c->stash(
        item => $item,
        form => $form,
    );
}


=head2 list

=cut

sub list :Local :Args(0) {
    my ( $self, $c ) = @_;
    my ($status,$result) = $self->getModel($c)->readAll();
    if (is_error($status)) {
        $c->res->status($status);
        $c->error($c->loc($result));
    } else {
        $c->stash(
            items => $result,
        )
    }
}

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

