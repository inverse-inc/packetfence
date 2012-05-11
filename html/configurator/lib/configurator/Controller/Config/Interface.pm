package configurator::Controller::Config::Interface;
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

=cut

=head2 index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->visit('get', ['all'], ['get']);
}

=head2 object

Chained dispatch for an interface.

=cut
sub object :Chained('/') :PathPart('config/interface') :CaptureArgs(1) {
    my ($self, $c, $interface) = @_;
    $c->stash->{interface} = $interface;
}

=head2 get

/config/interface/<interface>/get

=cut
sub get :Chained('object') :PathPart('get') :Args(0) {
    my ($self, $c) = @_;
    my $interface = $c->stash->{interface};

    my ($result, $message) = $c->model('Config::Pf')->get($interface);
    if (!$result) {
        $c->error($message);
    }
    else {
        $c->res->status(200);
        $c->stash->{interfaces} = $message;
    }
}

=head2 delete

/config/interface/<interface>/delete

=cut
sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ($self, $c) = @_;
    my $interface = $c->stash->{interface};

    my ($result, $message) = $c->model('Config::Pf')->remove($interface);
    if (!$result) {
        $c->error($message);
    }
    else {
        $c->res->status(200);
        $c->stash->{result} = $message;
    }
}

=head2 edit

/config/interface/<interface>/edit

=cut
sub edit :Chained('object') :PathPart('edit') :Args(0) {
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
            $c->res->status(400);
            $c->stash->{result} = $@;
        }
        else {
            my ($result, $message) = $c->model('Config::Pf')->edit($interface, $assignments);
            if (!$result) {
                $c->error($message);
            }
            else {
                $c->res->status(201);
                $c->stash->{result} = $result;
            }
        }
    }
    else {
        $c->res->status(400);
        $c->stash->{result} = 'Missing parameters';
    }
}

=head2 add

/config/interface/add/<interface>
/config/interface/add?interface=<interface>

=cut

sub add :Local {
    my ($self, $c, $interface) = @_;

    $interface = $c->request->params->{interface} unless ($interface);
    my $assignments = $c->request->params->{assignments};

    if ($interface && $assignments) {
        my $result;
        eval {
            $assignments = decode_json($assignments);
        };
        if ($@) {
            # Malformed JSON
            chomp $@;
            $c->res->status(400);
            $c->stash->{result} = $@;
        }
        else {
            my ($result, $message) = $c->model('Config::Pf')->add($interface, $assignments);
            if (!$result) {
                $c->error($message);
            }
            else {
                $c->res->status(201);
                $c->stash->{result} = $result;
            }
        }
    }
    else {
        $c->res->status(400);
        $c->stash->{message} = 'Missing parameters';
        $c->forward('View::HTML');
    }
}

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;
    $c->forward('View::JSON');
}

=head1 AUTHOR

Francis Lachapelle

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
