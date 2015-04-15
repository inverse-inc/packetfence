package pfappserver::PacketFence::Controller::Violation;

=head1 NAME

pfappserver::PacketFence::Controller::Violation - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;

use pf::config;
use pf::Switch::constants;
use pf::factory::triggerParser;
use pfappserver::Form::Violation;

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'violation', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'VIOLATIONS_READ' },
        list   => { AdminRole => 'VIOLATIONS_READ' },
        create => { AdminRole => 'VIOLATIONS_CREATE' },
        clone  => { AdminRole => 'VIOLATIONS_CREATE' },
        update => { AdminRole => 'VIOLATIONS_UPDATE' },
        remove => { AdminRole => 'VIOLATIONS_DELETE' },
    },
);

=head1 METHODS

=head2 begin

Setting the current form instance and model

=cut

sub begin :Private {
    my ($self, $c) = @_;
    my ($status, $result);
    my ($model, $violations, $violation_default, $roles, $triggers, $templates);

    $model =  $c->model('Config::Violations');
    ($status, $result) = $model->readAll();
    if (is_success($status)) {
        $violations = $result;
    }
    my @roles = map {{ name => $_ }} @SNMP::ROLES;
    ($status, $result) = $c->model('Roles')->list();
    if (is_success($status)) {
        push(@roles, @$result);
    }
    ($status, $violation_default) = $model->read('defaults');
    $triggers = $model->listTriggers();
    $templates = $model->availableTemplates();
    $c->stash(
        trigger_types => \@pf::factory::triggerParser::VALID_TRIGGER_TYPES,
        current_model_instance => $model,
        current_form_instance =>
              $c->form("Violation",
                       violations => $violations,
                       placeholders => $violation_default,
                       roles => \@roles,
                       triggers => $triggers,
                       templates => $templates,
                      )
             )
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'violation/list.tt';
    $c->forward('list');
}

=head2 after view

=cut

after view => sub {
    my ($self, $c, $id) = @_;
    if (!$c->stash->{action_uri}) {
        if ($c->stash->{item}) {
            $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [$c->stash->{id}]);
        } else {
            $c->stash->{action_uri} = $c->uri_for($self->action_for('create'));
        }
    }
};

=head2 after create

=cut

after [qw(create clone)] => sub {
    my ($self, $c) = @_;
    if (!(is_success($c->response->status) && $c->request->method eq 'POST' )) {
        $c->stash->{template} = 'violation/view.tt';
    }
};

=head2 after list

=cut

after list => sub {
    my ($self, $c) = @_;

    if (is_success($c->response->status)) {
        # Sort violations by id and keep the defaults template at the top
        my @items = sort {
            if ($a->{id} eq 'defaults') {
                -1;
            } else {
                int($a->{id}) <=> int($b->{id});
            }
        } @{$c->stash->{items}};
        $c->stash->{items} = \@items;
        my ($status, $result) = $c->model('Config::Profile')->readAllIds();
        if (is_success($status)) {
            $c->stash->{profiles} = $result;
        }
    }
};

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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
