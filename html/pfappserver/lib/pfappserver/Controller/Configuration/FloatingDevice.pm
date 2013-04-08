package pfappserver::Controller::Configuration::FloatingDevice;

=head1 NAME

pfappserver::Controller::Configuration::FloatingDevice - Catalyst Controller

=head1 DESCRIPTION

Controller for floating device management.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pfappserver::Form::Config::Switch;
use pf::config::cached;

BEGIN {
    extends 'pfappserver::Base::Controller::Base';
    with 'pfappserver::Base::Controller::Crud::Config';
}

=head2 Methods

=over

=item begin

Set the current form instance and model

=cut

sub begin :Private {
    my ($self, $c) = @_;
    pf::config::cached::ReloadConfigs();
    my $model = $c->model("Config::Cached::FloatingDevice")->new;
    $c->stash->{current_model_instance} = $model;
    $c->stash->{current_form_instance}  = $c->form("Config::FloatingDevice")->new(ctx => $c);
}

=item object

Usage: /configuration/floatingdevice/*

=cut

sub object :Chained('/') :PathPart('configuration/floatingdevice') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;
    $self->getModel($c)->readConfig();
    $self->_setup_object($c, $id);
}

=item after list

=cut

after list => sub {
    my ($self, $c) = @_;

    my ($status, $switch, $ip);
    my $switchModel = $c->model('Config::Cached::Switch');
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

=item after update

=item after remove

=cut

after [qw(update remove)] => sub {
    my ($self, $c) = @_;
    if (is_success($c->response->status) ) {
        $self->getModel($c)->rewriteConfig();
    }
};

=item after create

=cut

after create => sub {
    my ($self, $c) = @_;
    if(!(is_success($c->response->status) && $c->request->method eq 'POST' )) {
        $c->stash->{template} = 'configuration/floatingdevice/view.tt';
    }
};

=item after view

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

=item index

Usage: /configuration/floatingdevice/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->forward('list');
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
