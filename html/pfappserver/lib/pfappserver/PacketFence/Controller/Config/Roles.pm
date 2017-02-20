package pfappserver::PacketFence::Controller::Config::Roles;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Roles - Catalyst Controller

=head1 DESCRIPTION

Controller for roles management.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pfappserver::Form::Config::Switch;

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
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::Roles", form => "Config::Roles" },
    },
);

=head1 METHODS

=head2 index

Usage: /config/roles/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    #$c->forward('list');
    #$c->forward("view", [$name]);
    $c->go('Controller::Roles', 'index');
}

=head2 view

=cut

sub view :Path :Args(1) {
    my ($self, $c, $name) = @_;
    
    $c->stash->{tab} = $name;
    $self->object($c, $name);
    $c->stash->{template} = "config/roles/index.tt";
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
