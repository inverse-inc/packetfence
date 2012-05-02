package configurator::Controller::Interface;

=head1 NAME

configurator::Controller::Interface - Catalyst Controller

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

=item add

Add the selected network interface to the system
Usage: /interface/<logical_name>/add

=cut
sub add :Chained('object') :PathPart('add') :Args(0) {
    my ( $self, $c ) = @_;

    my $interface = $c->stash->{interface};

    my $result = $c->model('Interface')->add($interface);

    if ( $result eq 1 ) {
        $c->response->status(200);
        $c->stash->{status_msg} = "Interface $interface successfully added on the system";
    } else {
        $c->response->status(500);
        $c->stash->{status_msg} = $result;
    }

    $c->response->redirect($c->uri_for($self->action_for('list'),
        {mid => $c->set_status_msg($c->stash->{status_msg})}));
}

=item create

Create a vlan interface on the system
Usage: /interface/create/<logical_name>

=cut
sub create :Path('create') :Args(1) {
    my ( $self, $c, $interface ) = @_;

    my $result = $c->model('Interface')->create($interface);

    if ( $result eq 1 ) {
        $c->response->status(200);
        $c->stash->{status_msg} = "Interface $interface successfully created";
    } else {
        $c->response->status(500);
        $c->stash->{status_msg} = $result;
    }

    $c->response->redirect($c->uri_for($self->action_for('list'),
        {mid => $c->set_status_msg($c->stash->{status_msg})}));
}

=item delete

=cut
sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ( $self, $c ) = @_;

    my $interface = $c->stash->{interface};

    my $result = $c->model('Interface')->delete($interface);

    if ( $result eq 1 ) {
        $c->response->status(200);
        $c->stash->{status_msg} = "Interface $interface successfully deleted";
    } else {
        $c->response->status(500);
        $c->stash->{status_msg} = $result;
    }

    $c->response->redirect($c->uri_for($self->action_for('list'),
        {mid => $c->set_status_msg($c->stash->{status_msg})}));
}

=item edit

Edit the configuration of the selected network interface
Usage: /interface/<logical_name>/edit/<IP_address>/<netmask>

=cut
sub edit :Chained('object') :PathPart('edit') :Args(2) {
    my ( $self, $c, $ipaddress, $netmask ) = @_;

    my $interface = $c->stash->{interface};

    my $result = $c->model('Interface')->edit($interface, $ipaddress, $netmask);

    if ( $result eq 1 ) {
        $c->response->status(200);
        $c->stash->{status_msg} = "Interface $interface successfully edited";
    } else {
        $c->response->status(500);
        $c->stash->{status_msg} = $result;
    }

    $c->response->redirect($c->uri_for($self->action_for('list'),
        {mid => $c->set_status_msg($c->stash->{status_msg})}));
}

=item get

Retrieve the configuration of the selected network interface(s)
Usage: /interface/<logical_name>/get

=cut
sub get :Chained('object') :PathPart('get') :Args(0) {
    my ( $self, $c ) = @_;

    my $interface = $c->stash->{interface};

    my $result;
    eval {
        $result = $c->model('Interface')->get($interface);
    };

    if ( $@ ) {
        chomp $@;
        $c->response->status(500);
        $c->stash->{status_msg} = $@;
    } else {
        $c->response->status(200);
        $c->stash(interfaces => $result);
    }
}

=item index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->redirect($c->uri_for($self->action_for('list')));
}

=item list

=cut
sub list :Path('list') Args(0) {
#sub list :Chained('object') :PathPart('list') :Args(0) {
    my ( $self, $c ) = @_;

    $c->visit('get', ['all'], ['get']);
}

=item object

Interface controller dispatcher

=cut
sub object :Chained('/') :PathPart('interface') :CaptureArgs(1) {
    my ( $self, $c, $interface ) = @_;

    unless ( $c->model('Interface')->_interfaceExists($interface) ) {
        $c->response->status(404);
        $c->stash->{status_msg} = "Unknown requested interface $interface";
        $c->detach();
    }

    $c->stash->{interface} = $interface;

    $c->load_status_msgs;
}
=item remove

Remove the selected network interface
Usage: /interface/<logical_name>/remove

=cut
sub remove :Chained('object') :PathPart('remove') :Args(0) {
    my ( $self, $c ) = @_;

    my $interface = $c->stash->{interface};

    my $result = $c->model('Interface')->remove($interface);

    if ( $result eq 1 ) {
        $c->response->status(200);
        $c->stash->{status_msg} = "Interface $interface successfully removed from the system";
    } else {
        $c->response->status(500);
        $c->stash->{status_msg} = $result;
    }

    $c->response->redirect($c->uri_for($self->action_for('list'),
        {mid => $c->set_status_msg($c->stash->{status_msg})}));
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
