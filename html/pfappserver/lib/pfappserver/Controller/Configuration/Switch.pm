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
    extends 'pfappserver::Base::Controller::Base';
    with 'pfappserver::Base::Controller::Crud';
}

=head2 Methods

=over

=item begin

Setting the current form instance and model

=cut

sub begin :Private {
    my ( $self, $c ) = @_;
    my ($status,$switch_default,$roles);
    my $model = $c->model("Config::Cached::Switch")->new;
    ($status,$switch_default) = $model->read('default');
    ($status, $roles) = $c->model('Roles')->list;
    $roles = undef unless(is_success($status));
    $c->stash->{current_model_instance} = $model;
    $c->stash->{current_form_instance}  = $c->form("Config::Switch")->new(ctx => $c, placeholders => $switch_default, roles => $roles);
    $c->stash->{switch_default} = $switch_default;
}

=item object

/configuration/switch/*

=cut

sub object :Chained('/') :PathPart('configuration/switch') :CaptureArgs(1) {
    my ($self,$c,$id) = @_;
    $self->getModel($c)->readConfig();
    $self->_setup_object($c,$id);
    $c->stash->{action_uri} = $c->uri_for($c->action);
}

after [qw(update remove)] => sub {
    my ($self,$c) = @_;
    if(is_success($c->response->status) ) {
        $self->getModel($c)->rewriteConfig();
    }
};

after create => sub {
    my ($self,$c) = @_;
    if(is_success($c->response->status) && $c->request->method eq 'POST' ) {
        $self->getModel($c)->rewriteConfig();
    } else {
        $c->stash->{template} = 'configuration/switch/read.tt';
    }
};

after view => sub {
    my ( $self, $c ) = @_;
    if (!$c->stash->{action_uri}) {
        my $id = $c->stash->{id};
        $c->log->info("ID : $id");
        if ($id) {
            $c->stash->{action_uri} = $c->uri_for($self->action_for('update'),[$c->stash->{id}]);
        } else {
            $c->stash->{action_uri} = $c->uri_for($self->action_for('create'));
        }
    }
};

=item read

Usage: /configuration/switch/<switch>/read

=cut

sub read :Chained('object') :PathPart('read') :Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('view');
}

=back

=head2 CONTROLLER OPERATIONS

=over

=item index

Usage: /configuration/switch/

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('list');
}

sub list :Local :Args(0) {
    my ( $self, $c ) = @_;
    my $model = $self->getModel($c);
    my ($status,$result) = $model->readAll();
    if (is_error($status)) {
        $c->res->status($status);
        $c->error($c->loc($result));
    } else {
        $c->stash(
            items => $result,
        )
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
