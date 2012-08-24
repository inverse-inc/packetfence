package pfappserver::Controller::SoH;

=head1 NAME

pfappserver::Controller::SoH - Catalyst Controller

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
        $c->response->location($c->req->referer);
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

    $c->response->redirect($c->uri_for($c->controller('Admin')->action_for('configuration'), ('soh')));
    $c->detach();
}

=head2 create

=cut

sub create :Local {
    my ($self, $c) = @_;

    my ($status, $result);

    if ($c->request->method eq 'POST') {
        my $data = decode_json($c->request->params->{json});
        # Validate violation id
        if ($data->{action} eq 'violation' && !$c->model('Config::Violations')->exists($data->{vid})) {
            $status = HTTP_BAD_REQUEST;
            $result = $c->loc("The specified violation doesn't exist.");
        }
        else {
            my $configViolationsModel = $c->model('Config::Violations');
            ($status, $result) = $c->model('SoH')->create($configViolationsModel,
                                                          $data->{name}, $data->{action}, $data->{vid},
                                                          $data->{rules});
        }
        if (is_error($status)) {
            $c->response->status($status);
            $c->stash->{status_msg} = $result;
            $c->stash->{current_view} = 'JSON';
        }
    }
    else {
        my ($status, $result) = $c->model('Config::Violations')->read_violation('all');
        if (is_success($status)) {
            $c->stash->{violations} = $result;
        }
    }
}

=head2 object

SoH controller dispatcher

=cut

sub object :Chained('/') :PathPart('soh') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    my ($status, $result) = $c->model('SoH')->exists($id);
    if ( is_error($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
    else {
        $c->stash->{filter} = $result;
    }
}

=head2 get

=cut

sub get :Chained('object') :PathPart('get') :Args(0) {
    my ($self, $c) = @_;

    my ($status, $result);

    if ($c->stash->{filter}) {
        ($status, $result) = $c->model('Config::Violations')->read_violation('all');
        if (is_success($status)) {
            $c->stash->{violations} = $result;
        }
    }

    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 update

=cut

sub update :Chained('object') :PathPart('update') :Args(0) {
    my ($self, $c) = @_;

    my $data = decode_json($c->request->params->{json});
    my $configViolationsModel = $c->model('Config::Violations');
    my ($status, $result) = $c->model('SoH')->update($configViolationsModel,
                                                     $c->stash->{filter},
                                                     $data->{action}, $data->{vid},
                                                     $data->{rules});
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
    }

    $c->stash->{current_view} = 'JSON';
}

=head2 delete

=cut

sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ($self, $c) = @_;

    my $configViolationsModel = $c->model('Config::Violations');
    my ($status, $result) = $c->model('SoH')->delete($configViolationsModel,
                                                     $c->stash->{filter});
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
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
