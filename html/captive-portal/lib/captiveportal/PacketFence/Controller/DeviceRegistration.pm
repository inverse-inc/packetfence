package captiveportal::PacketFence::Controller::DeviceRegistration;;
use Moose;
use namespace::autoclean;
use pf::Authentication::constants;
use pf::config qw(%ConfigSelfService);
use pf::constants;
use pf::log;
use pf::node;
use pf::util;
use pf::error qw(is_success);
use pf::web;
use pf::enforcement qw(reevaluate_access);
use fingerbank::DB_Factory;
use pf::constants::realm;
use POSIX;

BEGIN { extends 'captiveportal::Base::Controller'; }

__PACKAGE__->config( namespace => 'device-registration' );

=head1 NAME

captiveportal::PacketFence::Controller::DeviceRegistration - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub auto : Private {
    my ( $self, $c ) = @_;
    $c->stash->{isDeviceRegEnable} = $self->isDeviceRegEnabled($c);
    unless($c->stash->{isDeviceRegEnable}) {
        $self->showError($c,"Device registration module is not enabled" );
        $c->detach;
    }
    return $TRUE;
}

=head2 isDeviceRegEnabled

Checks whether or not a device registration policy is enabled on the current connection profile

=cut

sub isDeviceRegEnabled {
    my ($self, $c) = @_;
    if ($c->profile->{'_self_service'}) {
        return $TRUE
    } else {
        return $FALSE;
    }
}

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $logger  = $c->log;
    my $pid     = $c->user_session->{"username"};
    my $request = $c->request;

    # See if user is trying to login and if is not already authenticated
    if ( ( !$pid ) ) {
        # Verify if user is authenticated
        $c->forward('userNotLoggedIn');
    } elsif ( $request->param('cancel') ) {
        $c->user_session({});
        $c->response->redirect('/status');
    }
    if ( $request->method eq 'POST' && $request->param('device_mac') ) {
        # User is authenticated and requesting to register a device
        my $device_mac = clean_mac($request->param('device_mac'));
        my $device_type;
        $device_type = $request->param('console_type') if ( defined($request->param('console_type')) );

        if(valid_mac($device_mac)) {
            # Register device
            $c->forward('registerNode', [ $pid, $device_mac, $device_type ]);
        }
        $c->stash(txt_auth_error => "Please verify the provided MAC address.");
    }
    # User is authenticated so display registration page
    $c->stash(title => "Registration", template => 'device-registration/registration.html');
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

=cut

sub userNotLoggedIn : Private {
    my ($self, $c) = @_;
    $c->response->redirect('/status/login');
}

sub landing : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( title => "Device registration landing", template => 'device-registration/registration.html' );
}

