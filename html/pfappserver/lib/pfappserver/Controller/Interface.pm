package pfappserver::Controller::Interface;

=head1 NAME

pfappserver::Controller::Interface - Catalyst Controller

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

use pfappserver::Form::Interface;
use pfappserver::Form::Interface::Create;

BEGIN {extends 'Catalyst::Controller'; }

=head1 METHODS

=over

=item begin

This controller defaults view is HTML.

=cut

sub begin :Private {
    my ( $self, $c ) = @_;

    pf::config::cached::ReloadConfigs();
    $c->stash->{current_view} = 'HTML';

    # Only show the interfaces networks when in the admin app.
    # We know we're in the configurator when the 'enforcements' session variable is defined.
    if ($c->session->{enforcements}) {
        delete $c->stash->{show_network};
    } else {
        $c->stash->{show_network} = 1;
    }
}

=item index

=cut

sub index :Local :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'interface/index.tt';
    $c->visit('list');
}

=item list

=cut

sub list :Local :Args(0) {
    my ( $self, $c ) = @_;

    my $models =
      {
       'networks' => $c->model('Config::Cached::Network'),
       'interface' => $c->model('Config::Cached::Interface')
      };
    $c->stash->{interfaces} = $c->model('Interface')->get('all', $models);
}


=item object

Interface controller dispatcher

=cut

sub object :Chained('/') :PathPart('interface') :CaptureArgs(1) {
    my ( $self, $c, $interface ) = @_;

    my ($status, $status_msg) = $c->model('Interface')->exists($interface);
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $status_msg;

        $c->response->redirect($c->uri_for($self->action_for('list')));
        $c->detach();
    }

    $c->stash->{interface} = $interface;
    if ((my ($name, $vlan) = split(/\./, $interface))) {
        $c->stash->{ifname} = $name;
        $c->stash->{vlan} = $vlan;
    }
}

=item create

Create an interface vlan

Usage: /interface/<logical_name>/create

=cut

sub create :Chained('object') :PathPart('create') :Args(0) {
    my ( $self, $c ) = @_;

    my $mechanism = 'all';
    if ($c->session->{'enforcements'}) {
        $mechanism = [ keys %{$c->session->{'enforcements'}} ];
    }
    my $types = $c->model('Enforcement')->getAvailableTypes($mechanism);

    my ($status, $result, $form);

    if ($c->request->method eq 'POST') {
        $form = pfappserver::Form::Interface::Create->new(ctx => $c, types => $types);
        $form->process(params => $c->req->params);
        if ($form->has_errors) {
            $status = HTTP_BAD_REQUEST;
            $result = $form->field_errors; # translated by the form
        }
        else {
            my $data = $form->value;
            my $interface = $c->stash->{interface} . "." . $data->{vlan};
            ($status, $result) = $c->model('Interface')->create($interface);
            if (is_success($status)) {
                my $models =
                  {
                   'networks' => $c->model('Config::Cached::Network'),
                   'interface' => $c->model('Config::Cached::Interface')
                  };
                ($status, $result) = $c->model('Interface')->update($interface, $data, $models);
            }

            $c->response->status($status);
            $c->stash->{status_msg} = $c->loc($result);
        }
        $c->stash->{current_view} = 'JSON';
    }
    else {
        $form = pfappserver::Form::Interface::Create->new(ctx => $c,
                                                          types => $types,
                                                          init_object => { name => $c->stash->{interface} });
        $form->process();
        $c->stash->{form} = $form;

        $c->stash->{template} = 'interface/create.tt';
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

    $c->stash->{current_view} = 'JSON';
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

    # Return the interfaces status in the response
    my $interfaces = $c->model('Interface')->isActive('all');
    $c->stash->{interfaces} = $interfaces;

    $c->stash->{current_view} = 'JSON';
}

sub read :Chained('object') :ParthPart('read') :Args(0) {
    my ( $self, $c ) = @_;

    # Retrieve interface definition
    my $models =
      {
       'networks' => $c->model('Config::Cached::Network'),
       'interface' => $c->model('Config::Cached::Interface')
      };
    my $interface = $c->stash->{interface};
    my $interface_ref = $c->model('Interface')->get($interface, $models);
    $interface_ref->{$interface}->{name} = $interface;

    # Retrieve available enforcement types
    my $mechanism = 'all';
    if ($c->session->{'enforcements'}) {
        $mechanism = [ keys %{$c->session->{'enforcements'}} ];
    }
    my $interfaces = $c->model('Interface')->get('all', $models);
    my $types = $c->model('Enforcement')->getAvailableTypes($mechanism, $interface, $interfaces);

    # Build form
    my $form = pfappserver::Form::Interface->new(ctx => $c,
                                                 types => $types,
                                                 init_object => $interface_ref->{$interface});
    $form->process();
    $c->stash->{form} = $form;
}

=item update

Edit the configuration of the selected network interface

Usage: /interface/<logical_name>/update/<IP_address>/<netmask>

=cut

sub update :Chained('object') :PathPart('update') :Args(0) {
    my ( $self, $c ) = @_;

    my ($status, $result, $form);
    my $models =
      {
       'networks' => $c->model('Config::Cached::Network'),
       'interface' => $c->model('Config::Cached::Interface'),
       'system' => $c->model('Config::System'),
      };

    if ($c->request->method eq 'POST') {
        # Fetch valid types for enforcement mechanism
        my $mechanism = 'all';
        if ($c->session->{'enforcements'}) {
            $mechanism = [ keys %{$c->session->{'enforcements'}} ];
        }
        my $types = $c->model('Enforcement')->getAvailableTypes($mechanism);

        # Validate form
        $form = pfappserver::Form::Interface->new(ctx => $c, types => $types);
        $form->process(params => $c->req->params);
        if ($form->has_errors) {
            $status = HTTP_BAD_REQUEST;
            $result = $form->field_errors; # translated by the form
        }
        else {
            # Update interface
            my $data = $form->value;
            ($status, $result) = $c->model('Interface')->update($c->stash->{interface}, $data, $models);
            $result = $c->loc($result);
        }
        if (is_error($status)) {
            $c->response->status($status);
        }
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
    }
    else {
        $c->stash->{template} = 'interface/read.tt';
        $c->forward('read');
    }
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

    # Return the interfaces status in the response
    my $interfaces = $c->model('Interface')->isActive('all');
    $c->stash->{interfaces} = $interfaces;

    $c->stash->{current_view} = 'JSON';
}

=back

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
