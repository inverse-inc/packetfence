package configurator::Controller::DB;

=head1 NAME

configurator::Controller::DB - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error);
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 METHODS

=over

=item assign

Assign a new user to a database.

Usage: /db/assign/<database_name>

=cut
sub assign :Path('assign') :Args(1) {
    my ( $self, $c, $db ) = @_;

    my $root_user       = $c->request->params->{root_user};
    my $root_password   = $c->request->params->{root_password};
    my $pf_user         = $c->request->params->{pf_user};
    my $pf_password     = $c->request->params->{pf_password};

    my ( $status, $message, $dbHandler ) = $c->model('DB')->connect('mysql', $root_user, $root_password);
    if ( !is_error($status) ) {
        ( $status, $message ) = $c->model('DB')->assign($dbHandler, $db, $pf_user, $pf_password);
    }
    if ( is_error($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message;
    } else {
        $c->stash->{status_msg} = $message;
    }
}

=item create

Create a new database.

Usage: /db/create/<database_name>

=cut
sub create :Path('create') :Args(1) {
    my ( $self, $c, $db ) = @_;

    my $root_user       = $c->request->params->{root_user};
    my $root_password   = $c->request->params->{root_password};

    my ( $status, $message ) = $c->model('DB')->create($db, $root_user, $root_password);
    if ( is_error($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message;
    } else {
        $c->stash->{status_msg} = $message;
    }
}

=item schema

Apply the PF MySQL schema to the requested database

Usage: /db/schema/<database_name>

=cut
sub schema :Path('schema') :Args(1) {
    my ( $self, $c, $db ) = @_;

    my $root_user       = $c->request->params->{root_user};
    my $root_password   = $c->request->params->{root_password};

    my ( $status, $message ) = $c->model('DB')->schema($db, $root_user, $root_password );

    if ( is_error($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message;
    } else {
        $c->stash->{status_msg} = $message;
    }
}

=item test

Test the connection to the database server with the provided root user / password.

Will try to connect to the 'mysql' database.

Usage: /db/test

=cut
sub test :Path('test') :Args(0) {
    my ( $self, $c ) = @_;

    my $root_user       = $c->request->params->{root_user};
    my $root_password   = $c->request->params->{root_password};

    my ( $status, $message ) = $c->model('DB')->connect('mysql', $root_user, $root_password);
    if ( is_error($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message;
    } else {
        $c->stash->{status_msg} = $message;
    }
}

=back

=head1 AUTHORS

Derek Wuelfrath <dwuelfrath@inverse.ca>

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
