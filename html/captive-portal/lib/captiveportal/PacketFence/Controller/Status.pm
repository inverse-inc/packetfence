package captiveportal::PacketFence::Controller::Status;
use Moose;
use namespace::autoclean;
use pf::util;
use pf::constants;
use pf::config;
use pf::config qw(%ConfigSelfService);
use pf::node;
use pf::person;
use pf::web;
use pf::security_event qw(security_event_view_open);
use pf::constants::security_event qw($LOST_OR_STOLEN);
use pf::password qw(view);
use pf::authentication;

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::Status - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub auto :Private {
    my ( $self, $c ) = @_;
    $c->session->{release_bypass} = $TRUE;
    $c->stash->{isDeviceRegEnable} = $c->forward(DeviceRegistration => "isDeviceRegEnabled");
    $c->stash->{stripeCustomerPortalEnabled} = $c->profile->stripeCustomerPortalEnabled;
    $c->stash->{dynamicPreSharedKeyEnabled} = is_dpsk_enabled($c->profile);
    $c->forward('setupCurrentNodeInfo');
    return 1;
}

sub is_dpsk_enabled {
    my ( $profile ) = @_;

    if (exists $profile->{'_self_service'} && $profile->{'_self_service'} ne "" && isenabled($ConfigSelfService{$profile->{'_self_service'}}{'dynamic_pre_shared_key'}) ) {
        return $TRUE;
    }
    return $FALSE;
}

=head2 index

=cut


sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    if($c->request->param('logout_url')) {
        $c->user_session->{logout_url} = $c->request->param('logout_url');
    }
    my $pid     = $c->user_session->{"username"} // $c->{_session}->{username};
    if ( $c->has_errors ) {
        $c->stash->{txt_auth_error} = join(' ', grep { ref ($_) eq '' } @{$c->error});
        $c->clear_errors;
    }
    if ($pid) {
        $c->forward('userIsAuthenticated');
    } else {
        $c->response->redirect('/status/login');
        $c->detach();
    }
    if (view($pid)) {
        $c->stash->{hasLocalAccount} = $TRUE;
    }
    $c->stash(
        title => "Status - Network Access",
        template => 'status.html',
        billing  => $c->profile->hasBilling(),
        access_registration_when_registered => $c->profile->canAccessRegistrationWhenRegistered(),
        logout_url => $c->user_session->{logout_url},
    );
}

sub is_lost_stolen {
    my ( $mac ) = @_;
   
    my @security_events = security_event_view_open($mac);
    if ( grep {$_->{'security_event_id'} eq $LOST_OR_STOLEN} @security_events ) {
        return $TRUE
    } else {
        return $FALSE
    }
}

sub userIsAuthenticated : Private {
    my ( $self, $c ) = @_;
    my $pid     = $c->user_session->{"username"} // $c->{_session}->{username};
    my @person_nodes = person_nodes($pid);
    my @nodes;
    foreach my $person_node (@person_nodes) {
        my $node = node_view($person_node->{mac});
        setExpiration($node);
        my $mac = $node->{'mac'};
        if (is_lost_stolen($mac)) {
            $node->{lostOrStolen} = $TRUE;
        }
        push @nodes, $node;
    }
    $c->stash(
        nodes    => \@nodes,
    );
    if (is_dpsk_enabled($c->profile)) {
        my @provisioners = $c->profile->provisionerObjects();

        foreach my $provisioner (@provisioners) {
            next unless $provisioner->isa("pf::provisioner::dpsk");
            my $dpsk = $provisioner->generate_dpsk($pid);
            if (!$dpsk) {
                $dpsk = "Error generating the PSK, contact your administrator";
            }
            $c->stash( psk => $dpsk);
        }
    }
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
                # No more access time; RADIUS accounting should have triggered a security_event
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
    $c->stash( 
        template => 'status/login.html',
        title => "Status - Login",
    );
    if ( all_defined( $username, $password ) ) {
        $c->forward(Authenticate => 'authenticationLogin');
        if ( $c->has_errors ) {
            $c->stash->{txt_auth_error} = join(' ', grep { ref ($_) eq '' } @{$c->error});
            $c->clear_errors;
        } else {
            $c->response->redirect('/status');
        }
    }
}

sub reset_password : Local {
    my ( $self, $c ) = @_;
    my $pid     = $c->user_session->{"username"};
    if ( $c->has_errors ) {
        $c->stash->{txt_auth_error} = join(' ', grep { ref ($_) eq '' } @{$c->error});
        $c->clear_errors;
    }
    if ($pid) {
        $c->forward('userIsAuthenticated');
    } else {
        $c->forward('login');
    }
    $c->stash(
        title => "Status - Manage Account",
        template => 'status/reset_password.html',
        logout_url => $c->user_session->{logout_url},
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
    $c->stash->{template} = 'status/reset_password.html';
}


sub logout : Local {
    my ( $self, $c ) = @_;
    $c->user_session({});
    $c->forward('index');
}

sub billing_cancel_subscription : Path('/status/billing/cancel_subscription') : Args(2) {
    my ($self, $c, $source_id, $subscription_id) = @_;
    my $source = getAuthenticationSource($source_id);
    $c->stash->{template} = "status/billing_cancel_subscription.html";
    if(!$source) {
        $c->stash(
            error => "Unable to find source $source_id",    
        );
    }
    
    if($c->request->method eq "POST") {
        my ($res, $msg) = $source->handleCancelLink($subscription_id, $c->request->parameters);
        if($res) {
            $c->stash->{status} = "canceled";
        }
        else {
            $c->stash(
                error => $msg,
            );
        }
    }

}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
