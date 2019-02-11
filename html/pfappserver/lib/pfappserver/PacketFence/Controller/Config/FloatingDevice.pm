package pfappserver::PacketFence::Controller::Config::FloatingDevice;

=head1 NAME

pfappserver::PacketFence::Controller::Config::FloatingDevice - Catalyst Controller

=head1 DESCRIPTION

Controller for floating device management.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/floatingdevice', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'FLOATING_DEVICES_READ' },
        list   => { AdminRole => 'FLOATING_DEVICES_READ' },
        create => { AdminRole => 'FLOATING_DEVICES_CREATE' },
        clone  => { AdminRole => 'FLOATING_DEVICES_CREATE' },
        update => { AdminRole => 'FLOATING_DEVICES_UPDATE' },
        remove => { AdminRole => 'FLOATING_DEVICES_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::FloatingDevice", form => "Config::FloatingDevice" },
    },
);

=head1 METHODS

=head2 after list

Check which floating device is also defined as a switch

=cut

after list => sub {
    my ($self, $c) = @_;

    my ($status, $switch, $ip);
    my $switchModel = $c->model('Config::Switch');
    foreach my $floatingdevice (@{$c->stash->{items}}) {
        $ip = $floatingdevice->{ip};
        if ($ip) {
            ($status, $switch) = $switchModel->read($ip);
            if (is_success($status)) {
                $floatingdevice->{switch} = $switch;
            }
        }
    }
};

=head2 after create clone

Show the 'view' template when creating or cloning a floating device.

=cut

after [qw(create clone)] => sub {
    my ($self, $c) = @_;
    if (!(is_success($c->response->status) && $c->request->method eq 'POST' )) {
        $c->stash->{template} = 'config/floatingdevice/view.tt';
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
};

=head2 index

Usage: /config/floatingdevice/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->forward('list');
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
