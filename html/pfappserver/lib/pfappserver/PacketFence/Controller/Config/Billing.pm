package pfappserver::PacketFence::Controller::Config::Billing;

=head1 NAME
pfappserver::PacketFence::Controller::Config::Billing - Catalyst Controller
=head1 DESCRIPTION
Controller for admin roles management.
=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::config::cached;
use pf::factory::billing;

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/billing', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'BILLING_READ' },
        list   => { AdminRole => 'BILLING_READ' },
        create => { AdminRole => 'BILLING_CREATE' },
        clone  => { AdminRole => 'BILLING_CREATE' },
        update => { AdminRole => 'BILLING_UPDATE' },
        remove => { AdminRole => 'BILLING_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::Billing", form => "Config::Billing" },
    },
);

=head1 METHODS

=head2 after create clone

Show the 'view' template when creating or cloning a scan engine.

=cut

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

=head2 index

Usage: /config/billing/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{types} = [ sort grep {$_} map { /^pf::billing::gateway::(.*)/;$1  } @pf::factory::billing::MODULES];
    $c->forward('list');
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
