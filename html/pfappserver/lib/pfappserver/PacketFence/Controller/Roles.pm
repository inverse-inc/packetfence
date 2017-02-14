package pfappserver::PacketFence::Controller::Roles;

=head1 NAME

pfappserver::PacketFence::Controller::Roles - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;

use pfappserver::Form::Role;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head1 METHODS

=head2 index

=cut

sub index :Path :Args(0) :AdminRole('USERS_ROLES_READ') {
    my ($self, $c) = @_;

    my ($status, $result) = $c->model('Roles')->list();
    if (is_success($status)) {
        $c->stash->{roles} = $result;
    }
    else {
        $c->stash->{error} = $result;
    }
}

=head2 view

=cut

sub view :Path :Args(0) :AdminRole('USERS_ROLES_READ') {
    my ($self, $c, $name) = @_;

    $c->stash->{tab} = $name;
    $self->object($c, $name);
}

=head2 create

=cut

sub create :Local :AdminRole('USERS_ROLES_CREATE') {
    my ($self, $c) = @_;

    my ($status, $result, $form);

    if ($c->request->method eq 'POST') {
        $form = pfappserver::Form::Role->new(ctx => $c);
        $form->process(params => $c->req->params);
        if ($form->has_errors) {
            $status = HTTP_BAD_REQUEST;
            $result = $form->field_errors;
        }
        else {
            my $data = $form->value;
            ($status, $result) = $c->model('Roles')->create($data->{name}, $data->{max_nodes_per_pid}, $data->{notes});
            $self->audit_current_action($c, status => $status, id => $data->{name});
        }

        if (is_error($status)) {
            $c->response->status($status);
            $c->stash->{status_msg} = $result;
        }
        $c->stash->{current_view} = 'JSON';
    }
    else {
        $c->stash->{action_uri} = $c->req->uri;
        $c->forward('read');
    }
}

=head2 object

Roles controller dispatcher

=cut

sub object :Chained('/') :PathPart('roles') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    my ($status, $result) = $c->model('Roles')->read($id);
    if (is_success($status)) {
        $c->stash->{role} = $result;
    }
    else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
}

=head2 read

=cut

sub read :Chained('object') :PathPart('read') :Args(0) :AdminRole('USERS_ROLES_READ') {
    my ($self, $c) = @_;

    my ($status, $result, $form);

    $c->stash->{template} = 'roles/read.tt';

    if ($c->stash->{role}->{category_id}) {
        # Update an existing role
        $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [$c->stash->{role}->{category_id}]);
    }

    $form = pfappserver::Form::Role->new(ctx => $c, init_object => $c->stash->{role});
    $form->process();
    $c->stash->{form} = $form;
}

=head2 update

=cut

sub update :Chained('object') :PathPart('update') :Args(0) :AdminRole('USERS_ROLES_UPDATE') {
    my ($self, $c) = @_;

    my ($status, $result, $form);

    if ($c->request->method eq 'POST') {
        $form = pfappserver::Form::Role->new(ctx => $c, id => $c->stash->{role}->{name});
        $form->process(params => $c->req->params);
        if ($form->has_errors) {
            $status = HTTP_BAD_REQUEST;
            $result = $form->field_errors;
        }
        else {
            my $data = $form->value;
            ($status, $result) = $c->model('Roles')->update($c->stash->{role},
                                                            $c->stash->{role}->{name},
                                                            $data->{max_nodes_per_pid},
                                                            $data->{notes});
            $self->audit_current_action($c, status => $status, id => $c->stash->{role}->{name});
        }
        if (is_error($status)) {
            $c->response->status($status);
            $c->stash->{status_msg} = $result;
        }
        $c->stash->{current_view} = 'JSON';
    }
    else {
        $c->stash->{template} = 'violation/get.tt';
        $c->forward('get');
    }
}

=head2 delete

=cut

sub delete :Chained('object') :PathPart('delete') :Args(0) :AdminRole('USERS_ROLES_DELETE') {
    my ($self, $c) = @_;

    my ($status, $result) = $c->model('Roles')->delete($c->stash->{role});
    $self->audit_current_action($c, status => $status, id => $c->stash->{role}->{name});
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
    }

    $c->stash->{current_view} = 'JSON';
}

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
