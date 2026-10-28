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
    %ConfigRoles
);
use pf::constants;
use pf::util;
use pf::node;
use NetAddr::IP;
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
# When the switch does not answer SNMP (SNMP is disabled in the Meraki dashboard
# by default), the CDP lookup is skipped for SNMP_UNREACHABLE_MEMORY instead of
# making every RADIUS request wait for the SNMP timeout.
use constant SNMP_UNREACHABLE_MEMORY => '10m';

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
    PushACLs
    Flow
    Cdp
);

# What a Layer 3 firewall rule of a group policy matches: the protocol of a
# role ACL and the one of the rule
use constant MERAKI_RULE_PROTOCOLS => { ip => 'any', tcp => 'tcp', udp => 'udp', icmp => 'icmp' };

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
    my ($self, $ifIndex) = @_;
    return () if !$self->isVoIPEnabled() || !$self->_cdpLookupAvailable();
    require pf::Switch::Cisco;
    my @phones = pf::Switch::Cisco::getPhonesCDPAtIfIndex($self, $ifIndex);
    # connectRead can succeed from its cached sysLocation while the switch no
    # longer answers (SNMP disabled since, wrong community): a CDP request that
    # timed out counts as well
    my $error = $self->{_sessionRead} ? $self->{_sessionRead}->error() : undef;
    $self->_snmpUnreachable($error) if !@phones && defined($error) && $error =~ /No response/i;
    return @phones;
}

=head2 _cdpLookupAvailable

Whether the switch answers SNMP. A switch that does not answer is not queried
again for SNMP_UNREACHABLE_MEMORY: the lookup runs during the RADIUS request,
and without this every request would wait for the SNMP timeout. A switch whose
"Use SNMP" is disabled is not queried, without a warning.

=cut

sub _cdpLookupAvailable {
    my ($self) = @_;
    return $FALSE if isdisabled($self->{_useSNMP});
    return $FALSE if $self->cache_distributed->get($self->{_id} . "-CDP-snmp-unreachable");
    return $TRUE if $self->connectRead();
    $self->_snmpUnreachable($self->{_error});
    return $FALSE;
}

=head2 _snmpUnreachable

Remember for SNMP_UNREACHABLE_MEMORY that the switch does not answer SNMP.

=cut

