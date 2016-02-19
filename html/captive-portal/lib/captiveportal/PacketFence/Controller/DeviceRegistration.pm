package captiveportal::PacketFence::Controller::DeviceRegistration;;
use Moose;
use namespace::autoclean;
use pf::Authentication::constants;
use pf::config;
use pf::log;
use pf::node;
use pf::util;
use pf::web;
use pf::web::device_registration;

BEGIN { extends 'captiveportal::Base::Controller'; }

__PACKAGE__->config( namespace => 'device-registration' );

=head1 NAME

captiveportal::PacketFence::Controller::DeviceRegistration - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub begin : Private {
    my ( $self, $c ) = @_;
    if (isdisabled( $Config{'registration'}{'device_registration'} ) )
    {
        $self->showError($c,"Device registration module is not enabled" );
        $c->detach;
    }
    $c->stash->{console_types} = \@pf::web::device_registration::DEVICE_TYPES;
}

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $logger  = $c->log();
    my $pid     = $c->session->{"username"};
    my $request = $c->request;

    # See if user is trying to login and if is not already authenticated
    if ( ( !$pid ) ) {
        # Verify if user is authenticated
        $c->forward('userNotLoggedIn');
    } elsif ( $request->param('cancel') ) {
        $c->delete_session;
        $c->detach('login');
    } elsif ( $request->param('device_mac') ) {
        # User is authenticated and requesting to register a device
        my $device_mac = clean_mac($request->param('device_mac'));
        my $device_type;
        $device_type = $request->param('console_type') if ( defined($request->param('console_type')) );
        if(valid_mac($device_mac)) {
            # Register device
            $c->forward('registerNode', [ $pid, $device_mac, $device_type ]);
            unless ($c->has_errors) {
                $c->stash(status_msg  => i18n_format("The MAC address %s has been successfully registered.", $device_mac));
                $c->detach('landing');
            }
        } else {
            $c->stash(txt_auth_error => i18n_format("Please verify the provided MAC address."));
        }
    }
    # User is authenticated so display registration page
    $c->stash(template => 'device-registration/registration.html');
}

=head2 gaming_registration

Backwards compatability

/gaming-registration

=cut

sub gaming_registration: Path('/gaming-registration') {
    my ( $self, $c ) = @_;
    $c->forward('index');
}


=head2 userNotLoggedIn

TODO: documention

=cut

sub userNotLoggedIn : Private {
    my ($self, $c) = @_;
    my $request = $c->request;
    my $username = $request->param('username');
    my $password = $request->param('password');
    if ( all_defined( $username, $password ) ) {
        $c->forward(Authenticate => 'authenticationLogin');
        if ($c->has_errors) {
            $c->detach('login');
        }
    } else {
        $c->detach('login');
    }
}

=head2 login

Display the device registration login

=cut

sub login : Local : Args(0) {
    my ( $self, $c ) = @_;
    if ( $c->has_errors ) {
        $c->stash->{txt_auth_error} = join(' ', grep { ref ($_) eq '' } @{$c->error});
        $c->clear_errors;
    }
    $c->stash( template => 'device-registration/login.html' );
}

sub landing : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'device-registration/landing.html' );
}

sub registerNode : Private {
    my ( $self, $c, $pid, $mac, $type ) = @_;
    my $logger = $c->log;
    if ( pf::web::device_registration::is_allowed($mac) ) {
        my ($node) = node_view($mac);
        if( $node && $node->{status} ne $pf::node::STATUS_UNREGISTERED ) {
            $self->showError($c,"$mac is already registered or pending to be registered. Please verify MAC address if correct contact your network administrator");
        } else {
            my $session = $c->session;
            my $source_id = $session->{source_id};
            my %info;
            my $params = { username => $pid };
            $c->stash->{device_mac} = $mac;
            # Get role for device registration
            my $role =
              $Config{'registration'}{'device_registration_role'};
            if ($role) {
                $logger->debug("Device registration role is $role (from pf.conf)");
            } else {
                # Use role of user
                $role = &pf::authentication::match( $source_id, $params , $Actions::SET_ROLE);
                $logger->debug("Gaming devices role is $role (from username $pid)");
            }

            my $unregdate = &pf::authentication::match( $source_id, $params, $Actions::SET_UNREG_DATE);
            if ( defined $unregdate ) {
                $logger->debug("Got unregdate $unregdate for username $pid");
                $info{unregdate} = $unregdate;
            }
            $info{'category'} = $role if ( defined $role );
            $info{'auto_registered'} = 1;
            $info{'mac'} = $mac;
            $info{'notes'} = $type if ( defined($type) );
            $c->portalSession->guestNodeMac($mac);
            node_modify($mac, status => "reg", %info);
        }
    } else {
        $self->showError($c,"Please verify the provided MAC address.");
    }
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

__PACKAGE__->meta->make_immutable;

1;
