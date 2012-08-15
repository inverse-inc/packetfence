package pfappserver::Controller::Admin;

=head1 NAME

pfappserver::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 SUBROUTINES

=head2 auto

Allow only authenticated users

=cut
sub auto :Private {
    my ($self, $c) = @_;

    unless ($c->action->name eq 'login' || $c->user_exists()) {
        $c->stash->{status_msg} = 'Your session has expired.';
        $c->stash->{'template'} = 'admin/login.tt';
        $c->stash->{'redirect_action'} = $c->action;
    }
}

=head2 begin

Set the default view to pfappserver::View::Admin.

=cut
sub begin :Private {
    my ( $self, $c ) = @_;

    $c->stash->{current_view} = 'Admin';
}

=head2 login

Perform authentication using Catalyst Authentication plugin.

Upon successful authentication, redirect the user to the status page.

=cut
sub login :Local :Args(0) {
    my ( $self, $c ) = @_;

    if (exists($c->req->params->{'username'}) && exists($c->req->params->{'password'})) {
        if ($c->authenticate( {username => $c->req->params->{'username'},
                               password => $c->req->params->{'password'}} )) {
            $c->response->redirect($c->uri_for($c->controller('Admin')->action_for('status')));
            $c->detach();
        }
        else {
            $c->response->status(HTTP_UNAUTHORIZED);
            $c->stash->{status_msg} = $c->loc("Wrong username or password.");
        }
        $c->stash->{current_view} = 'JSON';
    }
    elsif ($c->user_exists()) {
        $c->response->redirect($c->uri_for($c->controller('Admin')->action_for('status')));
        $c->detach();
    }
    elsif ($c->req->params->{'redirect_action'}) {
        $c->stash->{redirect_action} = $c->req->params->{'redirect_action'};
    }
}

=head2 logout

=cut
sub logout :Local :Args(0) {
    my ( $self, $c ) = @_;

    $c->logout();
    $c->stash->{'redirect_action'} = $c->controller('Admin')->action_for('status');
    $c->stash->{'template'} = 'admin/login.tt';
    $c->stash->{'status_msg'} = $c->loc("You have been logged out.");
}

=head2 index

Status

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->redirect($c->uri_for($c->controller('Admin')->action_for('status')));
}

=head2 object

Administrator controller dispatcher

=cut
sub object :Chained('/') :PathPart('admin') :CaptureArgs(0) {
    my ( $self, $c ) = @_;

}

=head2 status

=cut
sub status :Chained('object') :PathPart('status') :Args(0) {
    my ( $self, $c ) = @_;

}

=head2 reports

=cut
sub reports :Chained('object') :PathPart('reports') :Args(0) {
    my ( $self, $c ) = @_;

}

=head2 nodes

=cut
sub nodes :Chained('object') :PathPart('nodes') :Args(0) {
    my ( $self, $c ) = @_;

}

=head2 configuration

=cut
sub configuration :Chained('object') :PathPart('configuration') :Args(0) {
    my ( $self, $c ) = @_;

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
