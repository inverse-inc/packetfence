package pfappserver::Controller::Configuration::Switch;

=head1 NAME

pfappserver::Controller::Configuration::Switch - Catalyst Controller

=head1 DESCRIPTION

Controller for switches management.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pfappserver::Form::Config::Switch;

BEGIN {extends 'Catalyst::Controller'; }


=head1 METHODS

=head2 CONTROLLER CRUD OPERATORS

=over

=item create

Usage: /configuration/switch/create

=cut
sub create :Local {
    my ( $self, $c ) = @_;

    my ($status, $result, $form);

    $c->stash->{action_uri} = $c->uri_for($c->action);
    if ($c->request->method eq 'POST') {
        $c->forward('update');
    }
    else {
        $c->forward('read');
    }
}

=item read

Usage: /configuration/switch/<switch>/read

=cut
sub read :Chained('object') :PathPart('read') :Args(0) {
    my ( $self, $c ) = @_;
    my $switch = $c->stash->{switch};
    my $switch_ref = $c->stash->{switch_ref};

    # Build form
    my $roles;
    my ($status, $result) = $c->model('Roles')->list;
    if (is_success($status)) {
        $roles = $result;
    }
    my $form = pfappserver::Form::Config::Switch->new(ctx => $c, init_object => $switch_ref, roles => $roles);
    $form->process();
    $c->stash->{form} = $form;

    if ($c->stash->{switch} && !$c->stash->{action_uri}) {
        $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [$switch]);
    }
    $c->stash->{template} = 'configuration/switch/read.tt';
    #$c->stash->{current_view} = 'HTML';
}

=item update

Usage: /admin/configuration/switches/<switch>/update

=cut
sub update :Chained('object') :PathPart('update') :Args(0) {
    my ( $self, $c ) = @_;
    my $switch = $c->stash->{switch};

    if ($c->request->method eq 'POST') {
        my ($status, $result);
        my ($roles, $form, $data);

        ($status, $result) = $c->model('Roles')->list;
        if (is_success($status)) {
            $roles = $result;
        }
        $form = pfappserver::Form::Config::Switch->new(ctx => $c, roles => $roles);
        $form->process(params => $c->req->params);
        if ($form->has_errors) {
            $status = HTTP_BAD_REQUEST;
            $result = $form->field_errors;
        }
        else {
            $data = $form->value;
            ($status, $result) = $c->model('Config::Switches')->update($data->{ip}, $data);
        }

        $c->response->status($status);
        $c->stash->{status_msg} = $result; # TODO: localize error message
        $c->stash->{current_view} = 'JSON';
    }
    else {
        $c->forward('read');
    }
}

=item delete

Delete an existing switch / network equipment.

Usage: /configuration/switch/<switch>/delete

=cut
sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ( $self, $c ) = @_;
    my $switch = $c->stash->{switch};

    my ($status, $result) = $c->model('Config::Switches')->deleteItem($switch);
    if ( is_success($status) ) {
        $c->stash->{status_msg} = $result;
    } else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
    }

    $c->stash->{current_view} = 'JSON';
}


=back

=head2 CONTROLLER OPERATIONS

=over

=item index

Usage: /configuration/switch/index

=cut
sub index :Local :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'configuration/switch/index.tt';
    $c->visit('list');
}

=item list

Usage: /configuration/switch/list

=cut
sub list :Local :Args(0) {
    my ( $self, $c ) = @_;

    my ($status, $result) = $c->model('Config::Switches')->read('all');
    if (is_error($status)) {
        $c->res->status($status);
        $c->error($c->loc($result));
    }
    else {
        $c->stash->{switches} = $result;
    }
}

=item object

Controller dispatcher.

We basically capture the requested switch and check if that one is valid.

=cut
sub object :Chained('/') :PathPart('switch') :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    my ($status, $result) = $c->model('Config::Switches')->read($id);
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $c->loc($result);
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
    else {
        $c->stash->{switch} = $id;
        $c->stash->{switch_ref} = pop @$result;
    }
}


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

__PACKAGE__->meta->make_immutable;

1;