sub _snmpUnreachable {
    my ($self, $error) = @_;
    $self->logger->warn("$self->{_id} does not answer SNMP" . (defined($error) && $error ne '' ? " ($error)" : '') . ": VoIP phones are not looked up in its CDP neighbors for the next " . SNMP_UNREACHABLE_MEMORY . ". Enable SNMP for the network in the Meraki dashboard and set the SNMP read parameters of the switch, or disable the CDP detection of VoIP phones on the switch");
    $self->cache_distributed->set($self->{_id} . "-CDP-snmp-unreachable", 1, SNMP_UNREACHABLE_MEMORY);
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
    # authenticating again can't find a phone if the switch does not answer SNMP
    return $FALSE if !$self->_cdpLookupAvailable();
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

=head2 Group Policy ACLs (Push ACLs)

The switch applies to an authenticated client the group policy of the network
named by the Filter-Id of the Access-Accept, and the Layer 3 firewall rules of
that group policy filter the traffic the client sends. With Push ACLs,
PacketFence creates in the Meraki dashboard (through the Dashboard API, see
conf/pfsetacls/switch_acls.yml) a group policy named after each role that has
ACLs, holding the ACLs of the role as L3 firewall rules, updates it when the
ACLs change, and returns the name of the role in Filter-Id.

A rule matches the protocol (tcp, udp, icmp or any), the destination address
and the destination port only: the source is always the client. The role ACLs
follow the Cisco format, where what no line permits is denied, while the rules
of a group policy allow what no rule matches, so the pushed rules end with a
deny of everything unless the last ACL already matches everything.

=head2 returnRoleAttributes

The switch drops all the traffic of a client whose Filter-Id matches no group
policy of the network. With Push ACLs, a role without ACLs gets no group policy,
so no Filter-Id is returned for it: the client is unrestricted, as a role
without ACLs is.

=cut

sub returnRoleAttributes {
    my ($self, $role) = @_;
    if ($self->usePushACLs && defined($role) && exists $ConfigRoles{$role} && !defined($self->_getRoleAccessListByName($role))) {
        $self->logger->info("(".$self->{'_id'}.") Not returning Filter-Id for role $role: no group policy is pushed for a role without ACLs, and the switch drops the traffic of a client whose Filter-Id matches no group policy");
        return ();
    }
    return $self->SUPER::returnRoleAttributes($role);
}

=head2 pushAclsName

Only the in ACLs of a role are pushed: the rules of a group policy filter the
traffic the client sends.

=cut

sub pushAclsName {
    my ($self, $role, $direction) = @_;
    return $direction eq 'out' ? undef : $role;
}

=head2 acl_chewer

For the push (L<pf::Switch/getRoleAccessListByName>), the L3 firewall rules of
the group policy of the role, as a list of hashes with the fields of the
Dashboard API (comment, policy, protocol, destPort, destCidr). The ACLs this
format cannot express are handled by L<pf::Switch/filterUntranslatableAcls>:
a permit is skipped, a deny ends the rules with a deny of everything.

Outside of the push, the ACLs are returned as they are: the switch does not
take ACLs in the RADIUS reply.

=cut

sub acl_chewer {
    my ($self, $acl, $role) = @_;
    return $acl if !$self->aclsForPush;
    my $logger = $self->logger;

    my ($acl_ref, @direction) = $self->format_acl($acl);
    my $entries = $acl_ref->{'packetfence'}->{'entries'} // [];
    if (@$entries == @direction) {
        my (@in, @in_direction);
        my $out = 0;
        for my $i (0 .. $#direction) {
            if (($direction[$i] // 'in') eq 'out') {
                $out++;
                next;
            }
            push @in, $entries->[$i];
            push @in_direction, $direction[$i];
        }
        $logger->warn("(".$self->{'_id'}.") Skipping the out ACLs of role '$role' ($out): the rules of a group policy only filter the traffic the client sends") if $out;
        $acl_ref = { packetfence => { entries => \@in } };
        @direction = @in_direction;
    }
    ($entries) = $self->filterUntranslatableAcls($acl_ref, \@direction, $role, sub { $self->untranslatableMerakiAcl($_[0]) });

    my @rules = map { $self->merakiL3FirewallRule($_, $role) } @$entries;
    if (!@rules) {
        # no in ACL: the role does not restrict the traffic the client sends
        push @rules, { comment => "PacketFence role $role: no in ACL", policy => 'allow', protocol => 'any', destPort => 'any', destCidr => 'any' };
    }
    my $last = $rules[-1];
    if (!($last->{'protocol'} eq 'any' && $last->{'destCidr'} eq 'any' && $last->{'destPort'} eq 'any')) {
        push @rules, { comment => "PacketFence role $role: implicit deny", policy => 'deny', protocol => 'any', destPort => 'any', destCidr => 'any' };
    }
    return \@rules;
}

=head2 untranslatableMerakiAcl

Why a parsed ACL entry cannot be an L3 firewall rule of a group policy, or
undef when it can. A rule matches tcp, udp, icmp or any protocol, the
destination address (a prefix) and the destination port (one port or a range of
tcp or udp): not the source address or port, TCP flags, ICMP types, other
protocols, or the other port operators.

=cut

sub untranslatableMerakiAcl {
    my ($self, $entry) = @_;
    my $protocol = $self->_merakiProtocol($entry);
    return "a group policy rule matches tcp, udp, icmp or ip, not the protocol '".($entry->{'protocol'} // '')."'" if !defined $protocol;
    return "a group policy rule matches the destination only, not the source address" if ($entry->{'source'}->{'ipv4_addr'} // '0.0.0.0') ne '0.0.0.0';
    return "a group policy rule has no source port match" if defined $entry->{'source'}->{'port'};
    return "a group policy rule has no TCP flags match ('".$entry->{'tcp_flags'}."')" if defined $entry->{'tcp_flags'};
    return "a group policy rule has no ICMP type match ('".$entry->{'icmp_qualifier'}."')" if defined $entry->{'icmp_qualifier'};
    return "the destination mask '".$entry->{'destination'}->{'wildcard'}."' is not contiguous" if !$self->aclWildcardIsContiguous($entry->{'destination'}->{'wildcard'});
    my $port = $entry->{'destination'}->{'port'};
    if (defined $port) {
        my @ports = $port =~ /^eq\s+(\S+)$/ ? ($1) : $port =~ /^range\s+(\S+)\s+(\S+)$/ ? ($1, $2) : ();
        return "the port operator '$port' cannot be represented" if !@ports;
        foreach my $p (@ports) {
            return "the port '$p' has no number" if !defined $self->_merakiPortNumber($p, $protocol);
        }
    }
    return undef;
}

=head2 merakiL3FirewallRule

The L3 firewall rule of a parsed ACL entry L</untranslatableMerakiAcl> accepts.

=cut

sub merakiL3FirewallRule {
    my ($self, $entry, $role) = @_;
    my $protocol = $self->_merakiProtocol($entry);
    my $destination = $entry->{'destination'};
    my $cidr = 'any';
    if (($destination->{'ipv4_addr'} // '0.0.0.0') ne '0.0.0.0') {
        if (($destination->{'wildcard'} // '0.0.0.0') eq '0.0.0.0') {
            $cidr = $destination->{'ipv4_addr'} . '/32';
        } else {
            $cidr = NetAddr::IP->new($destination->{'ipv4_addr'}, norm_net_mask($destination->{'wildcard'}))->network->cidr;
        }
    }
    my $port = 'any';
    if (defined $destination->{'port'}) {
        if ($destination->{'port'} =~ /^eq\s+(\S+)$/) {
            $port = $self->_merakiPortNumber($1, $protocol);
        } elsif ($destination->{'port'} =~ /^range\s+(\S+)\s+(\S+)$/) {
            $port = $self->_merakiPortNumber($1, $protocol) . '-' . $self->_merakiPortNumber($2, $protocol);
        }
    }
    (my $acl_protocol = $entry->{'protocol'} // 'ip') =~ s/\(\d*\)//;
    my $line = $entry->{'acl_line'} // join(' ', $entry->{'action'}, $acl_protocol, 'any', 'any');
    # the comment is written in a YAML double quoted string of the playbook
    $line =~ s/["\\]/'/g;
    $line =~ s/\s+/ /g;
    return {
        comment  => "PacketFence role $role: $line",
        policy   => $entry->{'action'} eq 'permit' ? 'allow' : 'deny',
        protocol => MERAKI_RULE_PROTOCOLS->{$protocol},
        destPort => $port,
        destCidr => $cidr,
    };
}

sub _merakiProtocol {
    my ($self, $entry) = @_;
    my $protocol = $entry->{'protocol'};
    return undef if !defined($protocol) || ref($protocol);
    $protocol =~ s/\(\d*\)//;
    return exists MERAKI_RULE_PROTOCOLS->{$protocol} ? $protocol : undef;
}

# The number of a destination port of a role ACL, written as a number or as a
# service name (eq www), 1 to 65535 as the rule takes it, or undef
sub _merakiPortNumber {
    my ($self, $port, $protocol) = @_;
    return undef if !defined $port;
    my $number = $port =~ /^\d+$/ ? $port : scalar getservbyname($port, $protocol);
    return defined($number) && $number =~ /^\d+$/ && $number >= 1 && $number <= 65535 ? $number : undef;
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
