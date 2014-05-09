package pfappserver::Controller::Configuration::Firewall_SSO;

=head1 NAME

pfappserver::Controller::Configuration::Firewall_SSO - Catalyst Controller

=head1 DESCRIPTION

Controller for firewall sso  management.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::config::cached;

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'configuration/firewall_sso', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'FIREWALL_SSO_READ' },
        list   => { AdminRole => 'FIREWALL_SSO_READ' },
        create => { AdminRole => 'FIREWALL_SSO_CREATE' },
        clone  => { AdminRole => 'FIREWALL_SSO_CREATE' },
        update => { AdminRole => 'FIREWALL_SSO_UPDATE' },
        remove => { AdminRole => 'FIREWALL_SSO_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::Firewall_SSO", form => "Config::Firewall_SSO" },
    },
);

=head1 METHODS

=head2 after create clone

Show the 'view' template when creating or cloning a floating device.

=cut

after [qw(create clone)] => sub {
    my ($self, $c) = @_;
    if (!(is_success($c->response->status) && $c->request->method eq 'POST' )) {
        $c->stash->{template} = 'configuration/firewall_sso/view.tt';
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

Usage: /configuration/firewall_sso/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->forward('list');
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

__PACKAGE__->meta->make_immutable;

1;
