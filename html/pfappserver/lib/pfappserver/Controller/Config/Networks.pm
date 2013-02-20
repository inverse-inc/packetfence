package pfappserver::Controller::Config::Networks;

=head1 NAME

pfappserver::Controller::Config::Networks - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use pfappserver::Form::Config::Network;
use pfappserver::Form::Config::Network::Routed;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

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

Usage: /config/network/create

=cut

sub create :Path('create') :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{action_uri} = $c->uri_for($c->action);
    if ($c->request->method eq 'POST') {
        my $network = $c->req->params->{network};
        $c->stash->{network} = $network;
        $c->forward('update');
    }
    else {
        $c->forward('read');
    }
}

=item object

Chained dispatch

=cut
sub object :Chained('/') :PathPart('config/network') :CaptureArgs(1) {
    my ( $self, $c, $network ) = @_;

    my ($status, $return )= $c->model('Config::Networks')->read($network);
    if ( is_success($status) ) {
        $c->stash->{network_ref} = shift @$return;
    }
    $c->stash->{network} = $network;
}

=item delete

Delete a network section in PacketFence networks.conf configuration file

Usage: /config/network/<network>/delete

=cut

sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ( $self, $c ) = @_;

    my $network = $c->stash->{network};

    my ($status, $return) = $c->model('Config::Networks')->delete($network);
    if ( is_success($status) ) {
        $c->stash->{status_msg} = $return;
    } else {
        $c->response->status($status);
        $c->error($return);
    }
}

=item read

Usage: /config/network/<network>/read

=cut
sub read :Chained('object') :PathPart('read') :Args(0) {
    my ( $self, $c ) = @_;

    my $network = $c->stash->{network};
    my $network_ref = $c->stash->{network_ref};
    my $form;

    if (defined($network)) {
        # Edit an existing network
        $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [$network]);
    }

    if (!defined($network) || $network_ref->{next_hop}) {
        # Create or edit a routed network
        $form = pfappserver::Form::Config::Network::Routed->new(ctx => $c, network => $network, init_object => $network_ref);
    }
    else {
        # Edit the default interface network
        $form = pfappserver::Form::Config::Network->new(ctx => $c, network => $network, init_object => $network_ref);
    }
    $form->process();
    $c->stash->{form} = $form;
    $c->stash->{template} = 'config/network.tt';
    $c->stash->{current_view} = 'HTML';
}

=item update

Usage: /config/network/<network>/update

=cut
sub update :Chained('object') :PathPart('update') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'POST') {
        my ($status, $result);
        my ($form, $network, $network_ref);

        $network = $c->stash->{network};
        $network_ref = $c->stash->{network_ref};

        # Validate form
        if (!defined($network_ref)) {
            # Create a routed network
            $form = pfappserver::Form::Config::Network::Routed->new(ctx => $c);
        } elsif ($network_ref->{next_hop}) {
            # Edit a routed network
            $form = pfappserver::Form::Config::Network::Routed->new(ctx => $c, network => $network);
        } else {
            # Edit the default interface network
            $form = pfappserver::Form::Config::Network->new(ctx => $c, network => $network);
        }
        $form->process(params => $c->req->params);
        if ($form->has_errors) {
            $status = HTTP_BAD_REQUEST;
            $result = $form->field_errors;
        }
        else {
            # Write networks.conf
            if ($form->value->{network} && $network ne $form->value->{network}) {
                # Network address has changed
                $c->model('Config::Networks')->update_network($network, $form->value->{network});
                $network = $form->value->{network};
                $network_ref = $form->value;
            }
            delete $form->value->{network};
            if ($network_ref) {
                # Update an existing network
                ($status, $result) = $c->model('Config::Networks')->update($network, $form->value);
            }
            else {
                # Create a new network
                ($status, $result) = $c->model('Config::Networks')->create($network, $form->value);
            }
        }

        $c->response->status($status);
        $c->stash->{status_msg} = $result; # TODO: localize error message
    }
    else {
        $c->stash->{template} = 'config/network.tt';
        $c->forward('read');
    }
}

=back

=head1 FRAMEWORK HELPERS

=over

=item end

=cut
sub end :ActionClass('RenderView') {
    my ( $self, $c ) = @_;

    # TODO In DEVEL that's cool, but in production we want only a generic 500 message and logging on 'unhandled' errors
    if ( scalar @{ $c->error } ) {
        $c->stash->{status_msg} = $c->error;
        $c->forward('View::JSON');
        $c->error(0);
    }
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
