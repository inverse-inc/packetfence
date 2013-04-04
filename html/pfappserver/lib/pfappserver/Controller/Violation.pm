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

=head1 SUBROUTINES

=head2 begin

Setting the current form instance and model

=cut

sub begin :Private {
    my ( $self, $c ) = @_;
    my ($configViolationsModel, $status, $result);
    my ($form, $actions, $violations, $triggers, $templates);
    pf::config::cached::ReloadConfigs();

    my $model =  $c->model('Config::Cached::Violations');
    ($status, $result) = $model->readAll();
    if (is_success($status)) {
        $violations = $result;
    }
    $actions = $model->availableActions();
    $triggers = $model->listTriggers();
    $templates = $model->availableTemplates();
    $c->stash(
        trigger_types => \@pf::config::VALID_TRIGGER_TYPES,
        current_model_instance => $model,
        current_form_instance => $c->form("Violation")->new(
            ctx=>$c,
            actions => $actions,
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

    $c->response->redirect($c->uri_for($c->controller('Admin')->action_for('configuration'), ('violations')));
    $c->detach();
}
=head2 read

=cut

after view => sub {
    my ($self, $c, $id) = @_;
    if ($c->stash->{item} && !$c->stash->{action_uri}) {
        $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [ $c->stash->{id} ]);
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
