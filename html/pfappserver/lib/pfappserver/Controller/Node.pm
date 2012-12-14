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

BEGIN { extends 'pfappserver::Base::Controller::Base'; }

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
    my ( $self, $c ) = @_;
    $c->go("simple_search");
}

=head2 simple_search

=cut
sub simple_search : SimpleSearch('Node')  : Local :Args() { }

=head2 object

Node controller dispatcher

=cut
sub object :Chained('/') :PathPart('node') :CaptureArgs(1) {
    my ( $self, $c, $mac ) = @_;

    my ($status, $node_ref) = $c->model('Node')->exists($mac);
    if ( is_error($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $node_ref;
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }

    $c->stash->{mac} = $mac;
}

=head2 get

=cut
sub get :Chained('object') :PathPart('get') :Args(0) {
    my ($self, $c) = @_;

    my ($nodeStatus, $result);
    my ($form, $status, $roles);

    # Form initialization :
    # Retrieve node details, categories and status

    ($status, $result) = $c->model('Node')->get($c->stash->{mac});
    if (is_success($status)) {
        $c->stash->{node} = $result;
    }
    ($status, $result) = $c->model('Roles')->list();
    if (is_success($status)) {
        $roles = $result;
    }
    $nodeStatus = $c->model('Node')->availableStatus();
    $form = pfappserver::Form::Node->new(ctx => $c,
                                         init_object => $c->stash->{node},
                                         status => $nodeStatus,
                                         roles => $roles);
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
                                         status => $nodeStatus);
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
