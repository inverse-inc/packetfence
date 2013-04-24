package pfappserver::Controller::Node;

=head1 NAME

pfappserver::Controller::Node - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;

use pfappserver::Form::Node;
use pfappserver::Form::AdvancedSearch;

BEGIN { extends 'pfappserver::Base::Controller::Base'; }

=head1 SUBROUTINES


=head2 index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->go('simple_search');
}

=head2 simple_search

=cut
sub simple_search :SimpleSearch('Node') :Local :Args() { }

=head2 advanced_search

=cut
sub advanced_search :Local :Args() {
    my ($self, $c) = @_;
    my ($status,$status_msg,%search_results) = (HTTP_OK,undef,);
    my $search_model = $c->model("Search::Node");
    my $form = new pfappserver::Form::AdvancedSearch;
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = $form->field_errors;
    } else {
        %search_results = $search_model->search($form->value);
    }
    $c->stash(
        status_msg => $status_msg,
        %search_results
    );
    $c->response->status($status);
}


=head2 save_search

=cut
sub save_search : Local :Args(0) { }

=head2 get_searches

=cut
sub get_searches : Local :Args(0) { }

=head2 object

Node controller dispatcher

=cut
sub object :Chained('/') :PathPart('node') :CaptureArgs(1) {
    my ( $self, $c, $mac ) = @_;

    my ($status, $node_ref, $roles_ref);

    ($status, $node_ref) = $c->model('Node')->exists($mac);
    if ( is_error($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $node_ref;
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
    ($status, $roles_ref) = $c->model('Roles')->list();
    if (is_success($status)) {
        $c->stash->{roles} = $roles_ref;
    }

    $c->stash->{mac} = $mac;
}

=head2 view

=cut
sub view :Chained('object') :PathPart('read') :Args(0) {
    my ($self, $c) = @_;

    my ($nodeStatus, $result);
    my ($form, $status, $roles);

    # Form initialization :
    # Retrieve node details and status

    ($status, $result) = $c->model('Node')->view($c->stash->{mac});
    if (is_success($status)) {
        $c->stash->{node} = $result;
    }
    $nodeStatus = $c->model('Node')->availableStatus();
    $form = pfappserver::Form::Node->new(ctx => $c,
                                         init_object => $c->stash->{node},
                                         status => $nodeStatus,
                                         roles => $c->stash->{roles});
    $form->process();
    $c->stash->{form} = $form;

#    my @now = localtime;
#    $c->stash->{now} = { date => POSIX::strftime("%Y-%m-%d", @now),
#                         time => POSIX::strftime("%H:%M", @now) };
}

=head2 update

=cut
sub update :Chained('object') :PathPart('update') :Args(0) {
    my ( $self, $c ) = @_;

    my ($status, $message);
    my ($form, $nodeStatus);

    $nodeStatus = $c->model('Node')->availableStatus();
    $form = pfappserver::Form::Node->new(ctx => $c,
                                         status => $nodeStatus,
                                         roles => $c->stash->{roles});
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $message = $form->field_errors;
    }
    else {
        ($status, $message) = $c->model('Node')->update($c->stash->{mac}, $form->value);
    }
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message; # TODO: localize error message
    }
    $c->stash->{current_view} = 'JSON';
}

=head2 delete

=cut

sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ( $self, $c ) = @_;

    my ($status, $message) = $c->model('Node')->delete($c->stash->{mac});
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message; # TODO: localize error message
    }
    $c->stash->{current_view} = 'JSON';
}

=head2 violations

=cut

sub violations :Chained('object') :PathPart :Args(0) {
    my ($self, $c) = @_;
    my ($status, $result) = $c->model('Node')->violations($c->stash->{mac});
    if (is_success($status)) {
        $c->stash->{items} = $result;
        $c->stash->{template} = 'node/violations.tt';
        (undef, $c->stash->{violations}) = $c->model('Config::Violations')->readAll();
    } else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 triggerViolation

=cut

sub triggerViolation :Chained('object') :PathPart('trigger') :Args(1) {
    my ($self, $c, $id) = @_;
    my ($status, $result) = $c->model('Config::Violations')->hasId($id);
    if (is_success($status)) {
        ($status, $result) = $c->model('Node')->addViolation($c->stash->{mac}, $id);
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $result;
    if (is_success($status)) {
        $c->forward('violations');
    }
    else {
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 openViolation

=cut

sub openViolation :Path('open') :Args(1) {
    my ($self, $c, $id) = @_;
    my ($status, $result) = $c->model('Node')->openViolation($id);
    $c->response->status($status);
    $c->stash->{status_msg} = $result;
    $c->stash->{current_view} = 'JSON';
}

=head2 closeViolation

=cut

sub closeViolation :Path('close') :Args(1) {
    my ($self, $c, $id) = @_;
    my ($status, $result) = $c->model('Node')->closeViolation($id);
    $c->response->status($status);
    $c->stash->{status_msg} = $result;
    $c->stash->{current_view} = 'JSON';
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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
