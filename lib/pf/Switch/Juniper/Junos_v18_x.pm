package pf::Switch::Juniper::Junos_v18_x;

=head1 NAME

pf::SNMP::Juniper::Junos_v18_x - Object oriented module to manage Juniper's EX Series switches

=head1 STATUS

Supports
 MAC Authentication (MAC RADIUS in Juniper's terms)
 802.1X

Developed and tested on Juniper ex2300 running on JUNOS 18.2

=head1 BUGS AND LIMITATIONS

=head2 VoIP is only supported in untagged mode

VoIP devices will use the defined voiceVlan but in untagged mode.
A computer and a phone in the same port can still be on two different VLANs since Juniper supports multiple VLANs per port.

=head2 VSTP and RADIUS dynamic VLAN assignment

Currently, these two technologies cannot be enabled at the same time on the ports and VLANs on which PacketFence is enabled.

=cut

use strict;
use warnings;

use base ('pf::Switch::Juniper::Junos_v15_x');

use pf::constants;
sub description { 'Junos v18.x' }
sub switchDriverId { 'juniper_junos' }

# importing switch constants
use pf::Switch::constants;
use pf::node qw(node_attributes);
use Try::Tiny;
use pf::util;
use pf::radius::constants;

# Access lists are pushed inline with the Juniper-Switching-Filter VSA, which
# is verified on this branch only: the older modules target non ELS platforms
# where multi term filters need Junos 15.1X53-D55 or later.
use pf::SwitchSupports qw(
    AccessListBasedEnforcement
);

=head2 radiusDisconnect

Send a Disconnect request to disconnect a mac

=cut

=head2 getVoipVsa

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).
For now it returns the voiceVlan untagged since Juniper supports multiple untagged VLAN in the same interface

=cut

