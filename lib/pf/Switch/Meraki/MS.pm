package pf::Switch::Meraki::MS;

=head1 NAME

pf::Switch::Meraki::MS

=head1 SYNOPSIS

The pf::Switch::Meraki::MS module implements an object oriented interface to
manage the connection with MS series switch model.

=head1 STATUS

Developed and tested on a MS220_8P (P standing for PoE) switch

=head1 BUGS AND LIMITATIONS

=head2 VoIP devices detection

VoIP devices are detected through the CDP neighbors of the port (SNMP, CISCO-CDP-MIB),
which requires SNMP to be enabled for the network in the Meraki dashboard and the
SNMP read parameters on the switch. LLDP is not queried.

=cut

use strict;
use warnings;

use base ('pf::Switch::Meraki');

use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);
use pf::constants;
use pf::util;
use pf::node;
use pf::Switch::Meraki::MR_v2;
use pf::access_filter::radius;
use pf::radius::constants;

# The switch lists a CDP neighbor in its cdpCacheTable 3 to 7 minutes after the
# port comes up. A device that is not a phone is authenticated again every
# CDP_RECHECK_TIMEOUT seconds during the first CDP_RECHECK_WINDOW seconds after it
# was first seen on the switch, which is remembered CDP_RECHECK_MEMORY.
use constant CDP_RECHECK_TIMEOUT => 300;
use constant CDP_RECHECK_WINDOW => 900;
use constant CDP_RECHECK_MEMORY => '48h';

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
sub description { 'Meraki switch MS' }
sub switchDriverId { 'meraki' }
use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    RadiusVoip
    RoleBasedEnforcement
    Flow
    Cdp
);

sub isVoIPEnabled {
    my ($self) = @_;
    return isenabled($self->{_VoIPEnabled});
}

=head2 getPhonesCDPAtIfIndex

MS switches expose the CDP neighbors in the CISCO-CDP-MIB cdpCacheTable
(indexed by the port number, ifDescr "Port N"), the same way Cisco switches do.
SNMP has to be enabled for the network in the Meraki dashboard and the SNMP read
parameters have to be set on the switch.

=cut

sub getPhonesCDPAtIfIndex {
    require pf::Switch::Cisco;
    goto &pf::Switch::Cisco::getPhonesCDPAtIfIndex;
}

=head2 isPhoneAtIfIndex

Only a found phone is cached. The switch lists a CDP neighbor in its
cdpCacheTable minutes after the port comes up, so the first RADIUS request of
a phone usually comes before it: caching that miss would hide the phone until
the cache expires.

=cut

sub isPhoneAtIfIndex {
    my ($self, $mac, $ifIndex) = @_;
    my $is_phone = $self->SUPER::isPhoneAtIfIndex($mac, $ifIndex);
    if (!$is_phone && defined($ifIndex)) {
        $self->cache_distributed->remove($self->{_id} . "-SNMP-isPhoneAtIfIndex-$ifIndex-$mac");
    }
    return $is_phone;
}

=head2 returnRadiusAccessAccept

When a device that was just seen on the switch is not detected as a phone, ask
the switch to authenticate it again in CDP_RECHECK_TIMEOUT seconds without
bringing the port down (Session-Timeout with Termination-Action
RADIUS-Request), when the CDP entry of a phone is in the cdpCacheTable. A
device that is still not a phone then gets the regular answer.

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;

    # the RADIUS filter runs once, at the end, over the complete reply
    my $unfiltered = $args->{'unfiltered'};
    $args->{'unfiltered'} = $TRUE;
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    $args->{'unfiltered'} = $unfiltered;
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    return [$status, %radius_reply] if ($status == $RADIUS::RLM_MODULE_USERLOCK);

    if (!exists($radius_reply{'Session-Timeout'}) && $self->_cdpRecheck($args)) {
        $self->logger->info("$args->{'mac'} is not a phone according to CDP yet, asking the switch to authenticate it again in " . CDP_RECHECK_TIMEOUT . " seconds");
        $radius_reply{'Session-Timeout'} = CDP_RECHECK_TIMEOUT;
        $radius_reply{'Termination-Action'} = 1; # RADIUS-Request
    }

    return [$status, %radius_reply] if isenabled($args->{'unfiltered'});
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    my ($radius_reply_ref, $filtered_status) = $filter->handleAnswerInRule($rule, $args, \%radius_reply);
    return [$filtered_status, %$radius_reply_ref];
}

=head2 _cdpRecheck

Whether the device should be authenticated again to look for it in the CDP
neighbors, when the CDP lookup can run.

Every answer during the first CDP_RECHECK_WINDOW seconds after the device was
first seen on the switch asks for it, so the device is checked every
CDP_RECHECK_TIMEOUT seconds until its CDP entry shows up, also when a phone
reboots or its link flaps right after it connects. After the window, a device
that is still not a phone gets the regular answer. The first time a device was
seen is kept CDP_RECHECK_MEMORY.

=cut

sub _cdpRecheck {
    my ($self, $args) = @_;
    return $FALSE if $args->{'isPhone'};
    return $FALSE if !$self->isVoIPEnabled();
    return $FALSE if defined($self->{_VoIPCDPDetect}) && !isenabled($self->{_VoIPCDPDetect});
    return $FALSE if !defined($args->{'mac'}) || !defined($args->{'ifIndex'}) || $args->{'ifIndex'} eq '';
    my $key = $self->{_id} . "-CDP-recheck-" . $args->{'mac'};
    my $cache = $self->cache_distributed;
    my $now = time();
    my $first_seen = $cache->get($key);
    if (!defined($first_seen)) {
        $cache->set($key, $now, CDP_RECHECK_MEMORY);
        return $TRUE;
    }
    return ($now - $first_seen) < CDP_RECHECK_WINDOW;
}

=head2 getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($self) = @_;
    my $logger = $self->logger;

    return ('Cisco-AVPair' => "device-traffic-class=voice");
}

=head2 getVersion 

obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->info("we don't know how to determine the version through SNMP !");
    return '1';
}

=head2 parseRequest

Redefinition of pf::Switch::parseRequest due to specific attribute being used by Meraki

=cut

sub parseRequest {
    my ( $self, $radius_request ) = @_;
    my $client_mac      = ref($radius_request->{'Calling-Station-Id'}) eq 'ARRAY'
                           ? clean_mac($radius_request->{'Calling-Station-Id'}[0])
                           : clean_mac($radius_request->{'Calling-Station-Id'});
    my $user_name       = $self->parseRequestUsername($radius_request);
    my $nas_port_type   = $radius_request->{'NAS-Port-Type'};
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );
    my $session_id      = $self->getCiscoAvPairAttribute($radius_request, "audit-session-id");
    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, $session_id, $nas_port_id);
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
    elsif ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );
        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    else{
        $logger->error("This authentication mode is not supported");
    }

}

=head2 deauthenticateMacRadius

Method to deauth a wired node with RADIUS Disconnect.

=cut

sub deauthenticateMacRadius {
    my ($self, $ifIndex,$mac) = @_;
    my $logger = $self->logger;

    $self->radiusDisconnect($mac );
}

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger;
    # Use the same disconnect method as the Meraki MR v2
    pf::Switch::Meraki::MR_v2::radiusDisconnect(@_);
}

=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Filter-Id';
}

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
