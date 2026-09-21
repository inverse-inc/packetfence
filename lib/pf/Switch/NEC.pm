package pf::Switch::NEC;

=head1 NAME

pf::Switch::NEC - Object oriented module to access and configure NEC QX-S series switches

=head1 SYNOPSIS

NEC QX-S series switches run a Comware 7 based firmware, so this module builds
on L<pf::Switch::H3C::Comware_v7> and adds the RADIUS authorization features of
Comware 7: role (Filter-Id) assignment, dynamic ACLs through the H3C-Av-Pair
attribute, voice VLAN tagging, RADIUS CLI login and NAS-Port-Id parsing.

=head1 STATUS

=over

=item Hardware

Developed and tested on a QX-S4148GT-4G-PW running Comware Software version 7.2.8.

=item Supports

=over

=item MAC Authentication

=item 802.1X

=item RADIUS dynamic VLAN assignment

=item Role assignment (Filter-Id: ACL number, ACL name or user profile pre-configured on the switch)

=item Dynamic ACLs (H3C-Av-Pair C<ip:inacl#N=rule>)

=item Voice over IP (voice VLAN + C<device-traffic-class=voice>)

=item RADIUS Disconnect (dynamic-author server)

=item RADIUS CLI login (network-admin / network-operator user roles)

=back

=back

=cut

use strict;
use warnings;

use base ('pf::Switch::H3C::Comware_v7');

use pf::constants;
use pf::constants::role qw($VOICE_ROLE);
use pf::config qw(
    $MAC
    $PORT
    $WIRED_802_1X
    $WIRED_MAC_AUTH
    %ConfigRoles
);
use pf::radius::constants;
use pf::Switch::constants;
use pf::util;
use pf::access_filter::radius;

=head1 SUPPORTED TECHNOLOGIES

=cut

use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    RadiusDynamicVlanAssignment
    RadiusVoip
    RoleBasedEnforcement
    AccessListBasedEnforcement
    Flow
);

# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

=head1 CONSTANTS

=over

=item $AV_PAIR_ATTRIBUTE

RADIUS attribute carrying Comware "attribute=value" pairs (vendor 25506, attribute 210).

=item $USER_ROLE_ATTRIBUTE

RADIUS attribute carrying the Comware CLI user roles (vendor 25506, attribute 155).

=back

=cut

our $AV_PAIR_ATTRIBUTE   = 'H3C-Av-Pair';
our $USER_ROLE_ATTRIBUTE = 'H3C-User-Role';

=head1 SUBROUTINES

=over

=item returnRoleAttribute

Comware 7 parses the standard Filter-Id attribute as an authorization ACL number,
an ACL name or a user profile name that must already exist on the switch.

=cut

sub returnRoleAttribute {
    my ($self) = @_;
    return 'Filter-Id';
}

=item returnInAccessListAttribute

Comware 7 accepts inbound dynamic ACL rules through the H3C-Av-Pair attribute
using the C<ip:inacl#E<lt>NE<gt>=E<lt>ruleE<gt>> syntax (Cisco IOS style rules).

=cut