sub getVoipVsa{
    my ($self) = @_;
    my $logger = $self->logger;
    my $voiceVlan = $self->{'_voiceVlan'};
    
    $logger->info("Accepting phone with Access-Accept on voiceVlan $voiceVlan");
    
    return (
        'Juniper-VoIP-Vlan' => "$voiceVlan",
    );
}

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger;

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!$self->hasRadiusSecret()) {
        $logger->warn(
            "Unable to perform RADIUS Disconnect-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # translating to expected format 00-11-22-33-CA-FE
    $mac = uc($mac);
    $mac =~ s/:/-/g;

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    my $response;
    try {
        my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = $self->handleRadiusDisconnect($connection_info, $attributes_ref, []);

    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS Disconnect-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ( ($response->{'Code'} eq 'Disconnect-ACK') || ($response->{'Code'} eq 'CoA-ACK') );

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=head2 setAdminStatus - bounce switch port with radius CoA technique

Send a CoA request to bounce switch port

=cut

sub setAdminStatus {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    #We need to fetch the MAC on the ifIndex in order to bounce switch port with CoA.
    my @locationlog = locationlog_view_open_switchport_no_VoIP( $self->{_ip}, $ifIndex );
    my $mac = $locationlog[0]->{'mac'};
    if (!$mac) {
        @locationlog = locationlog_view_open_switchport_only_VoIP( $self->{_ip}, $ifIndex );
        $mac = $locationlog[0]->{'mac'};
    }
    
    if (!$mac) {
        $logger->info("Can't find MAC address in the locationlog... we won't perform port bounce");
        return $TRUE;
    }

    if ( !$self->isProductionMode() ) {
        $logger->info("Switch not in production mode... we won't perform port bounce");
        return $TRUE;
    }

    if (!$self->hasRadiusSecret()) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on $self->{'_id'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("bouncing $mac using RADIUS CoA-Request method");

    # translating to expected format 00-11-22-33-CA-FE
    $mac = uc($mac);
    $mac =~ s/:/-/g;

    my $response;
    my $send_disconnect_to = $self->{'_controllerIp'} || $self->{'_ip'};
    try {
        my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);

        $response = $self->handleRadiusCoa( $connection_info,
            {
                'Acct-Terminate-Cause' => 'Admin-Reset',
                'NAS-IP-Address' => $self->{'_switchIp'},
                'Calling-Station-Id' => $mac,
            },
            [{ 'vendor' => 'Juniper', 'attribute' => 'Juniper-AV-Pair', 'value' => 'Port-Bounce' }],
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

# Junos caps one instance of a vendor specific attribute at 247 characters, and
# a switching filter at 20 match conditions and 4000 characters across every
# instance of the attribute. A filter that goes over a limit is ignored by the
# switch without any error, so the budgets are enforced here.
use constant SWITCHING_FILTER_ATTRIBUTE_LIMIT  => 247;
use constant SWITCHING_FILTER_TOTAL_LIMIT      => 4000;
use constant SWITCHING_FILTER_CONDITIONS_LIMIT => 20;

# Ends a filter that had to be cut short. Terms are evaluated in order, so a
# deny that cannot be sent must not let the terms after it allow what it
# blocked: the filter stops there and denies everything else instead.
use constant SWITCHING_FILTER_DENY_ALL => 'Match Destination-ip 0.0.0.0/0 Action deny';

# The Cisco port names Cisco::AccessList::Parser accepts, by IP protocol. The
# filter only takes port numbers.
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

=head2 returnRadiusAccessAccept

Add the ACLs of the role to the Access-Accept as C<Juniper-Switching-Filter>
attributes, one instance per filter term.

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    # the RADIUS filter runs once, at the end, over the complete reply
    $args->{'unfiltered'} = $TRUE;

    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if ($status == $RADIUS::RLM_MODULE_USERLOCK);

    my @filters = defined($radius_reply_ref->{'Juniper-Switching-Filter'})
        ? @{$radius_reply_ref->{'Juniper-Switching-Filter'}}
        : ();

    if (isenabled($self->{_AccessListMap}) && $self->supportsAccessListBasedEnforcement) {
        my $role = $args->{'user_role'};
        if (defined($role) && $role ne "") {
            my $access_list = $self->getAccessListByName($role, $args->{'mac'}, $args->{'ifIndex'});
            if ($access_list) {
                foreach my $term ($self->_switchingFilterBudget([$self->_switchingFilterTerms($access_list, $role)], $role)) {
                    push @filters, $term;
                    $logger->info("(".$self->{'_id'}.") Adding access list : $term to the RADIUS reply");
                }
                $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
            }
            else {
                $logger->info("(".$self->{'_id'}.") No access lists defined for this role $role");
            }
        }
    }

    $radius_reply_ref->{'Juniper-Switching-Filter'} = \@filters if @filters;

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule, $args, $radius_reply_ref);

    return [$status, %$radius_reply_ref];
}

=head2 _switchingFilterBudget

Keep the terms within the limits of the switch, which ignores a filter over one
of them without any error.

A permit that does not fit in one attribute is skipped. When a deny does not
fit, or when the filter runs out of room, the filter is cut there and ends with
L</SWITCHING_FILTER_DENY_ALL>: dropping a deny, or the terms after the cut that
may include one, would let traffic through that the role blocks.

=cut

sub _switchingFilterBudget {
    my ($self, $terms, $role) = @_;
    my $logger = $self->logger;

    my $budget = SWITCHING_FILTER_TOTAL_LIMIT;
    my $conditions_left = SWITCHING_FILTER_CONDITIONS_LIMIT;
    my @kept;
    foreach my $term (@$terms) {
        my $too_long = length($term) > SWITCHING_FILTER_ATTRIBUTE_LIMIT;
        if ($too_long && $term !~ /\sAction\s+deny$/) {
            $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': term is ".length($term)." characters, one attribute holds at most ".SWITCHING_FILTER_ATTRIBUTE_LIMIT.": $term");
            next;
        }
        my $conditions = $self->_switchingFilterConditionCount($term);
        if ($too_long || length($term) > $budget || $conditions > $conditions_left) {
            $logger->warn("(".$self->{'_id'}.") Ending the ACLs of role '$role' with a deny all: the switch ignores a filter over ".SWITCHING_FILTER_CONDITIONS_LIMIT." match conditions or ".SWITCHING_FILTER_TOTAL_LIMIT." characters, and one attribute holds at most ".SWITCHING_FILTER_ATTRIBUTE_LIMIT." characters");
            while (@kept && (length(SWITCHING_FILTER_DENY_ALL) > $budget || $conditions_left < 1)) {
                my $removed = pop @kept;
                $budget += length($removed);
                $conditions_left += $self->_switchingFilterConditionCount($removed);
            }
            push @kept, SWITCHING_FILTER_DENY_ALL;
            last;
        }
        $budget -= length($term);
        $conditions_left -= $conditions;
        push @kept, $term;
    }

    return @kept;
}

=head2 _switchingFilterConditionCount

Number of match conditions in a term. The switch counts conditions, not terms,
so "Match Ip-protocol 6, Destination-ip 10.0.0.1 Action deny" counts as two.

=cut

sub _switchingFilterConditionCount {
    my ($self, $term) = @_;
    return 0 if $term !~ /^Match\s+(.*?)\s+Action\s/;
    my @conditions = split(/\s*,\s*/, $1);
    return scalar(@conditions);
}

=head2 _switchingFilterTerms

Return the list of C<Juniper-Switching-Filter> terms for an access list.

Only the role path of L<pf::Switch/_getAccessListByName> runs the access list
through L</acl_chewer>: a node's bypass_acls and the access lists defined on the
switch entry itself are returned untouched, so they arrive here in Cisco syntax
and are translated. Anything that is still not a term is dropped, because the
switch refuses the whole Access-Accept over a single malformed attribute.

The list stops at L</SWITCHING_FILTER_DENY_ALL>: nothing after it can match.

The lines are translated one at a time, so a line whose permits are all skipped
gives nothing rather than the deny all L</acl_chewer> ends a role with: the
lines after it still apply. When no term is left at all from inbound lines,
the list is the deny all, like a role whose ACLs were all skipped.

=cut

sub _switchingFilterTerms {
    my ($self, $access_list, $role) = @_;
    my $logger = $self->logger;

    my @terms;
    my $inbound = 0;
    while ($access_list =~ /([^\n]+)\n?/g) {
        my $line = $1;
        next if $line !~ /\S/;

        if ($line =~ /^Match\s/) {
            push @terms, $line;
            last if $line eq SWITCHING_FILTER_DENY_ALL;
            next;
        }

        $inbound ||= $line !~ /^\s*out\|/;
        my @chewed = grep { /^Match\s/ } split(/\n/, $self->acl_chewer($line, $role, allow_empty => 1) // '');
        if (!@chewed) {
            $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': cannot be expressed as a Juniper-Switching-Filter term: $line");
            next;
        }
        push @terms, @chewed;
        last if $chewed[-1] eq SWITCHING_FILTER_DENY_ALL;
    }

    if (!@terms && $inbound) {
        $logger->warn("(".$self->{'_id'}.") Denying all the traffic of role '$role': none of its inbound ACLs can be represented");
        push @terms, SWITCHING_FILTER_DENY_ALL;
    }

    return @terms;
}


=head2 acl_chewer

Translate PacketFence ACLs (Cisco extended ACL syntax) into the filter terms
carried by the C<Juniper-Switching-Filter> RADIUS VSA (Juniper VSA 48).

Each returned line is one complete term, for example:

    Match Ip-protocol 6, Destination-ip 192.0.2.10 Action allow

The caller sends each line as its own instance of the attribute: a single
instance is capped at 247 characters and Junos accepts roughly 4000 characters
across all instances of the attribute.

The grammar is case sensitive. Only the first letter of a match condition is
capitalized and the action is lowercase; anything else is refused by the switch
with C<DOT1XD_ATTRIBUTE_VALIDATION_FAILED: switching-filter attribute validation
failed>. A refused attribute invalidates the entire Access-Accept and leaves the
supplicant in the C<Held> state, so a term that cannot be represented is dropped
with a warning rather than emitted in a form the switch would reject.

Dropping a permit only narrows the role, dropping a deny would widen it: an
inbound deny that cannot be represented ends the list with
L</SWITCHING_FILTER_DENY_ALL> instead.

A role whose inbound ACLs were all dropped, or cannot be parsed, gets
L</SWITCHING_FILTER_DENY_ALL> rather than no filter, which would leave the
supplicant unrestricted. With C<allow_empty>, all dropped ACLs give an empty
result instead, for callers that translate a role one line at a time and add
the deny all once at the end (L</_switchingFilterTerms>).

=cut

sub acl_chewer {
    my ($self, $acl, $role, %options) = @_;

    my ($acl_ref, @direction) = $self->format_acl($acl);
    my $entries = $acl_ref->{'packetfence'}->{'entries'} // [];
    my $inbound = grep { ($_ // 'in') eq 'in' } @direction;

    # The parser returns no entry for ACLs it cannot read
    if (@$entries != @direction) {
        return '' if !$inbound;
        $self->logger->warn("(".$self->{'_id'}.") Denying all the traffic of role '$role': its ACLs cannot be parsed, and sending no filter would leave the supplicant unrestricted");
        return SWITCHING_FILTER_DENY_ALL . "\n";
    }

    my $chewed = '';
    my $i = 0;
    foreach my $entry (@$entries) {
        my $dir = $direction[$i++] // 'in';
        my $term = $self->_switchingFilterTerm($entry, $dir, $role);
        if (!defined $term) {
            # An egress ACL is never enforced by the VSA, so skipping it changes
            # nothing on the switch. Skipping an ingress deny would let the terms
            # after it allow what it blocks.
            next if $dir eq 'out' || ($entry->{'action'} // '') ne 'deny';
            $self->logger->warn("(".$self->{'_id'}.") Ending the ACLs of role '$role' with a deny all: a deny that cannot be represented must not let the ACLs after it through");
            $chewed .= SWITCHING_FILTER_DENY_ALL . "\n";
            last;
        }
        $chewed .= $term . "\n";
    }

    # Sending no filter would leave the supplicant unrestricted, while the
    # switch denies whatever a filter does not allow
    if ($chewed eq '' && $inbound && !$options{allow_empty}) {
        $self->logger->warn("(".$self->{'_id'}.") Denying all the traffic of role '$role': none of its inbound ACLs can be represented");
        $chewed = SWITCHING_FILTER_DENY_ALL . "\n";
    }

    return $chewed;
}

=head2 _switchingFilterTerm

Build a single C<Juniper-Switching-Filter> term from one parsed ACL entry.

Returns undef when the entry cannot be represented by the VSA, which supports
only these match conditions: destination-mac, source-vlan, source-dot1q-tag,
destination-ip, ip-protocol, source-port and destination-port.

=cut

sub _switchingFilterTerm {
    my ($self, $entry, $dir, $role) = @_;
    my $logger = $self->logger;

    # The VSA filters traffic coming from the supplicant and has no notion of
    # direction, so an egress ACL cannot be represented.
    if ($dir eq 'out') {
        $logger->warn("(".$self->{'_id'}.") Skipping outbound ACL of role '$role': Juniper-Switching-Filter only filters traffic sent by the supplicant");
        return;
    }

    my $reason = $self->untranslatableAclQualifier($entry);
    if (defined $reason) {
        $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': $reason");
        return;
    }

    # There is no TCP flag or ICMP type match condition. Dropping the qualifier
    # would turn "permit tcp any any established" into a permit of every TCP
    # packet, so drop the whole term instead.
    if (defined $entry->{'tcp_flags'}) {
        $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': Juniper-Switching-Filter has no TCP flags match condition ('".$entry->{'tcp_flags'}."')");
        return;
    }
    if (defined $entry->{'icmp_qualifier'}) {
        $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': Juniper-Switching-Filter has no ICMP type match condition ('".$entry->{'icmp_qualifier'}."')");
        return;
    }

    # There is no source address match condition. Dropping the condition would
    # silently widen the term, so drop the whole term instead.
    if (!$self->_aclAddressIsAny($entry->{'source'})) {
        $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': Juniper-Switching-Filter has no source address match condition");
        return;
    }

    my @match;

    my $protocol = $self->_aclProtocolNumber($entry->{'protocol'});
    push @match, "Ip-protocol $protocol" if defined $protocol;

    my $destination = $entry->{'destination'};
    if (!$self->_aclAddressIsAny($destination)) {
        my $prefix = $self->_aclWildcardToPrefixLen($destination->{'wildcard'});
        if (!defined $prefix) {
            $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': non contiguous wildcard mask '".$destination->{'wildcard'}."' has no prefix length");
            return;
        }
        # Cisco ignores the address bits the wildcard covers, send the network
        my $network = $self->_aclNetworkAddress($destination->{'ipv4_addr'}, $destination->{'wildcard'});
        push @match, "Destination-ip " . $network . ($prefix == 32 ? '' : "/$prefix");
    }

    foreach my $side (['source', 'Source-port'], ['destination', 'Destination-port']) {
        my ($key, $keyword) = @$side;
        my $port = $entry->{$key}->{'port'};
        next if !defined $port;
        if ($port !~ /^eq\s+(\S+)$/) {
            $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': port operator '$port' cannot be represented, only 'eq' is supported");
            return;
        }
        my $number = $self->_aclPortNumber($1, $protocol);
        if (!defined $number) {
            $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': unknown port name in '$port'");
            return;
        }
        push @match, "$keyword $number";
    }

    # "Match Action deny" is not valid grammar, so a catch all needs an explicit
    # condition. 0.0.0.0/0 matches every destination.
    if (!@match) {
        push @match, "Destination-ip 0.0.0.0/0";
    }

    my $action = $entry->{'action'} eq 'permit' ? 'allow' : 'deny';

    return "Match " . join(', ', @match) . " Action $action";
}

=head2 _aclAddressIsAny

Whether a parsed ACL address stanza is the "any" wildcard.

=cut

sub _aclAddressIsAny {
    my ($self, $address) = @_;
    return $address->{'ipv4_addr'} eq '0.0.0.0' && $address->{'wildcard'} eq '255.255.255.255';
}

=head2 _aclProtocolNumber

Extract the IP protocol number from the parsed protocol, which looks like
"tcp(6)" or "udp(17)". Returns undef for "ip()", which matches any protocol and
therefore needs no match condition.

=cut

sub _aclProtocolNumber {
    my ($self, $protocol) = @_;
    return if !defined $protocol;
    return $1 if $protocol =~ /\((\d+)\)/;
    return;
}

=head2 _aclWildcardToPrefixLen

Convert a Cisco wildcard mask into a prefix length. Returns undef for a non
contiguous mask, which has no prefix length equivalent.

=cut

sub _aclWildcardToPrefixLen {
    my ($self, $wildcard) = @_;

    my $mask = norm_net_mask($wildcard);
    my $bits = unpack('%32b*', pack('C4', split(/\./, $mask)));
    my $contiguous = $bits == 0 ? 0 : (0xFFFFFFFF << (32 - $bits)) & 0xFFFFFFFF;

    return if join('.', unpack('C4', pack('N', $contiguous))) ne $mask;

    return $bits;
}

=head2 _aclNetworkAddress

The network address of an address and its Cisco wildcard mask, which ignores
the address bits the wildcard covers: 10.0.0.5 0.0.0.255 is 10.0.0.0.

=cut

sub _aclNetworkAddress {
    my ($self, $address, $wildcard) = @_;
    my $mask = norm_net_mask($wildcard);
    return join('.', unpack('C4', pack('C4', split(/\./, $address)) & pack('C4', split(/\./, $mask))));
}

=head2 _aclPortNumber

The number of a port given as a number or as a Cisco port name of the
protocol. Returns undef for a name the protocol does not know.

=cut

sub _aclPortNumber {
    my ($self, $port, $protocol) = @_;
    return $port if $port =~ /^\d+$/;
    return if !defined $protocol || !exists $CISCO_PORT_NAMES{$protocol};
    return $CISCO_PORT_NAMES{$protocol}{lc($port)};
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
