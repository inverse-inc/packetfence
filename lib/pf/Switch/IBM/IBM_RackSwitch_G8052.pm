package pf::Switch::IBM::IBM_RackSwitch_G8052;

=head1 NAME

pf::Switch::HP::RackSwitch_G8052 - Object oriented module to access and configure IBM RackSwitch G8052 switches

=head1 STATUS

=head1 SUPPORTS

=head2 802.1X without VoiP

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;
use Try::Tiny;

use base ('pf::Switch::IBM');
use pf::constants;
use pf::config;
use pf::Switch::constants;
use pf::util;
use pf::node qw(node_attributes);
use pf::util::radius qw(perform_disconnect);


sub description { 'IBM RackSwitch G8052' }

# CAPABILITIES
# access technology supported
sub supportsWiredDot1x { return $TRUE; }
sub supportsRadiusDynamicVlanAssignment { return $TRUE; }

=head1 SUBROUTINES

=head2 radiusDisconnect

Send a CoA to disconnect a mac

=cut

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "[$mac] Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("[$mac] deauthenticating");

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("[$mac] controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
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
            LocalAddr => $management_network->tag('vip'),
        };

        $logger->debug("[$mac] network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        my $node_info = node_attributes($mac);
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

        $response = perform_coa($connection_info, $attributes_ref, [{ 'vendor' => 'Cisco', 'attribute' => 'Cisco-AVPair', 'value' => 'subscriber:command=reauthenticate' }]);

    } catch {
        chomp;
        $logger->warn("[$mac] Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): $_");
        $logger->error("[$mac] Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.")...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

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
    my ($this, $method, $connection_type) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'dot1xPortReauthenticate',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'handleReAssignVlanTrapForWiredMacAuth',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
}

=head2 returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overrides the default implementation to add the dynamic acls

=cut

sub returnRadiusAccessAccept {
    my ($self, $vlan, $mac, $port, $connection_type, $user_name, $ssid, $wasInline, $user_role) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # Inline Vs. VLAN enforcement
    my $radius_reply_ref = {};
    my $role = "";
    if ( (!$wasInline || ($wasInline && $vlan != 0) ) && isenabled($self->{_VlanMap})) {
        $radius_reply_ref = {
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => $vlan,
        };
    }

    
    if ( isenabled($self->{_AccessListMap}) && $self->supportsAccessListBasedEnforcement ){
        if( defined($user_role) && $user_role ne ""){
            my $access_list = $self->getAccessListByName($user_role);
            my @av_pairs;
            while($access_list =~ /([^\n]+)\n?/g){
                push(@av_pairs, $self->returnAccessListAttribute."=".$1);
                $logger->info("[$mac] (".$self->{'_id'}.") Adding access list : $1 to the RADIUS reply");
            } 
            $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs; 
            $logger->info("[$mac] (".$self->{'_id'}.") Added access lists to the RADIUS reply.");
        }
    }
    if ( isenabled($self->{_RoleMap}) && $self->supportsRoleBasedEnforcement()) {
        $logger->debug("[$mac] (".$self->{'_id'}.") Network device supports roles. Evaluating role to be returned");
        if ( defined($user_role) && $user_role ne "" ) {
            $role = $self->getRoleByName($user_role);
        }
        if ( defined($role) && $role ne "" ) {
            $radius_reply_ref->{$self->returnRoleAttribute()} = $role;
            $logger->info(
                "[$mac] (".$self->{'_id'}.") Added role $role to the returned RADIUS Access-Accept under attribute " . $self->returnRoleAttribute()
            );
        }
        else {
            $logger->debug("[$mac] (".$self->{'_id'}.") Received undefined role. No Role added to RADIUS Access-Accept");
        }
    }

    $logger->info("[$mac] (".$self->{'_id'}.") Returning ACCEPT with VLAN $vlan and role $role");
    return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
}

=head2 _dot1xPortReauthenticate

=cut

sub _dot1xPortReauthenticate {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $logger->info("Trying to do IBM 802.1x port re-authentication.");

    my $oid_dot1xPaePortReauthenticate = "1.0.8802.1.1.1.1.1.2.1.5"; # from IEEE8021-PAE-MIB

    if (!$this->connectWrite()) {
        return 0;
    }

    $logger->trace("SNMP set_request force dot1xPaePortReauthenticate on ifIndex: $ifIndex");
    my $result = $this->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_dot1xPaePortReauthenticate.$ifIndex", Net::SNMP::INTEGER, 1
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force 802.1x re-authentication: ".$this->{_sessionWrite}->error);
    }

    return (defined($result));
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
