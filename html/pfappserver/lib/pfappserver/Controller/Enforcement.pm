package pfappserver::Controller::Enforcement;

=head1 NAME

pfappserver::Controller::Enforcement - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 METHODS

=over

=item assign

=cut
sub assign :Chained('object') :PathPart('assign') :Args(1) {
    my ( $self, $c, $interface ) = @_;

    my ($status, $status_msg) = $c->model('Interface')->exists($interface);
    unless ( is_success($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $status_msg;
        $c->detach();
    }

    $c->session->{$interface} = $c->stash->{type};
}

=item list_mechanisms

=cut
sub list_mechanisms :Path('list_mechanisms') :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->status(200);
    $c->stash->{mechanisms} = $c->model('Enforcement')->_getAvailableMechanisms();
}

=item list_types

=cut
sub list_types :Path('list_types') :Args(1) {
    my ( $self, $c, $mechanism ) = @_;

    # Requested mechanism is invalid
    unless ( $c->model('Enforcement')->_isInArray($c->model('Enforcement')->_getAvailableMechanisms(), $mechanism) ) {
        $c->response->status(404);
        $c->stash->{status_msg} = "Unknown requested mechanism $mechanism";
        $c->detach();
    }

    $c->response->status(200);
    $c->stash->{types} = $c->model('Enforcement')->getAvailableTypes($mechanism);
}

=item object

=cut
sub object :Chained('/') :PathPart('enforcement') :CaptureArgs(1) {
    my ( $self, $c, $type ) = @_;

    # Requested type is invalid
    unless ( $c->model('Enforcement')->_isInArray($c->model('Enforcement')->getAvailableTypes('all'), $type) ) {
        $c->response->status(404);
        $c->stash->{status_msg} = "Unknown requested type $type";
        $c->detach();
    }

    $c->stash->{type} = $type;

    $c->load_status_msgs;
}

=item revoke

=cut
sub revoke :Chained('object') :PathPart('revoke') :Args(1) {
    my ( $self, $c, $interface ) = @_;

    my ($status, $status_msg) = $c->model('Interface')->exists($interface);
    unless ( is_success($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $status_msg;
        $c->detach();
    }

    $c->session->{$interface} = "";
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
