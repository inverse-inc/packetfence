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

    my $mechanism   = $c->stash->{mechanism};
    my $type        = $c->stash->{type};

    
}

=item index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->redirect($c->uri_for($self->action_for('list')));
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
    $c->stash->{types} = $c->model('Enforcement')->_getAvailableTypes($mechanism);
}

=item object

=cut
sub object :Chained('/') :PathPart('enforcement') :CaptureArgs(2) {
    my ( $self, $c, $mechanism, $type ) = @_;

    # Requested mechanism invalid
    unless ( $c->model('Enforcement')->_isInArray($c->model('Enforcement')->_getAvailableMechanisms(), $mechanism) ) {
        $c->response->status(404);
        $c->stash->{status_msg} = "Unknown requested mechanism $mechanism";
        $c->detach();
    }

    # Requested type is invalid
    unless ( $c->model('Enforcement')->_isInArray($c->model('Enforcement')->_getAvailableTypes('all'), $type) ) {
        $c->response->status(404);
        $c->stash->{status_msg} = "Unknown requested type $type";
        $c->detach();
    }

    # Requested type is invalid for the requested mechanism
    unless ( $c->model('Enforcement')->_isInArray($c->model('Enforcement')->_getAvailableTypes($mechanism), $type) ) {
        $c->response->status(500);
        $c->stash->{status_msg} = "Requested type $type is invalid for the requested mechanism $mechanism";
        $c->detach();
    }    

    $c->stash->{mechanism} = $mechanism;
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
