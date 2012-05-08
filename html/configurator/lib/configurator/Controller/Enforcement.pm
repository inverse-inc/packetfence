package configurator::Controller::Enforcement;

=head1 NAME

configurator::Controller::Enforcement - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

# Catalyst includes
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }


=head1 SUBROUTINES

=over

=item assign

=cut
sub assign :Chained('object') :PathPart('assign') :Args(1) {
    my ( $self, $c, $interface ) = @_;

    unless ( $c->model('Interface')->_interfaceExists($interface) ) {
        $c->response->status(404);
        $c->stash->{status_msg} = "Unknown requested interface $interface";
        $c->detach();
    }

    my $mode    = $c->stash->{mode};
    my $type    = $c->stash->{type};

    
}

=item index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->redirect($c->uri_for($self->action_for('list')));
}

=item list_modes

=cut
sub list_modes :Path('list_modes') :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->status(200);
    $c->stash->{modes} = $c->model('Enforcement')->_getAvailableModes();
}

=item list_types

=cut
sub list_types :Path('list_types') :Args(1) {
    my ( $self, $c, $mode ) = @_;

    # Requested mode is invalid
    unless ( $c->model('Enforcement')->_isInArray($c->model('Enforcement')->_getAvailableModes(), $mode) ) {
        $c->response->status(404);
        $c->stash->{status_msg} = "Unknown requested mode $mode";
        $c->detach();
    }

    $c->response->status(200);
    $c->stash->{types} = $c->model('Enforcement')->_getAvailableTypes($mode);
}

=item object

=cut
sub object :Chained('/') :PathPart('mode') :CaptureArgs(2) {
    my ( $self, $c, $mode, $type ) = @_;

    # Requested mode is invalid
    unless ( $c->model('Enforcement')->_isInArray($c->model('Enforcement')->_getAvailableModes(), $mode) ) {
        $c->response->status(404);
        $c->stash->{status_msg} = "Unknown requested mode $mode";
        $c->detach();
    }

    # Requested type is invalid
    unless ( $c->model('Enforcement')->_isInArray($c->model('Enforcement')->_getAvailableTypes('all'), $type) ) {
        $c->response->status(404);
        $c->stash->{status_msg} = "Unknown requested type $type";
        $c->detach();
    }

    # Requested type is invalid for the requested mode
    unless ( $c->model('Enforcement')->_isInArray($c->model('Enforcement')->_getAvailableTypes($mode), $type) ) {
        $c->response->status(500);
        $c->stash->{status_msg} = "Requested type $type is invalid for the requested mode $mode";
        $c->detach();
    }    

    $c->stash->{mode} = $mode;
    $c->stash->{type} = $type;

    $c->load_status_msgs;
}

=item revoke

=cut
sub revoke :Chained('object') :PathPart('revoke') :Args(1) {
    my ( $self, $c, $interface ) = @_;

    unless ( $c->model('Interface')->_interfaceExists($interface) ) {
        $c->response->status(404);
        $c->stash->{status_msg} = "Unknown requested interface $interface";
        $c->detach();
    }
}


=back

=head1 AUTHOR

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
