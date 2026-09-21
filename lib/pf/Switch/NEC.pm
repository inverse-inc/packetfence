package pf::Switch::NEC;

=head1 NAME

pf::Switch::NEC - Object oriented module to access and configure NEC QX-S series switches

=head1 SYNOPSIS

NEC QX-S series switches run a Comware 7 based firmware, so this module builds
on L<pf::Switch::H3C::Comware_v7> and adds the RADIUS authorization features of
Comware 7: role assignment, dynamic ACLs, voice VLAN tagging, RADIUS CLI login
and NAS-Port-Id parsing.

=head1 STATUS

=over

=item Hardware

Developed and tested on a QX-S4148GT-4G-PW running Comware Software version 7.2.8.

=item Supports

=over

=item MAC Authentication

=item 802.1X (including EAP-TLS)

=item RADIUS dynamic VLAN assignment

=item Dynamic ACL assignment (Filter-Id referencing a numbered ACL)

=item Voice over IP (voice VLAN + device-traffic-class=voice)

=item RADIUS Disconnect (dynamic-author server)

=item RADIUS CLI login (network-admin / network-operator user roles)

=back

=back

=head1 DYNAMIC ACLs

Comware 7 on the QX-S applies a per-session authorization ACL only when the
RADIUS reply references an ACL that already exists on the switch, through the
standard C<Filter-Id> attribute (an ACL number, an ACL name or a user profile).
It does B<not> honor inline ACL rules carried in the vendor C<H3C-Av-Pair>
attribute (C<ip:inacl#N=...>), which this firmware silently ignores.

Enforcement therefore goes through role-based enforcement: enable "Role by
Switch Role" and set the numbered ACL (for example C<3999>) as the switch role
for each PacketFence role. The ACL itself is pre-configured on the switch, or
provisioned to it out of band.

=cut

use strict;
use warnings;

use base ('pf::Switch::H3C::Comware_v7');

use pf::constants;
use pf::config qw(
    $MAC
    $PORT
    $WIRED_802_1X
    $WIRED_MAC_AUTH
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

=item getVoipVsa

Returns the RADIUS attribute that classifies the session as a voice user.
Comware then authorizes the phone in the port's configured voice VLAN as a
tagged VLAN; PacketFence does not assign the VLAN itself.

=cut

sub getVoipVsa {
    my ($self) = @_;
    # On Comware 7, device-traffic-class=voice alone classifies the session as a
    # voice user and authorizes it in the voice VLAN configured on the port
    # (voice-vlan <id> enable), applied as a TAGGED VLAN - which is how an IP
    # phone tags its own voice traffic. We deliberately do NOT return the Tunnel
    # (VLAN) attributes here: assigning the voice VLAN untagged would be wrong for
    # a phone, and the switch already knows its voice VLAN. Verified on a
    # QX-S4148GT-4G-PW: this yields "Authorization tagged VLAN: <voice vlan>".
    return (
        $AV_PAIR_ATTRIBUTE => 'device-traffic-class=voice',
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
