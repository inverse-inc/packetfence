package pf::Switch::Pica8;

=head1 NAME

pf::Switch::Pica8

=head1 SYNOPSIS

Implements switch module to manage white box switches on which PICOS NOS can be installed.
The module supports RADIUS MAB + 802.1x for wired networks.

=head1 STATUS

Developed and tested on HPE AL 6900 running PICOS release 2.11.16 or later.

=over

=item Supports

This module only supports Wired Networks.
The Port Bounce feature is only supported for WIRED_802_1X; it is not supported for WIRED_MAC_AUTH connection type.

=over

=item Reauthentication and port bounce with RADIUS Change of Authorization (CoA) (RFC3576)

=back

=back

=head1 BUGS AND LIMITATIONS

Port bounce only works with WIRED_802_1X, SNMP is not yet supported. Port security is also not currently supported.

=over

Works only with PICOS release 2.11.16 or later.

=back

=cut

use strict;
use warnings;

use base ('pf::Switch');
use pf::log;
use Try::Tiny;
use pf::Switch::constants;
use pf::util;
use pf::util::radius qw(perform_coa);
use pf::web::util;
use pf::radius::constants;
use pf::constants;
use pf::config;
use pf::locationlog;
use pf::config qw(
    $ROLE_API_LEVEL
    $MAC
    $PORT
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);
use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);

=head1 SUBROUTINES

=over

=cut

# Description
sub description { return "Pica8" }

# CAPABILITIES
# access technology supported
sub supportsWiredDot1x { return $TRUE; }
sub supportsWiredMacAuth { return $TRUE; }
sub supportsRadiusDynamicVlanAssignment { return $TRUE; }
sub supportsRoleBasedEnforcement { return $TRUE; }

=item setAdminStatus - bounce host port with radius CoA technique

=cut

sub setAdminStatus {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    #We need to fetch the MAC on the ifIndex in order to bounce host port with CoA, only MAC works with CoA!
    my @locationlog = locationlog_view_open_switchport_no_VoIP( $self->{_ip}, $ifIndex );
    my $mac = $locationlog[0]->{'mac'};

    #Port bounce with CoA is not supported for WIRED_MAC_AUTH connection type.
    if ($locationlog[0]->{'connection_type'} eq 'WIRED_MAC_AUTH') {
    $logger->info("Port bounce for this connection type is not supported");
        return 1;
    }

    if ( !$self->isProductionMode() ) {
        $logger->info("Switch not in production mode... we won't perform port bounce");
        return 1;
    }

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on $self->{'_id'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("boucing MAC $mac using RADIUS CoA-Request method");

    # translating to expected format 00-11-22-33-CA-FE
    $mac = uc($mac);
    $mac =~ s/:/-/g;

    my $response;
    my $send_disconnect_to = $self->{'_controllerIp'} || $self->{'_ip'};
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
        };

        $response = perform_coa( $connection_info,
            {
                'Acct-Terminate-Cause' => 'Admin-Reset',
                'NAS-IP-Address' => $self->{'_switchIp'},
                'Calling-Station-Id' => $mac,
            },
            [{ 'vendor' => 'Pica8', 'attribute' => 'Pica8-AVPair', 'value' => 'subscriber:command=bounce-host-port' }],
        );
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

    $logger->warn(
        "Unable to perform RADIUS CoA-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=item bouncePort

Performs a shut / no-shut on the port.
Usually used to force the operating system to do a new DHCP Request after a VLAN change.

=cut

sub bouncePort {
    my ($self, $ifIndex) = @_;

    $self->setAdminStatus( $ifIndex );

    return $TRUE;
}

=head2 deauthenticateMacRadius

Method to deauth a wired node with CoA.

=cut

sub deauthenticateMacRadius {
    my ($self, $ifIndex,$mac) = @_;
    my $logger = $self->logger;

    # perform CoA
    $self->radiusDisconnect($mac ,{ 'Acct-Terminate-Cause' => 'Admin-Reset'});
}

=head2 radiusDisconnect

Send a CoA to disconnect a MAC

=cut

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger;

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating");

    my $send_disconnect_to = $self->{'_ip'};
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
        };

        $logger->debug("network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        # Standard Attributes

        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };
        $response = perform_coa($connection_info, $attributes_ref,
            [{'vendor' => 'Pica8', 'attribute' => 'Pica8-AVPair', 'value' => 'subscriber:command=reauthenticate'},
             {'vendor' => 'Pica8', 'attribute' => 'Pica8-AVPair', 'value' => 'subscriber:reauthenticate-type=last'}
            ]);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request on (".$self->{'_id'}.") : $_");
        $logger->error("Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.") ...")
            if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ( ($response->{'Code'} eq 'Disconnect-ACK') || ($response->{'Code'} eq 'CoA-ACK') );

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request on (".$self->{'_id'}.")."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
}

=head1 AUTHOR

Amjad Ali <ali.amjad@pica8.com>

=head1 COPYRIGHT

Copyright (C) 2009-2018 Pica8, Inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
