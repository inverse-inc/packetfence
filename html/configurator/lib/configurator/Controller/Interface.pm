package configurator::Controller::Interface;

=head1 NAME

configurator::Controller::Interface - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 STATUS

Currently, DHCP interfaces are not supported, which mean:

- DHCP configured interface will be reconfigured as static interfaces

- It is not possible to use DHCP to configure an existing interface.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 METHODS

=over

=item begin

This controller defaults view is JSON.

=cut
sub begin :Private {
    my ( $self, $c ) = @_;

    $c->stash->{current_view} = 'JSON';
}

=item create

Create a vlan interface

Usage: /interface/create/<logical_name>

=cut
sub create :Path('create') :Args(1) {
    my ( $self, $c, $interface ) = @_;

    my ($status, $status_msg) = $c->model('Interface')->create($interface);

    if ( is_success($status) ) {
        $c->stash->{status_msg} = $status_msg;
    } else {
        $c->response->status($status);
        $c->stash->{status_msg} = $status_msg;
    }
}

=item delete

Delete an existing vlan interface

Usage: /interface/<logical_name>/delete

=cut
sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ( $self, $c ) = @_;

    my $interface = $c->stash->{interface};
    my ($status, $status_msg) = $c->model('Interface')->delete($interface, $c->req->uri->host);

    if ( is_success($status) ) {
        $c->stash->{status_msg} = $status_msg;
    } else {
        $c->response->status($status);
        $c->stash->{status_msg} = $status_msg;
    }
}

=item down

Down the selected network interface

Usage: /interface/<logical_name>/down

=cut
sub down :Chained('object') :PathPart('down') :Args(0) {
    my ( $self, $c ) = @_;

    my $interface = $c->stash->{interface};
    my ($status, $status_msg) = $c->model('Interface')->down($interface, $c->req->uri->host);

    if ( is_success($status) ) {
        $c->stash->{status_msg} = $status_msg;
    } else {
        $c->response->status($status);
        $c->stash->{status_msg} = $status_msg;
    }
}

=item edit

Edit the configuration of the selected network interface

Usage: /interface/<logical_name>/edit/<IP_address>/<netmask>

=cut
sub edit :Chained('object') :PathPart('edit') :Args(2) {
    my ( $self, $c, $ipaddress, $netmask ) = @_;

    my $interface = $c->stash->{interface};
    my ($status, $status_msg) = $c->model('Interface')->edit($c->model('Config::Networks'), $interface, $ipaddress, $netmask);

    if ( is_success($status) ) {
        $c->stash->{status_msg} = $status_msg;
    } else {
        $c->response->status($status);
        $c->stash->{status_msg} = $status_msg;
    }
}

=item get

Retrieve the configuration of the selected network interface(s)

Usage: /interface/<logical_name>/get

=cut
sub get :Chained('object') :PathPart('get') :Args(0) {
    my ( $self, $c ) = @_;

    my $interface = $c->stash->{interface};

    my $interfaces_ref = $c->model('Interface')->get($interface);
    $c->stash->{interfaces} = $interfaces_ref;
    $c->stash(types => $c->model('Enforcement')->getAvailableTypes([ keys %{$c->session->{'enforcements'}} ]));
    my ($status, $interfaces_types) = $c->model('Config::Networks')->get_types($c->stash->{interfaces});
    if (is_success($status)) {
        my $wizardController = $c->controller('Wizard');
        $c->stash(interfaces_types => $wizardController->_prepare_types_for_display($c, $interfaces_ref, $interfaces_types));
    }
    $c->stash->{current_view} = 'HTML';
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

    my ($status, $status_msg) = $c->model('Interface')->exists($interface);
    unless ( is_success($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $status_msg;

        $c->response->redirect($c->uri_for($self->action_for('list')));

        $c->detach();
    }

    $c->stash->{interface} = $interface;
}

=item up

Activate the selected network interface

Usage: /interface/<logical_name>/up

=cut
sub up :Chained('object') :PathPart('up') :Args(0) {
    my ( $self, $c ) = @_;

    my $interface = $c->stash->{interface};
    my ($status, $status_msg) = $c->model('Interface')->up($interface);

    if ( is_success($status) ) {
        $c->stash->{status_msg} = $status_msg;
    } else {
        $c->response->status($status);
        $c->stash->{status_msg} = $status_msg;
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
