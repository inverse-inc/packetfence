package pfappserver::Controller::Violation;

=head1 NAME

pfappserver::Controller::Violation - Catalyst Controller

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
use pfappserver::Form::Violation;

BEGIN {
    extends 'pfappserver::Base::Controller::Base';
    with 'pfappserver::Base::Controller::Crud::Config';
}

=head1 METHODS

=head2 begin

Setting the current form instance and model

=cut

sub begin :Private {
    my ($self, $c) = @_;
    my ($configViolationsModel, $status, $result);
    my ($form, $violations, $triggers, $templates);
    pf::config::cached::ReloadConfigs();

    my $model =  $c->model('Config::Violations');
    ($status, $result) = $model->readAll();
    if (is_success($status)) {
        $violations = $result;
    }
    $triggers = $model->listTriggers();
    $templates = $model->availableTemplates();
    $c->stash(
        trigger_types => \@pf::config::VALID_TRIGGER_TYPES,
        current_model_instance => $model,
        current_form_instance => $c->form("Violation")->new(
            ctx => $c,
            violations => $violations,
            triggers => $triggers,
            templates => $templates,
        )
    )

}

=head2 object

Violation controller dispatcher

=cut

sub object :Chained('/') :PathPart('violation') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    $self->_setup_object($c,$id);
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

after create => sub {
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
        my ($status, $result) = $c->model('Config::Cached::Profile')->readAllIds();
        if (is_success($status)) {
            $c->stash->{profiles} = ['default', @$result];
        }
    }
};

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
