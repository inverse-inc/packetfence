package configurator::Controller::Config::Networks;

=head1 NAME

configurator::Controller::Config::Networks - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use HTTP::Status qw(:constants is_error is_success);
use JSON;
use Moose;
use namespace::autoclean;
use Try::Tiny;

BEGIN {extends 'Catalyst::Controller'; }

=head1 METHODS

=over

=item create

Create a new network section in PacketFence networks.conf configuration file

Usage: /config/network/<network>/create

=cut
sub create :Chained('object') :PathPart('create') :Args(0) {
    my ( $self, $c ) = @_;

    my $network = $c->stash->{network};
    my $assignments_ref = $c->request->body_params;

    if ( defined($assignments_ref) ) {
        my ($status, $return) = $c->model('Config::Networks')->create_network($network, $assignments_ref);
        if ( is_success($status) ) {
            $c->response->status(HTTP_CREATED);
            $c->stash->{status_msg} = $return;
        } else {
            $c->response->status($status);
            $c->error($return);
        }
    } else {
        $c->response->status(HTTP_BAD_REQUEST);
        $c->stash->{status_msg} = 'Missing parameters';
    }
}

=item delete

Delete a network section in PacketFence networks.conf configuration file

Usage: /config/network/<network>/delete

=cut
sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ( $self, $c ) = @_;

    my $network = $c->stash->{network};

    my ($status, $return) = $c->model('Config::Networks')->delete_network($network);
    if ( is_success($status) ) {
        $c->stash->{status_msg} = $return;
    } else {
        $c->response->status($status);
        $c->error($return);
    }
}

=item index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->visit('read', ['all'], ['read']);
}

=item object

Chained dispatch

=cut
sub object :Chained('/') :PathPart('config/network') :CaptureArgs(1) {
    my ( $self, $c, $network ) = @_;

    $c->stash->{network} = $network;
}

=item read

Usage: /config/network/<network>/read

=cut
sub read :Chained('object') :PathPart('read') :Args(0) {
    my ( $self, $c ) = @_;

    my $network = $c->stash->{network};

    my ($status, $return) = $c->model('Config::Networks')->read_network($network);
    if ( is_success($status) ) {
        $c->stash->{networks} = $return;
    } else {
        $c->response->status($status);
        $c->error($return);
    }
}

=item update

Usage: /config/network/<network>/update

=cut
sub update :Chained('object') :PathPart('update') :Args(0) {
    my ( $self, $c ) = @_;

    my $network = $c->stash->{network};
    my $assignments_ref = $c->request->body_params->{assignments};

    if ( $assignments_ref ) {
        my $decoded_assignments_ref = try { return decode_json($assignments_ref); }
        catch {
            # Malformed JSON
            chomp $_;
            $c->response->status(HTTP_BAD_REQUEST);
            $c->stash->{status_msg} = $_;
            return;
        };
        if ( defined($decoded_assignments_ref) ) {
            my ($status, $return) = $c->model('Config::Networks')->update_network($network, $assignments_ref);
            if ( is_success($status) ) {
                $c->response->status(HTTP_CREATED);
                $c->stash->{status_msg} = $return;
            } else {
                $c->response->status($status);
                $c->error($return);
            }                
        }
    } else {
        $c->response->status(HTTP_BAD_REQUEST);
        $c->stash->{stash_msg} = "Missing parameters";
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
    $c->forward('View::JSON');
}

=back

=head1 AUTHORS

Derek Wuelfrath <dwuelfrath@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

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
