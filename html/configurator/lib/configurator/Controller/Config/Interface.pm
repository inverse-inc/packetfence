package configurator::Controller::Config::Interface;
use HTTP::Status qw(:constants is_error);
use JSON;
use Moose;
use namespace::autoclean;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

pfws::Controller::Config::Interface - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->visit('read', ['all'], ['read']);
}

=head2 object

Chained dispatch for an interface.

=cut
sub object :Chained('/') :PathPart('config/interface') :CaptureArgs(1) {
    my ($self, $c, $interface) = @_;
    $c->stash->{interface} = $interface;
}

=head2 read

/config/interface/<interface>/read

=cut
sub read :Chained('object') :PathPart('read') :Args(0) {
    my ($self, $c) = @_;
    my $interface = $c->stash->{interface};

    my ($status, $message) = $c->model('Config::Pf')->read_interface($interface);
    if (is_error($status)) {
        $c->res->status($status);
        $c->error($message);
    }
    else {
        $c->stash->{interfaces} = $message;
    }
}

=head2 delete

/config/interface/<interface>/delete

=cut
sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ($self, $c) = @_;
    my $interface = $c->stash->{interface};

    my ($status, $message) = $c->model('Config::Pf')->delete_interface($interface);
    if (is_error($status)) {
        $c->res->status($status);
        $c->error($message);
    }
    else {
        $c->stash->{result} = $message;
    }
}

=head2 update

/config/interface/<interface>/update

=cut
sub update :Chained('object') :PathPart('update') :Args(0) {
    my ($self, $c) = @_;
    my $interface = $c->stash->{interface};

    my $assignments = $c->request->params->{assignments};

    if ($assignments) {
        eval {
            $assignments = decode_json($assignments);
        };
        if ($@) {
            # Malformed JSON
            chomp $@;
            $c->res->status(HTTP_BAD_REQUEST);
            $c->stash->{result} = $@;
        }
        else {
            my ($status, $message) = $c->model('Config::Pf')->update_interface($interface, $assignments);
            if (is_error($status)) {
                $c->res->status($status);
                $c->error($message);
            }
            else {
                $c->res->status(HTTP_CREATED);
                $c->stash->{result} = $status;
            }
        }
    }
    else {
        $c->res->status(HTTP_BAD_REQUEST);
        $c->stash->{result} = 'Missing parameters';
    }
}

=head2 create

/config/interface/create/<interface>
/config/interface/create?interface=<interface>

=cut

sub create :Local {
    my ($self, $c, $interface) = @_;

    $interface = $c->request->params->{interface} unless ($interface);
    my $assignments = $c->request->params->{assignments};

    if ($interface && $assignments) {
        eval {
            $assignments = decode_json($assignments);
        };
        if ($@) {
            # Malformed JSON
            chomp $@;
            $c->res->status(HTTP_BAD_REQUEST);
            $c->stash->{result} = $@;
        }
        else {
            my ($status, $message) = $c->model('Config::Pf')->create_interface($interface, $assignments);
            if (is_error($status)) {
                $c->res->status($status);
                $c->error($message);
            }
            else {
                $c->res->status(HTTP_CREATED);
                $c->stash->{result} = $status;
            }
        }
    }
    # FIXME is this still relevant? shouldn't it be no HTML forward and ->{result} instead of message?
    else {
        $c->res->status(HTTP_BAD_REQUEST);
        $c->stash->{message} = 'Missing parameters';
        $c->forward('View::HTML');
    }
}

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;
    $c->forward('View::JSON');
}

=head1 AUTHOR

Francis Lachapelle <flachapelle@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright 2012 Inverse inc.

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
