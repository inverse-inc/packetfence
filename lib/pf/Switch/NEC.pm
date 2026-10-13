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
use Cisco::AccessList::Parser;

=head1 SUPPORTED TECHNOLOGIES

=cut

use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    RadiusDynamicVlanAssignment
    RadiusVoip
    RoleBasedEnforcement
    PushACLs
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
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    $logger->error("This authentication mode is not supported");
    return;
}

=item deauthenticateMacRadius

Disconnect the session with a RFC 3576 Disconnect-Request. The dynamic-author
server of the switch identifies the session by its Calling-Station-Id.

=cut

sub deauthenticateMacRadius {
    my ($self, $ifIndex, $mac) = @_;
    return $self->radiusDisconnect($mac);
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

=item acl_chewer

Translate PacketFence's Cisco-style ACL lines into Comware advanced ACL C<rule>
lines, pushed to the switch by PushACLs. The C<in|>/C<out|> direction prefix is
kept: PacketFence splits the result into the C<E<lt>roleE<gt>> and
C<E<lt>roleE<gt>out> ACLs.

Each line is parsed with L<Cisco::AccessList::Parser>, like the other switch
modules. A line, or a qualifier, the translation cannot carry is never dropped
silently, since dropping a condition widens a permit:

=over

=item * a permit that cannot be expressed is skipped, which only narrows the role

=item * a deny that cannot be expressed ends the ACLs of its direction with C<rule deny ip>, so the lines after it cannot allow what it blocks

=item * a direction whose lines were all skipped gets C<rule deny ip> rather than nothing

=back

Not expressed: TCP flags, ICMP types, non contiguous masks, and the C<dscp>,
C<precedence>, C<tos>, C<fragments> and C<time-range> qualifiers, which the
parser accepts but does not report.

=cut

# The Cisco port names Cisco::AccessList::Parser accepts, by IP protocol. The
# rules are sent with port numbers.
our %CISCO_PORT_NAMES = (
    6 => {
        'bgp' => 179, 'chargen' => 19, 'cmd' => 514, 'daytime' => 13,
        'discard' => 9, 'domain' => 53, 'echo' => 7, 'exec' => 512,
        'finger' => 79, 'ftp' => 21, 'ftp-data' => 20, 'gopher' => 70,
        'hostname' => 101, 'ident' => 113, 'irc' => 194, 'klogin' => 543,
        'kshell' => 544, 'login' => 513, 'lpd' => 515, 'nntp' => 119,
        'pim-auto-rp' => 496, 'pop2' => 109, 'pop3' => 110, 'smtp' => 25,
        'sunrpc' => 111, 'syslog' => 514, 'tacacs' => 49, 'talk' => 517,
        'telnet' => 23, 'time' => 37, 'uucp' => 540, 'whois' => 43,
        'www' => 80,
    },
    17 => {
        'biff' => 512, 'bootpc' => 68, 'bootps' => 67, 'discard' => 9,
        'dnsix' => 195, 'domain' => 53, 'echo' => 7, 'isakmp' => 500,
        'mobile-ip' => 434, 'nameserver' => 42, 'netbios-dgm' => 138,
        'netbios-ns' => 137, 'netbios-ss' => 139, 'non500-isakmp' => 4500,
        'ntp' => 123, 'pim-auto-rp' => 496, 'rip' => 520, 'snmp' => 161,
        'snmptrap' => 162, 'sunrpc' => 111, 'syslog' => 514, 'tacacs' => 49,
        'talk' => 517, 'tftp' => 69, 'time' => 37, 'who' => 513,
        'xdmcp' => 177,
    },
);

use constant COMWARE_DENY_ALL => 'rule deny ip';

sub acl_chewer {
    my ($self, $acl, $role) = @_;
    my $logger = $self->logger;
    $role //= '';

    my (%rules, %had, %cut);
    my @order;
    while ($acl =~ /([^\n]+)\n?/g) {
        my $line = $1;
        $line =~ s/^\s+|\s+$//g;
        next if $line eq '' || $line =~ /^(?:remark|#)/i;

        my $dir = 'in';
        my $prefix = '';
        if ($line =~ /^(in|out)\|(.*)$/) {
            ($dir, $prefix, $line) = ($1, "$1|", $2);
        }
        next if $cut{$dir};
        push @order, $dir if !$had{$dir}++;

        my ($action, $rule, $reason) = $self->_comwareRule($line);
        if (defined $rule) {
            push @{$rules{$dir}}, "$prefix$rule";
            next;
        }
        if (!defined $action || $action ne 'deny') {
            $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': $reason: $line");
            next;
        }
        $logger->warn("(".$self->{'_id'}.") Ending the $dir ACLs of role '$role' with a deny all: $reason, and skipping a deny would let the ACLs after it through: $line");
        push @{$rules{$dir}}, $prefix . COMWARE_DENY_ALL;
        $cut{$dir} = 1;
    }

    my $out = '';
    foreach my $dir (@order) {
        if (!@{$rules{$dir} // []}) {
            $logger->warn("(".$self->{'_id'}.") Denying all the $dir traffic of role '$role': none of its $dir ACLs can be translated");
            push @{$rules{$dir}}, ($dir eq 'out' ? 'out|' : '') . COMWARE_DENY_ALL;
        }
        $out .= join('', map { "$_\n" } @{$rules{$dir}});
    }
    return $out;
}

=item _comwareRule

Translate one Cisco extended ACL line, without direction prefix, into a Comware
advanced ACL C<rule>. Returns the action, the rule, and why the line cannot be
translated when the rule is undef.

=cut

sub _comwareRule {
    my ($self, $line) = @_;

    my ($acl_ref) = eval { Cisco::AccessList::Parser->new->parse(input => "ip access-list extended packetfence\n$line\n") };
    my $entries = ref($acl_ref) eq 'HASH' ? $acl_ref->{'packetfence'}{'entries'} : undef;
    if (ref($entries) ne 'ARRAY' || @$entries != 1) {
        my ($action) = $line =~ /^(permit|deny)\b/i;
        return (defined $action ? lc($action) : undef, undef, "not a valid ACL");
    }
    my $entry = $entries->[0];
    my $action = $entry->{'action'};

    # Cisco::AccessList::Parser accepts these qualifiers without reporting them
    # in the parsed entry: the line would be translated without its condition.
    return ($action, undef, "the '$1' qualifier is not translated") if $line =~ /\s(dscp|precedence|tos|fragments|time-range)(?:\s|$)/i;
    return ($action, undef, "TCP flags are not translated ('".$entry->{'tcp_flags'}."')") if defined $entry->{'tcp_flags'};
    return ($action, undef, "ICMP types are not translated ('".$entry->{'icmp_qualifier'}."')") if defined $entry->{'icmp_qualifier'};

    my $protocol;
    my $number;
    if (($entry->{'protocol'} // '') =~ /^ip\(\)$/) {
        $protocol = 'ip';
    } elsif (($entry->{'protocol'} // '') =~ /\((\d+)\)/) {
        $number = $1;
        $protocol = { 1 => 'icmp', 6 => 'tcp', 17 => 'udp' }->{$number} // $number;
    } else {
        return ($action, undef, "unknown protocol '".($entry->{'protocol'} // '')."'");
    }

    my $rule = "rule $action $protocol";
    foreach my $side (['source', 'source', 'source-port'], ['destination', 'destination', 'destination-port']) {
        my ($key, $keyword, $port_keyword) = @$side;
        my $address = $entry->{$key};
        if (!($address->{'ipv4_addr'} eq '0.0.0.0' && $address->{'wildcard'} eq '255.255.255.255')) {
            return ($action, undef, "the $key mask '".$address->{'wildcard'}."' is not contiguous") if !$self->_comwareWildcardIsContiguous($address->{'wildcard'});
            $rule .= " $keyword $address->{'ipv4_addr'} " . ($address->{'wildcard'} eq '0.0.0.0' ? '0' : $address->{'wildcard'});
        }
        next if !defined $address->{'port'};
        my ($operator, @ports) = split(/\s+/, $address->{'port'});
        return ($action, undef, "the $key port '".$address->{'port'}."' is not translated")
            if $operator !~ /^(?:eq|neq|gt|lt|range)$/ || @ports != ($operator eq 'range' ? 2 : 1) || !defined $number;
        my @numbers;
        foreach my $port (@ports) {
            my $value = $port =~ /^\d+$/ ? $port : $CISCO_PORT_NAMES{$number}{lc($port)};
            return ($action, undef, "unknown port name '$port'") if !defined $value;
            push @numbers, $value;
        }
        $rule .= " $port_keyword $operator " . join(' ', @numbers);
    }
    return ($action, $rule, undef);
}

=item _comwareWildcardIsContiguous

Whether a Cisco wildcard mask is a run of low bits (0.0.0.255), i.e. has a
prefix length.

=cut

sub _comwareWildcardIsContiguous {
    my ($self, $wildcard) = @_;
    my @octets = split(/\./, $wildcard // '');
    return 0 if @octets != 4 || grep { !/^\d+$/ || $_ > 255 } @octets;
    my $bits = unpack('N', pack('C4', @octets));
    return (($bits + 1) & $bits) == 0 ? 1 : 0;
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
