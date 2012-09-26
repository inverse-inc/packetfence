package pfappserver::Controller::Violation;

=head1 NAME

pfappserver::Controller::Violation - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use JSON;
use Moose;
use namespace::autoclean;
use POSIX;

BEGIN {extends 'Catalyst::Controller'; }

=head1 SUBROUTINES

=head2 auto

Allow only authenticated users

=cut

sub auto :Private {
    my ($self, $c) = @_;

    unless ($c->user_exists()) {
        $c->response->status(HTTP_UNAUTHORIZED);
        $c->response->location($c->uri_for($c->controller('Admin')->action_for('configuration'), 'violations'));
        $c->stash->{template} = 'admin/unauthorized.tt';
        $c->detach();
        return 0;
    }

    return 1;
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->response->redirect($c->uri_for($c->controller('Admin')->action_for('configuration'), ('violations')));
    $c->detach();
}

=head2 create

=cut

sub create :Local {
    my ($self, $c) = @_;

    my ($status, $result);

    if ($c->request->method eq 'POST') {
        my $data = decode_json($c->request->params->{json});
        my $id = $data->{id};

        $c->stash->{action_uri} = $c->uri_for($c->action);
        $c->forward('update', [$id]);
    }
    else {
        $c->stash->{action_uri} = $c->uri_for($c->action);
        $c->stash->{template} = 'violation/get.tt';
        $c->forward('get');
    }
}

=head2 object

Violation controller dispatcher

=cut

sub object :Chained('/') :PathPart('violation') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    my ($status, $result) = $c->model('Config::Violations')->read_violation($id);
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $c->loc($result);
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
    else {
        $c->stash->{violation} = pop @$result;
    }
}

=head2 get

=cut

sub read :Chained('object') :PathPart('read') :Args(0) {
    my ($self, $c) = @_;

    my $configViolationsModel = $c->model('Config::Violations');
    my ($status, $result) = $configViolationsModel->read_violation('all');
    if (is_success($status)) {
        $c->stash->{violations} = $result;
    }

    $c->stash->{actions} = $configViolationsModel->availableActions();
    $c->stash->{triggers} = $configViolationsModel->list_triggers();
    if ($c->stash->{violation} && !$c->stash->{action_uri}) {
        $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [$c->{stash}->{violation}->{id}]);
    }
}

=head2 update

=cut

sub update :Chained('object') :PathPart('update') :Args(0) {
    my ($self, $c) = @_;

    my ($status, $result);

    if ($c->request->method eq 'POST') {
        my $data = decode_json($c->request->params->{json});
        # Validate close violation id
        if (grep { $_ eq 'close' } @{$data->{actions}}
            && !$c->model('Config::Violations')->exists($data->{vclose})) {
            $status = HTTP_BAD_REQUEST;
            $result = "The specified violation to close doesn't exist.";
        }
        else {
            # Flatten arrays
            $data->{actions} = join(',', @{$data->{actions}}) if ($data->{actions});
            $data->{trigger} = join(',', @{$data->{trigger}}) if ($data->{trigger});
            ($status, $result) = $c->model('Config::Violations')->update({ $data->{id} => $data });
        }
        if (is_error($status)) {
            $c->response->status($status);
            $c->stash->{status_msg} = $c->loc($result);
        }
        $c->stash->{current_view} = 'JSON';
    }
    else {
        $c->stash->{template} = 'violation/get.tt';
        $c->forward('get');
    }
}

=head2 delete

=cut

sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ($self, $c) = @_;

    my ($status, $result) = $c->model('Config::Violations')->delete_violation($c->stash->{violation}->{id});
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $c->loc($result);
    }

    $c->stash->{current_view} = 'JSON';
}

=head1 AUTHOR

Francis Lachapelle <flachapelle@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
