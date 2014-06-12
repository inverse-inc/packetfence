package captiveportal::PacketFence::Controller::Node::Manager;

use Moose;
use namespace::autoclean;
use pf::config;
use pf::node;
use pf::enforcement qw(reevaluate_access);

BEGIN {extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::Node::Manager - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub unreg :Local :Args(1) {
    my ($self, $c, $mac) = @_;
    my $username = $c->session->{username};
    my $node = node_view($mac);
    if ($username && $node) {
        $c->log->info("$username attempting to unregister $mac");
        if ($username ne $default_pid && $username eq $node->{pid}) {
            node_deregister($mac, %$node);
            reevaluate_access($mac, "node_modify");
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