sub registerNode : Private {
    my ( $self, $c, $pid, $mac, $type ) = @_;
    my $logger = $c->log;
    my $device_reg_profile = $c->profile->{'_self_service'};
    if ( is_allowed($mac, $device_reg_profile) && valid_mac($mac) ) {
        my ($node) = node_view($mac);
        if( $node && $node->{status} ne $pf::node::STATUS_UNREGISTERED ) {
            $c->stash( status_msg_error => ["%s is already registered or pending to be registered. Please verify MAC address if correct contact your network administrator", $mac]);
            $c->detach('Controller::Status', 'index');
        } else {
            my $session = $c->user_session;
            my $source_id = $session->{source_id};
            my %info;
            my $params = { username => $pid, 'context' => $pf::constants::realm::PORTAL_CONTEXT};
            $c->stash->{device_mac} = $mac;
            # Get role for device registration
            my $role =
              $ConfigSelfService{$device_reg_profile}{'device_registration_role'};
            if ($role) {
                $logger->debug("Device registration role is $role (from pf.conf)");
            } else {
                # Use role of user
                $role = pf::authentication::match( $source_id, $params , $Actions::SET_ROLE, undef, $c->user_session->{extra});
                $logger->debug("Gaming devices role is $role (from username $pid)");
            }

            my $duration = $ConfigSelfService{$device_reg_profile}{'device_registration_access_duration'};
            if($duration > 0) {
                $info{unregdate} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $duration));
                $logger->debug("Got unregdate $info{unregdate} for username $pid through the self-service configuration");
            }
            else {
                my $unregdate = pf::authentication::match( $source_id, $params, $Actions::SET_UNREG_DATE, undef, $c->user_session->{extra});
                if ( defined $unregdate ) {
                    $logger->debug("Got unregdate $unregdate for username $pid");
                    $info{unregdate} = $unregdate;
                }
            }
            my $time_balance = &pf::authentication::match( $source_id, $params, $Actions::SET_TIME_BALANCE);
            if ( defined $time_balance ) {
                $logger->debug("Got time balance $time_balance for username $pid");
                $info{time_balance} = pf::util::normalize_time($time_balance);
            }
            my $bandwidth_balance = &pf::authentication::match( $source_id, $params, $Actions::SET_BANDWIDTH_BALANCE);

            if ( defined $bandwidth_balance ) {
                $logger->debug("Got bandwidth balance $bandwidth_balance for username $pid");
                $info{bandwidth_balance} = pf::util::unpretty_bandwidth($bandwidth_balance);
            }
            $info{'category'} = $role if ( defined $role );
            $info{'auto_registered'} = 1;
            $info{'mac'} = $mac;
            $info{'pid'} = $pid;
            $info{'regdate'} = mysql_date();
            $info{'notes'} = $type if ( defined($type) );
            $c->portalSession->guestNodeMac($mac);
            node_modify($mac, status => "reg", %info);
            reevaluate_access($mac, 'manage_register');
            $c->stash( status_msg  => [ "The MAC address %s has been successfully registered.", $mac ]);
            $c->detach('Controller::Status', 'index');
        }
    } else {
        $c->stash( status_msg_error => [ "The provided MAC address %s is not allowed to be registered using this self-service page.", $mac ]);
        $c->detach('landing');
    }
}

=item device_from_mac_vendor

Get the matching device infos by mac vendor from Fingerbank

=cut

sub device_from_mac_vendor {
    my ($mac_vendor) = @_; 
    my $logger = get_logger();

    my ($status, $device_id) = fingerbank::API->new_from_config->device_id_from_oui($mac_vendor);

    if(is_success($status)) {
        return $device_id;
    } 
    else {
        return undef;
    }
}

=item is_allowed 

Verify 

=cut 

sub is_allowed {
    my ($mac, $device_reg_profile) = @_;
    $mac =~ s/O/0/i;
    my $logger = get_logger();
    my $oses = $ConfigSelfService{$device_reg_profile}{'device_registration_allowed_devices'};

    # If no oses are defined then it will allow every devices to be registered
    return $TRUE if @$oses == 0;

    # Verify if the device is existing in the table node and if it's device_type is allowed
    my $node = node_view($mac);
    my $device_type = $node->{device_type};
    for my $id (@$oses) {
        my $endpoint = fingerbank::Model::Endpoint->new(name => $device_type, version => undef, score => undef);
        if ( defined($device_type) && $endpoint->is_a_by_id($id)) {
            $logger->debug("The devices type ".$device_type." is authorized to be registered via the device-registration module");
            return $TRUE;
        }
    }

    $mac =~ s/://g;
    my $mac_vendor = substr($mac, 0,6);
    my $device_id = device_from_mac_vendor($mac_vendor);
    my ($status, $result) = fingerbank::Model::Device->find([{ id => $device_id}, {columns => ['name']}]);

    # We are loading the fingerbank endpoint model to verify if the device id is matching as a parent or child
    if (is_success($status)){
        my $device_name = $result->name;
        my $endpoint = fingerbank::Model::Endpoint->new(name => $device_name, version => undef, score => undef);

        for my $id (@$oses) {
            if ($endpoint->is_a_by_id($id)) {
                $logger->debug("The devices type ".$device_name." is authorized to be registered via the device-registration module");
                return $TRUE;
            }
        }
    }
    $logger->debug("Cannot find a matching device name for this device id ".$device_id." .");
    return $FALSE;
}

=head2 logout

allow user to logout

=cut

sub logout : Local {
    my ( $self, $c ) = @_;
    $c->user_session({});
    $c->forward('index');
}
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
