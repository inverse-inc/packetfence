package captiveportal::PacketFence::Controller::Status;
use Moose;
use namespace::autoclean;
use pf::util;
use pf::config;
use pf::node;
use pf::person;

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::Status - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my @nodes;
    my $portalSession = $c->portalSession;
    my $node_info     = node_view( $portalSession->clientMac() );
    if( $node_info->{pid} ne $default_pid ) {
        @nodes         = person_nodes($node_info->{pid});
        if ( defined $node_info->{'last_start_timestamp'}
            && $node_info->{'last_start_timestamp'} > 0 ) {
            if ( $node_info->{'timeleft'} > 0 ) {

                # Node has a usage duration
                $node_info->{'expiration'} =
                  $node_info->{'last_start_timestamp'} + $node_info->{'timeleft'};
                if ( $node_info->{'expiration'} < time ) {

                    # No more access time; RADIUS accounting should have triggered a violation
                    delete $node_info->{'expiration'};
                    $node_info->{'timeleft'} = 0;
                }
            }
        }
    }
    $c->stash(
        template => 'status.html',
        node     => $node_info,
        nodes    => \@nodes,
        billing  => isenabled( $c->profile->getBillingEngine ),
    );
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
