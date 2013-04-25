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

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
}

=head1 METHODS

=head2 begin

Setting the current form instance and model

=cut

sub begin :Private {
    my ($self, $c) = @_;
    pf::config::cached::ReloadConfigs();
    my ($status, $switch_default, $roles);
    my $model = $c->model("Config::Cached::Switch")->new;
    ($status, $switch_default) = $model->read('default');
    ($status, $roles) = $c->model('Roles')->list;
    $roles = undef unless(is_success($status));
    $c->stash->{current_model_instance} = $model;
    $c->stash->{current_form_instance} = $c->form("Config::Switch")->new(ctx => $c, placeholders => $switch_default,
                                                                         roles => $roles);
    $c->stash->{switch_default} = $switch_default;
}

=head2 object

/configuration/switch/*

=cut

sub object :Chained('/') :PathPart('configuration/switch') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;
    $self->getModel($c)->readConfig();
    $self->_setup_object($c, $id);
    $c->stash->{action_uri} = $c->uri_for($c->action);
}

=head2 after list

Check which switch is also defined as a floating device

=cut

after list => sub {
    my ($self, $c) = @_;

    my ($status, $floatingdevice, $ip);
    my $floatingDeviceModel = $c->model('Config::Cached::FloatingDevice');
    $floatingDeviceModel->readConfig();
    foreach my $switch (@{$c->stash->{items}}) {
        $ip = $switch->{id};
        if ($ip) {
            ($status, $floatingdevice) = $floatingDeviceModel->search('ip', $ip);
            if (is_success($status)) {
                $switch->{floatingdevice} = pop @$floatingdevice;
            }
        }
    }
};

=head2 after create

=cut

after create => sub {
    my ($self, $c) = @_;
    if (!(is_success($c->response->status) && $c->request->method eq 'POST' )) {
        $c->stash->{template} = 'configuration/switch/view.tt';
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

Usage: /configuration/switch/

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
