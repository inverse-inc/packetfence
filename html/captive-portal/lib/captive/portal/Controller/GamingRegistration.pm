package captive::portal::Controller::GamingRegistration;
use Moose;
use namespace::autoclean;
use pf::config;
use pf::log;
use pf::util;
use pf::web;

BEGIN { extends 'captive::portal::Base::Controller'; }

__PACKAGE__->config( namespace => 'gaming-registration' );

=head1 NAME

captive::portal::Controller::GamingRegistration - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub begin : Hookable('Private') {
    my ( $self, $c ) = @_;
    if (isdisabled( $Config{'registration'}{'gaming_devices_registration'} ) )
    {
        $self->showError( $c, "This module is not enabled" );
        $c->detach;
    }
}

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $logger  = get_logger;
    my $pid     = $c->session->{"username"};
    my $request = $c->request;
    my $info    = $c->stash->{info} || {};

    # See if user is trying to login and if is not already authenticated
    if (   ( !$pid )
        && ( $request->param('username') ne '' )
        && ( $request->param('password') ne '' ) ) {
        $c->forward( Authenticate => 'authenticationLogin' );
        if ( $c->stash->{txt_auth_error} ) {
            $c->detach('login');
        }
    } elsif ( !$pid ) {
        # Verify if user is authenticated
        $c->detach('login');
    } elsif ( $request->param('cancel') ) {
        $c->delete_session;
        $c->stash->{txt_auth_error} =
          'Registration canceled. Please try again.';
        $c->detach('login');
    } elsif ( $request->param('device_mac') ) {
        # User is authenticated and requesting to register gaming device
        my $device_mac = $request->param('device_mac');
        $c->stash->{device_mac} = $device_mac;
        # Get role for gaming device
        my $role =
          $Config{'registration'}{'gaming_devices_registration_role'};
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
        $info->{'category'} = $role if ( defined $role );
        $info->{'auto_registered'} = 1;
        # Register gaming device
        my ( $result, $msg ) =
          $c->forward( 'registerNode', [ $pid, $device_mac, %$info ] );
        unless ($result) {
            $c->stash->{txt_auth_error} = $msg;
        }
    }
    # User is authenticated so display registration page
    $c->stash( template => 'gaming-registration.html' );
}

sub login : Local : Args(0) : Hookable {
    my ( $self, $c ) = @_;
    $c->stash( template => 'gaming-login.html' );
}

sub landing : Local : Args(0) : Hookable {
    my ( $self, $c ) = @_;
    $c->stash( template => 'gaming-langing.html' );
}

sub registerNode : Hookable('Private') {
    my ( $self, $c, $pid, $mac, %info ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ( $msg, $result );
    if ( !valid_mac($mac) || !is_gaming_mac($mac) ) {
        $msg = "Please verify the provided MAC address.";
    } elsif ( !defined( $info{'category'} ) ) {
        $msg =
          "Can't determine the role. Please contact your system administrator.";
    } elsif ( is_max_reg_nodes_reached( $mac, $pid, $info{'category'} ) ) {
        $msg =
          "You have reached the maximum number of devices you are able to register with this username.";
    } else {
        ( $result, $msg ) =
          _sanitize_and_register( $mac, $pid,
            %info );
    }
    return ( $result, $msg );
}

sub _sanitize_and_register {
    my (  $mac, $pid, %info ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ( $result, $msg );
    if ( valid_mac($mac) ) {
        $info{'auto_registered'} = 1;
        $logger->info("performing node registration MAC: $mac pid: $pid");
        node_register( $mac, $pid, %info );
        reevaluate_access( $mac, 'manage_register' );
        $result = $TRUE;
        $msg    = "The MAC address %s has been successfully registered.";
    } else {
        $msg = "The MAC address %s provided is invalid please try again";
    }
    $msg = i18n_format( $msg, $mac );
    return ( $result, $msg );
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
