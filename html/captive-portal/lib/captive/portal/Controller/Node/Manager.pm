package captive::portal::Controller::Node::Manager;
use Moose;
use namespace::autoclean;
use pf::node;

BEGIN {extends 'captive::portal::Base::Controller'; }

=head1 NAME

captive::portal::Controller::Node::Manager - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub unreg :Local :Args(1) {
    my ( $self, $c, $mac ) = @_;
    my $username = $c->session->{username};
    my $node = node_view($mac);
    if($username && $mac) {
        if($username eq $node->{pid}) {
            node_unregistered($c);
            $c->response->redirect("/status");
            $c->detach;
        } else {
            $self->showError($c,"Not allowed to deregister $mac");
        }

    } else {
        $self->showError($c,"Not logged in or node ID $mac is not known");
    }
}


=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
