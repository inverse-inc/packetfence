package pfappserver::PacketFence::Controller::Config::Roles;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Roles - Catalyst Controller

=head1 DESCRIPTION

Controller for Roles configuration.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use pf::config::util qw(is_inline_configured);


BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/roles', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'USERS_ROLES_READ' },
        list   => { AdminRole => 'USERS_ROLES_READ' },
        create => { AdminRole => 'USERS_ROLES_CREATE' },
        clone  => { AdminRole => 'USERS_ROLES_CREATE' },
        update => { AdminRole => 'USERS_ROLES_UPDATE' },
        remove => { AdminRole => 'USERS_ROLES_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::Roles", form => "Config::Roles" },
        search => { form => 'AdvancedSearch' },
        index => { form => 'AdvancedSearch' },
    },
);

=head1 METHODS

=head2 search

search

=cut

sub search : Local : AdminRole('USERS_ROLES_READ') {
    my ($self, $c) = @_;
    my $model = $self->getModel($c);
    my $form = $self->getForm($c);
    $form->process(params => $c->request->params);
    my $status;
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $c->stash(
            current_view => 'JSON',
            status_msg => $form->field_errors,
        );
    } else {
        my $query = $form->value;
        $c->stash(current_view => 'JSON') if ($c->request->params->{'json'});
        ($status, my $result) = $model->search($query);
        if (is_success($status)) {
            $c->stash(
                form => $form,
                action => 'search',
                is_inline_configured => is_inline_configured(),
            );
            $c->stash($result);
        }
    }
    $c->response->status($status);
}

=head2 after create clone

Show the 'view' template when creating or cloning roles.

=cut

after [qw(create clone)] => sub {
    my ($self, $c) = @_;
    if (!(is_success($c->response->status) && $c->request->method eq 'POST' )) {
        $c->stash->{template} = 'config/roles/read.tt';
    }
};

=head2 after view

=cut

after view => sub {
    my ($self, $c) = @_;
    if (!$c->stash->{action_uri}) {
        my $id = $c->stash->{id};
        if ($id) {
            $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [$c->stash->{id}]);
        } else {
            $c->stash->{action_uri} = $c->uri_for($self->action_for('create'));
        }
    }
    $c->stash->{template} = 'config/roles/read.tt';
};

=head2 index

Usage: /roles/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->forward('search');
}

before list => sub {
    my ($self, $c) = @_;
    $c->stash->{is_inline_configured} = is_inline_configured();
};

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
