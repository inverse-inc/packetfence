package captiveportal::PacketFence::Controller::Status;
use Moose;
use namespace::autoclean;
use pf::util;
use pf::constants;
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
    $c->session->{release_bypass} = $TRUE;
    $c->forward('setupCurrentNodeInfo');
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $pid     = $c->user_session->{"username"};
    if ($pid) {
        $c->forward('userIsAuthenticated');
    } else {
        $c->forward('userIsNotAuthenticated');
    }
    $c->stash(
        template => 'status.html',
        billing  => $c->profile->hasBilling(),
    );
}

sub userIsAuthenticated : Private {
    my ( $self, $c ) = @_;
    my $pid   = $c->user_session->{"username"};
    my @nodes = person_nodes($pid);
    foreach my $node (@nodes) {
        setExpiration($node);
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
    if( $node_info && ($node_info->{pid} ne $default_pid && $node_info->{pid} ne $admin_pid ) ) {
        setExpiration($node_info);
    }
    $c->stash(
        node     => $node_info,
    );
}

sub setExpiration {
    my ($node_info) = @_;
    if ( defined $node_info->{'last_start_timestamp'}
         && $node_info->{'last_start_timestamp'} > 0 ) {
        if ( $node_info->{'time_balance'} > 0 ) {

            # Node has a usage duration
            $node_info->{'expiration'} = $node_info->{'last_start_timestamp'} + $node_info->{'time_balance'};
            if ( $node_info->{'expiration'} < time ) {
                # No more access time; RADIUS accounting should have triggered a violation
                delete $node_info->{'expiration'};
                $node_info->{'time_balance'} = 0;
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
    $c->user_session({});
    $c->forward('index');
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

1;
