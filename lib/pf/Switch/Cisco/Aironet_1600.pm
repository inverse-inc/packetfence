package pf::Switch::Cisco::Aironet_1600;

=head1 NAME

pf::Switch::Cisco::Aironet_1600 - Object oriented module to access SNMP enabled Cisco Aironet 1600 APs

=head1 SYNOPSIS

The pf::Switch::Cisco::Aironet_1600 module implements an object oriented interface
to access SNMP enabled Cisco Aironet_1600 APs.

This modules extends pf::Switch::Cisco::Aironet

=cut

use strict;
use warnings;
use Net::SNMP;
use Try::Tiny;

use pf::constants qw($TRUE);
use pf::config qw(
    $MAC
    $SSID
);
use pf::Switch::constants;
use pf::util qw(format_mac_as_cisco);
use pf::util::radius qw(perform_coa);

use base ('pf::Switch::Cisco::Aironet');

sub description { 'Cisco Aironet 1600' }

=head2 deauthTechniques

Specifices the type of deauth

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => 'deauthenticateMacRadius',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=head2 deauthenticateMacRadius

Method to deauth a wired node with CoA.

=cut

sub deauthenticateMacRadius {
    my ($self, $mac) = @_;
    my $logger = $self->logger;
    $mac = format_mac_as_cisco($mac);

    # perform CoA
    $self->radiusDisconnect($mac);
}

=head2 radiusDisconnect

Send a CoA to disconnect a mac

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

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
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
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = perform_coa($connection_info, $attributes_ref, [{ 'vendor' => 'Cisco', 'attribute' => 'Cisco-AVPair', 'value' => 'subscriber:command=reauthenticate' }]);

    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): $_");
        $logger->error("Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.")...") if ($_ =~ /^Timeout/);
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

1;
