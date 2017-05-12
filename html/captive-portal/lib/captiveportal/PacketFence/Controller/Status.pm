package captiveportal::PacketFence::Controller::Status;
use Moose;
use namespace::autoclean;
use pf::util;
use pf::constants;
use pf::config;
use pf::node;
use pf::person;
use pf::web;

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::Status - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub auto :Private {
    my ( $self, $c ) = @_;
    $c->session->{release_bypass} = $TRUE;
    $c->forward('setupCurrentNodeInfo');
    return 1;
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $pid     = $c->user_session->{"username"};
    if ( $c->has_errors ) {
        $c->stash->{txt_auth_error} = join(' ', grep { ref ($_) eq '' } @{$c->error});
        $c->clear_errors;
    }
    if ($pid) {
        $c->forward('userIsAuthenticated');
    } else {
        $c->forward('userIsNotAuthenticated');
    }
    if (person_has_local_account($pid)) {
        $c->stash->{hasLocalAccount} = 1;
    }
    $c->stash(
        title => "Status - Network Access",
        template => 'status.html',
        billing  => $c->profile->hasBilling(),
        access_registration_when_registered => $c->profile->canAccessRegistrationWhenRegistered(),
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
        if ( defined ( $node_info->{'time_balance'} )
         && $node_info->{'time_balance'} > 0) {
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
        if ($c->has_errors) {
            $c->detach('index');
        }
        $c->forward(Authenticate => 'authenticationLogin');
    }
    $c->forward('index');
}

sub person : Local {
    my ( $selfc, $c ) = @_;
    my $pid     = $c->user_session->{"username"};
    if ( $c->has_errors ) {
        $c->stash->{txt_auth_error} = join(' ', grep { ref ($_) eq '' } @{$c->error});
        $c->clear_errors;
    }
    if ($pid) {
        $c->forward('userIsAuthenticated');
    } else {
        $c->forward('userIsNotAuthenticated');
    }
    $c->stash(
        title => "Status - Manage Account",
        template => 'status/person.html',
    );
} 

sub reset_pw : Local {
    my ( $self, $c ) = @_;
    my $pid     = $c->user_session->{"username"};
    my $request = $c->request;
    my $password = $request->param('password');
    my $password2 = $request->param('password2');
    if ( all_defined ( $password, $password2 ) && ( $password eq $password2 ) ) {
        pf::password::reset_password($pid, $password);
        $c->stash->{status} = "success";
    } elsif ( $password ne $password2 ) {
        $c->stash->{status} = "error_match";
    } else {
        $c->stash->{status} = "error_fill";
    }
    $c->stash->{template} = 'status/person.html';
}


sub logout : Local {
    my ( $self, $c ) = @_;
    $c->user_session({});
    $c->forward('index');
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
