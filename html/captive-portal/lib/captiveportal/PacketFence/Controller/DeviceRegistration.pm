package captiveportal::PacketFence::Controller::DeviceRegistration;;
use Moose;
use namespace::autoclean;
use pf::config;
use pf::log;
use pf::node;
use pf::util;
use pf::web;
use pf::web::gaming;

BEGIN { extends 'captiveportal::Base::Controller'; }

__PACKAGE__->config( namespace => 'device-registration' );

=head1 NAME

captiveportal::PacketFence::Controller::DeviceRegistration - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub begin {
    my ( $self, $c ) = @_;
    if (isdisabled( $Config{'registration'}{'device_registration'} ) )
    {
        $self->showError( $c, "This module is not enabled" );
        $c->detach;
    }
    $c->stash->{console_types} = @pf::web::gaming::GAMING_CONSOLE_TYPES;
}

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $logger  = get_logger;
    my $pid     = $c->session->{"username"};
    my $request = $c->request;

    # See if user is trying to login and if is not already authenticated
    if ( ( !$pid ) ) {
        # Verify if user is authenticated
        $c->forward('userNotLoggedIn');
    } elsif ( $request->param('cancel') ) {
        $c->delete_session;
        $c->stash->{txt_auth_error} =
          'Registration canceled. Please try again.';
        $c->detach('login');
    } elsif ( $request->param('device_mac') ) {
        # User is authenticated and requesting to register gaming device
        my $device_mac = clean_mac($request->param('device_mac'));
        if(valid_mac($device_mac)) {
            # Register gaming device
            $c->forward('registerNode', [ $pid, $device_mac ]);
            unless ($c->stash->{txt_auth_error}) {
                $c->stash(status_msg  => i18n_format("The MAC address %s has been successfully registered.", $device_mac));
                $c->detach('landing');
            }
        } else {
            $c->stash(txt_auth_error => "Please verify the provided MAC address.");
        }
    }
    # User is authenticated so display registration page
    $c->stash(template => 'gaming-registration.html');
}

sub gaming_registration: Local('gaming-registration') {
    my ( $self, $c ) = @_;
    $c->forward('index');
}


=head2 userNotLoggedIn

TODO: documention

=cut

sub userNotLoggedIn {
    my ($self, $c) = @_;
    my $request = $c->request;
    my $username = $request->param('username');
    my $password = $request->param('password');
    if ( all_defined( $username, $password ) ) {
        $c->forward(Authenticate => 'authenticationLogin');
        if ($c->stash->{txt_auth_error}) {
            $c->detach('login');
        }
    } else {
        $c->detach('login');
    }
}

=head2 login

Display the gaming login

=cut

sub login : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'gaming-login.html' );
}

sub landing : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'gaming-landing.html' );
}

sub registerNode {
    my ( $self, $c, $pid, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    if ( pf::web::gaming::is_allowed_gaming_mac($mac) ) {
        my ($node) = node_view($mac);
        if( $node && $node->{status} ne $pf::node::STATUS_UNREGISTERED ) {
            $c->stash(txt_auth_error => "$mac is already registered or pending to be registered. Please verify MAC address if correct contact your network administrator");
        } else {
            my %info;
            $c->stash->{device_mac} = $mac;
            # Get role for gaming device
            my $role =
              $Config{'registration'}{'device_registration_role'};
            if ($role) {
                $logger->trace("Gaming devices role is $role (from pf.conf)");
            } else {
                # Use role of user
                $role = &pf::authentication::match(
                    &pf::authentication::getInternalAuthenticationSources(),
                    { username => $pid },
                    $Actions::SET_ROLE
                );
                $logger->trace(
                    "Gaming devices role is $role (from username $pid)");
            }
            $info{'category'} = $role if ( defined $role );
            $info{'auto_registered'} = 1;
            $info{'mac'} = $mac;
            $c->forward( 'CaptivePortal' => 'webNodeRegister', [ $pid, %info ] );
        }
    } else {
        $c->stash(txt_auth_error => "Please verify the provided MAC address.");
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
