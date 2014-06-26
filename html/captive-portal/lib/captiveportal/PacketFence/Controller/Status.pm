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

sub begin :Private {
    my ( $self, $c ) = @_;
    $c->forward('setupCurrentNodeInfo');
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $pid     = $c->session->{"username"};
    if ($pid) {
        $c->forward('userIsAuthenticated');
    } else {
        $c->forward('userIsNotAuthenticated');
    }
    $c->stash(
        template => 'status.html',
        billing  => isenabled( $c->profile->getBillingEngine ),
    );
}

sub userIsAuthenticated : Private {
    my ( $self, $c ) = @_;
    my $pid   = $c->session->{"username"};
    my @nodes = person_nodes($pid);
    foreach my $node (@nodes) {
        updateTimeleft($node);
    }
    $c->stash(
        nodes    => \@nodes,
    );
}

sub userIsNotAuthenticated : Private {
    my ( $self, $c ) = @_;
    $c->stash->{showLogin} = 1;
}

sub setupCurrentNodeInfo : Private {
    my ( $self, $c ) = @_;
    my $portalSession = $c->portalSession;
    my $node_info     = node_view( $portalSession->clientMac() );
    if( $node_info && $node_info->{pid} ne $default_pid ) {
        updateTimeleft($node_info);
    }
    $c->stash(
        node     => $node_info,
    );
}

sub updateTimeleft {
    my ($node_info) = @_;
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

sub login : Local {
    my ( $self, $c ) = @_;
    my $request = $c->request;
    my $username = $request->param('username');
    my $password = $request->param('password');
    if ( all_defined( $username, $password ) ) {
        $c->forward(Authenticate => 'authenticationLogin');
    }
    $c->forward('index');
}

sub logout : Local {
    my ( $self, $c ) = @_;
    $c->delete_session;
    $c->forward('index');
}


=head1 AUTHOR


=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
