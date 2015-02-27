
package pfappserver::PacketFence::Controller::Config::Provisioning;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Provisioning - Catalyst Controller

=head1 DESCRIPTION

Controller for Config::Provisioning management

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use pf::factory::provisioner;

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object dispatcher from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/provisioning', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'PROVISIONING_READ' },
        list   => { AdminRole => 'PROVISIONING_READ' },
        create => { AdminRole => 'PROVISIONING_CREATE' },
        clone  => { AdminRole => 'PROVISIONING_CREATE' },
        update => { AdminRole => 'PROVISIONING_UPDATE' },
        remove => { AdminRole => 'PROVISIONING_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::Provisioning",form => "Config::Provisioning" },
    },
);

=head1 METHODS

=head2 index

Usage: /config/provisioning

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{types} = [ sort grep {$_} map { /^pf::provisioner::(.*)/;$1  } @pf::factory::provisioner::MODULES];
    $c->forward('list');
}

before [qw(clone view _processCreatePost update)] => sub {
    my ($self, $c, @args) = @_;
    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    my $item = $c->stash->{$itemKey};
    my $type = $item->{type};
    my $form = $c->action->{form};
    $c->stash->{current_form} = "${form}::${type}";
};

sub create_type : Path('create') : Args(1) {
    my ($self, $c, $type) = @_;
    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    $c->stash->{$itemKey}{type} = $type;
    $c->forward('create');
}

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