sub returnInAccessListAttribute {
    my ($self) = @_;
    return 'ip:inacl#';
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept response for the network device.

Overrides the default implementation to add the dynamic ACLs as H3C-Av-Pair attributes.

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    $args->{'unfiltered'} = $TRUE;
    $args->{'compute_acl'} = $FALSE;
    $self->compute_action(\$args);
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if($status == $RADIUS::RLM_MODULE_USERLOCK);

    my @av_pairs = ();
    if (defined($radius_reply_ref->{$AV_PAIR_ATTRIBUTE})) {
        my $existing = $radius_reply_ref->{$AV_PAIR_ATTRIBUTE};
        @av_pairs = ref($existing) eq 'ARRAY' ? @$existing : ($existing);
    }

    if ( isenabled($self->{_AccessListMap}) && $self->supportsAccessListBasedEnforcement ){
        if( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && !($self->usePushACLs && exists $ConfigRoles{$args->{'user_role'}} ) && defined(my $access_list = $self->getAccessListByName($args->{'user_role'}, $args->{mac}, $args->{ifIndex}))){
            if ($access_list) {
                my $acl_num = 1;
                while($access_list =~ /([^\n]+)\n?/g){
                    my $acl = $1;
                    if ($acl !~ /^((in|out)\|)?(permit|deny)/i) {
                        next;
                    }
                    my ($test, $formated_acl) = $self->returnAccessListAttribute($acl_num, $acl);
                    if (!$test) {
                        $logger->debug("(".$self->{'_id'}.") Skipping unsupported access list entry : $acl");
                        next;
                    }
                    push(@av_pairs, $formated_acl);
                    $acl_num++;
                    $logger->info("(".$self->{'_id'}.") Adding access list : $formated_acl to the RADIUS reply");
                }
                $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
            } else {
                $logger->info("(".$self->{'_id'}.") No access lists defined for this role ".$args->{'user_role'});
            }
        }
    }

    if (@av_pairs) {
        $radius_reply_ref->{$AV_PAIR_ATTRIBUTE} = \@av_pairs;
    }

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=item getVoipVsa

Returns the RADIUS attributes for VoIP phones: the voice VLAN plus the Comware
C<device-traffic-class=voice> pair so the switch treats the session as a voice user
and tags the assigned VLAN as the voice VLAN on the port.

=cut

sub getVoipVsa {
    my ($self) = @_;
    return (
        'Tunnel-Type'             => $RADIUS::VLAN,
        'Tunnel-Medium-Type'      => $RADIUS::ETHERNET,
        'Tunnel-Private-Group-ID' => $self->getVlanByName($VOICE_ROLE) . "",
        $AV_PAIR_ATTRIBUTE        => 'device-traffic-class=voice',
    );
}

=item getIfIndexByNasPortId

Comware 7 sends a NAS-Port-Id formatted as C<slot=1;subslot=0;port=1;vlanid=1>.
The port is translated into an ifIndex through the BRIDGE-MIB when SNMP is
available; on a standalone switch (slot 1) the ifIndex matches the port number
so it is used directly when SNMP is unavailable.

=cut

sub getIfIndexByNasPortId {
    my ($self, $nas_port_id) = @_;
    my $logger = $self->logger;

    return $FALSE unless (defined($nas_port_id) && $nas_port_id =~ /slot=(\d+);subslot=(\d+);port=(\d+)/i);
    my ($slot, $subslot, $port) = ($1, $2, $3);

    my $dot1d_port = $port + $THREECOM::IFINDEX_OFFSET_PER_SLOT * ($slot - 1);
    my $ifIndex = $self->getIfIndexForThisDot1dBasePort($dot1d_port);
    return $ifIndex if (defined($ifIndex) && $ifIndex =~ /^\d+$/ && $ifIndex > 0);

    if ($slot == 1) {
        $logger->debug("(".$self->{'_id'}.") SNMP unavailable, using port $port from NAS-Port-Id '$nas_port_id' as ifIndex");
        return $port;
    }

    $logger->warn("(".$self->{'_id'}.") Unable to translate NAS-Port-Id '$nas_port_id' into an ifIndex");
    return $FALSE;
}

=item wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.
Comware 7 supports RFC 3576 Disconnect-Request through its dynamic-author server.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X || $connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacDefault',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    $logger->error("This authentication mode is not supported");
    return;
}

=item returnAuthorizeWrite

Return RADIUS attributes granting the C<network-admin> user role for CLI access.

=cut

sub returnAuthorizeWrite {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{$USER_ROLE_ATTRIBUTE} = 'shell:roles="network-admin"';
    $radius_reply_ref->{'Reply-Message'} = "Switch enable access granted by PacketFence";
    $radius_reply_ref->{'Reply-Message'} = $args->{'message'}." . ".$radius_reply_ref->{'Reply-Message'} if exists $args->{'message'};
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with write access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeWrite', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=item returnAuthorizeRead

Return RADIUS attributes granting the C<network-operator> user role for CLI access.

=cut

sub returnAuthorizeRead {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{$USER_ROLE_ATTRIBUTE} = 'shell:roles="network-operator"';
    $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
    $radius_reply_ref->{'Reply-Message'} = $args->{'message'}." . ".$radius_reply_ref->{'Reply-Message'} if exists $args->{'message'};
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeRead', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
