package pfappserver::PacketFence::Controller::Admin;

=head1 NAME

pfappserver::PacketFence::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use namespace::autoclean;
use Moose;
use pfappserver::Form::SavedSearch;
use pf::admin_roles;
use List::MoreUtils qw(none);
use pf::pfcmd::checkup;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head1 METHODS

=head2 auto

Allow only authenticated users

=cut

sub auto :Private {
    my ($self, $c, @args) = @_;

    # Make sure the 'enforcements' session variable doesn't exist as it affects the Interface controller
    delete $c->session->{'enforcements'};

    unless ($c->action->name eq 'login' || $c->action->name eq 'logout' || $c->user_in_realm('admin')) {
        $c->stash->{'template'} = 'admin/login.tt';
        unless ($c->action->name eq 'index') {
            $c->stash->{status_msg} = $c->loc("Your session has expired.");
            $c->stash->{'redirect_action'} = $c->uri_for($c->action, @args);
        }
        $c->delete_session();
        $c->detach();
        return 0;
    }

    return 1;
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
        $c->stash->{current_view} = 'JSON';
        eval {
            if ($c->authenticate( { username => $c->req->params->{'username'}, password => $c->req->params->{'password'} } )) {
                my $roles = [$c->user->roles];
                if (admin_can_do_any_in_group($roles, 'LOGIN_GROUP')) {

                    # Save the roles to the session
                    $c->session->{user_roles} = $roles;

                    # Save the updated roles data
                    $c->persist_user();

                    # Don't send a standard 302 redirect code; return the redirection URL in the JSON payload
                    # and perform the redirection on the client side
                    $c->response->status(HTTP_ACCEPTED);
                    if ($c->req->params->{'redirect_url'}) {
                        $c->stash->{success} = $c->req->params->{'redirect_url'};
                    } else {
                        $c->stash->{success} = $c->uri_for($c->controller()->action_for('index'));
                    }
                } else {
                    $c->response->status(HTTP_UNAUTHORIZED);
                    $c->stash->{status_msg} = $c->loc("You don't have the rights to perform this action.");
                    if (@$roles && none {$_ eq 'NONE'}) {
                        $c->log->error( "One of the following roles are not defined properly " . join(",", map { "'$_'" } @$roles));
                    }
                }
            } else {
                $c->response->status(HTTP_UNAUTHORIZED);
                $c->stash->{status_msg} = $c->loc("Wrong username or password.");
            }
        };
        if ($@) {
            $c->response->status(HTTP_INTERNAL_SERVER_ERROR);
            $c->stash->{status_msg} = $c->loc("Unexpected error. See server-side logs for details.");
        }
    } elsif ($c->user_in_realm( 'admin' )) {
        $c->response->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach();
    } elsif ($c->req->params->{'redirect_action'}) {
        $c->stash->{redirect_action} = $c->req->params->{'redirect_action'};
    }
}

=head2 logout

=cut

sub logout :Local :Args(0) {
    my ( $self, $c ) = @_;

    $c->logout();
    $c->delete_session();
    $c->stash->{'template'} = 'admin/login.tt';
    $c->stash->{'status_msg'} = $c->loc("You have been logged out.");
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my @roles = $c->user->roles();
    my $action;
    if (admin_can_do_any(\@roles,qw(SERVICES REPORTS))) {
        $action = 'status';
    } elsif( admin_can_do_any(\@roles,qw(USERS_READ))) {
        $action = 'users';
    } elsif( admin_can_do_any(\@roles,qw(NODES_READ))) {
        $action = 'nodes';
    } elsif( admin_can_do_any_in_group(\@roles, 'CONFIGURATION_GROUP_READ' ) ) {
        $action = 'configuration';
    } else {
        $action = 'logout';
        $c->log->error("A role action is not properly defined");
    }
    $c->response->redirect($c->uri_for($c->controller->action_for($action)));
}

=head2 object

Administrator controller dispatcher

=cut

sub object :Chained('/') :PathPart('admin') :CaptureArgs(0) {
    my ( $self, $c ) = @_;

    $c->stash->{'pf_release'} = $c->model('Admin')->pf_release();
}

=head2 status

=cut

sub status :Chained('object') :PathPart('status') :Args(0) {
    my ( $self, $c ) = @_;

}

=head2 reports

=cut

sub reports :Chained('object') :PathPart('reports') :Args(0) :AdminRole('REPORTS') {
    my ( $self, $c ) = @_;

    $c->forward('Controller::Graph', 'reports');
}

=head2 nodes

=cut

sub nodes :Chained('object') :PathPart('nodes') :Args(0) :AdminRole('NODES_READ') {
    my ( $self, $c ) = @_;
    my $id = $c->user->id;
    my ($status, $saved_searches) = $c->model("SavedSearch::Node")->read_all($id);
    $c->stash(
        saved_searches => $saved_searches,
        saved_search_form => $c->form("SavedSearch")
    );
}

=head2 users

=cut

sub users :Chained('object') :PathPart('users') :Args(0) :AdminRole('USERS_READ') {
    my ( $self, $c ) = @_;
    my $id = $c->user->id;
    my ($status, $saved_searches) = $c->model("SavedSearch::User")->read_all($id);
    $c->stash(
        saved_searches => $saved_searches,
        saved_search_form => $c->form("SavedSearch")
    );
}

=head2 configuration

=cut

sub configuration :Chained('object') :PathPart('configuration') :Args(0) {
    my ( $self, $c, $section ) = @_;

}

=head2 checkup

=cut

sub checkup :Chained('object') :PathPart('checkup') :Args(0) {
    my ( $self, $c ) = @_;
    my @problems = sanity_check();
    $c->stash->{items}->{problems} = \@problems;
    $c->stash->{current_view} = 'JSON';
}

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
