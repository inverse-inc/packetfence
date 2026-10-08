package pf::Switch::Huawei::S5735;

=head1 NAME

pf::Switch::Huawei::S5735 - Object oriented module to manage Huawei CloudEngine
S5735 switches running YunShan OS (V600)

=head1 STATUS

Supports

 MAC Authentication (MAC address authentication in Huawei's terms)
 802.1X
 RADIUS dynamic VLAN assignment
 Access lists pushed inline with the HW-Data-Filter RADIUS attribute

Developed and tested on a CloudEngine S5735R-L24P4S-A-V2 running YunShan OS
V600R024C00SPC500.

=head1 BUGS AND LIMITATIONS

=head2 Access lists only apply on the Access-Accept

The switch accepts C<HW-Data-Filter> in a CoA-Request and answers CoA-ACK, but
the rules are not applied to the session: only the copy carried by the
Access-Accept takes effect. Re-evaluating access therefore has to disconnect the
endpoint so it authenticates again, which is what the default deauthentication
method of this module already does.

=head2 A single malformed rule disables the whole access list

The switch validates the rules as a set. One rule it cannot parse makes it drop
every rule silently: the endpoint authenticates normally and ends up with
B<unrestricted> access, and the session shows no C<DACL group name(Effective)>.
Nothing is logged on the switch. Every rule is therefore validated here before
it is sent, and a rule that cannot be represented is dropped rather than passed
through in a form the switch might refuse.

=head2 The switch has no implicit deny

An endpoint matching none of the rules is B<permitted>, the opposite of the
Cisco syntax PacketFence access lists are written in. A catch all deny is
appended to every access list to restore the expected semantics, which also
means a role whose access list is entirely untranslatable ends up denied rather
than unrestricted.

=head2 Deauthentication identifies the session by MAC address only

The Disconnect-Request carries the endpoint MAC as C<Calling-Station-Id> and no
C<Acct-Session-Id>. The switch silently ignores a request whose
C<Acct-Session-Id> does not match the current session (no Disconnect-NAK), and
the endpoint stays online, so a stale accounting session id would make every
re-evaluation fail without an error.

=head2 Outbound access lists cannot be represented

The authentication profile filters traffic sent by the endpoint (control
direction inbound), so C<out|> access list lines are dropped with a warning.

=head1 SWITCH CONFIGURATION

The listener used for deauthentication only starts once C<radius local-ip> is
configured. Without it the switch answers ICMP port unreachable on 3799 and
every Disconnect-Request times out. The Disconnect-Request is only answered
when PacketFence is declared as an authorization server:

 radius local-ip <switch management ip>
 radius-server authorization <packetfence ip> shared-key cipher <secret>

Ports also need to be C<hybrid> rather than C<access> for RADIUS VLAN
assignment to apply.

=cut

use strict;
use warnings;

use base ('pf::Switch::Huawei::S5710');

use pf::constants;
use pf::util;
use pf::radius::constants;
use pf::access_filter::radius;

sub description { 'Huawei CloudEngine S5735' }

=head1 SUBROUTINES

=cut

# Access lists are pushed inline with the HW-Data-Filter VSA, which is verified
# on this model only: the S5710 module targets V200 platforms where the
# attribute has never been tested.
use pf::SwitchSupports qw(
    AccessListBasedEnforcement
);

# The value of one RADIUS attribute holds 253 bytes, and a rule number is the
# last three digits of an ACL rule number, so it ranges from 0 to 999. The real
# ceiling is the 4096 byte RADIUS packet the rules all have to fit in, next to
# everything else the Access-Accept carries, hence the byte budget; 128 rules
# were accepted by the switch in testing, and the count is kept below that so a
# list of long rules cannot reach the packet limit first.
use constant DATA_FILTER_ATTRIBUTE_LIMIT => 253;
use constant DATA_FILTER_RULES_LIMIT     => 64;
use constant DATA_FILTER_TOTAL_LIMIT     => 3000;

# Protocols the attribute accepts, by IP protocol number. Anything else has no
# keyword and cannot be expressed.
our %DATA_FILTER_PROTOCOLS = (
    1  => 'icmp',
    2  => 'igmp',
    6  => 'tcp',
    17 => 'udp',
);

=head2 returnRadiusAccessAccept

Add the access list of the role to the Access-Accept as C<Huawei-Data-Filter>
attributes, one instance per rule.

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

    if (isenabled($self->{_AccessListMap}) && $self->supportsAccessListBasedEnforcement) {
        my $role = $args->{'user_role'};
        if (defined($role) && $role ne "") {
            my $access_list = $self->getAccessListByName($role, $args->{'mac'}, $args->{'ifIndex'});
            if ($access_list) {
                my @rules = $self->_dataFilterRules($access_list, $role);
                $radius_reply_ref->{'Huawei-Data-Filter'} = \@rules if @rules;
                $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
            }
            else {
                $logger->info("(".$self->{'_id'}.") No access lists defined for this role $role");
            }
        }
    }

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule, $args, $radius_reply_ref);

    return [$status, %$radius_reply_ref];
}

=head2 deauthenticateMacRadius

Disconnect the endpoint by MAC address, see
L</Deauthentication identifies the session by MAC address only>.

=cut

sub deauthenticateMacRadius {
    my ($self, $mac, $is_dot1x) = @_;
    my $logger = $self->logger;

    if (!$self->isProductionMode()) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    my $calling_station_id = uc($mac);
    $calling_station_id =~ s/:/-/g;

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect($mac, { 'Calling-Station-Id' => $calling_station_id });
}

=head2 _dataFilterRules

Return the numbered C<Huawei-Data-Filter> rules for an access list, catch all
included.

Only the role path of L<pf::Switch/_getAccessListByName> runs the access list
through L</acl_chewer>: a node's bypass_acls and the access lists defined on the
switch entry itself are returned untouched, so they arrive here in Cisco syntax
and are translated. Rules are numbered here rather than in L</acl_chewer> so the
numbering stays contiguous and in the order the administrator wrote the access
list, which is the order the switch evaluates them in.

=cut

sub _dataFilterRules {
    my ($self, $access_list, $role) = @_;
    my $logger = $self->logger;

    my @rules;
    while ($access_list =~ /([^\n]+)\n?/g) {
        my $line = $1;
        next if $line !~ /\S/;

        my @chewed;
        if ($self->_isDataFilterRule($line)) {
            # already in the switch's syntax, only the numbering is redone
            $line =~ s/^\s*\$\d+\s+//;
            @chewed = ($line);
        }
        else {
            @chewed = grep { $self->_isDataFilterRule($_) }
                split(/\n/, $self->acl_chewer($line, $role) // '');
        }

        if (!@chewed) {
            $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': cannot be expressed as an HW-Data-Filter rule: $line");
            next;
        }
        push @rules, @chewed;
    }

    my @numbered;
    my $bytes = 0;
    my $i = 1;
    foreach my $rule (@rules) {
        my $numbered = '$' . $i . ' ' . $rule;
        if (length($numbered) > DATA_FILTER_ATTRIBUTE_LIMIT) {
            # one oversized rule would be truncated on the wire and take the
            # whole access list down with it
            $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': rule is ".length($numbered)." characters, one attribute holds at most ".DATA_FILTER_ATTRIBUTE_LIMIT.": $numbered");
            next;
        }
        # one slot and its bytes stay reserved for the catch all below
        if (@numbered + 1 >= DATA_FILTER_RULES_LIMIT
            || $bytes + length($numbered) > DATA_FILTER_TOTAL_LIMIT - 16) {
            $logger->warn("(".$self->{'_id'}.") Dropping the remaining ACLs of role '$role': an Access-Accept holds at most ".DATA_FILTER_RULES_LIMIT." rules or ".DATA_FILTER_TOTAL_LIMIT." characters of them");
            last;
        }
        $bytes += length($numbered);
        push @numbered, $numbered;
        $logger->info("(".$self->{'_id'}.") Adding access list : $numbered to the RADIUS reply");
        $i++;
    }

    # The switch permits what no rule matches, so the implicit deny the access
    # list is written against has to be spelled out. It is appended even when
    # nothing survived the translation: denying the endpoint is visible and
    # fixable, silently granting it full access is not.
    push @numbered, '$' . $i . ' deny';

    return @numbered;
}

=head2 _isDataFilterRule

Whether a line is a complete rule in the switch's syntax, with or without its
rule number.

The match is anchored on both ends and spells out the whole grammar on purpose.
A prefix match on C<permit|deny> would also accept a Cisco line, which starts
with the same two words, and passing one through untranslated is the very thing
that makes the switch throw the access list away and leave the endpoint
unrestricted.

=cut

our $DATA_FILTER_ADDRESS = qr/any|\d{1,3}(?:\.\d{1,3}){3}\/\d{1,2}/;
our $DATA_FILTER_RULE = qr{
    ^
    (?:permit|deny)
    (?:\s+(?:tcp|udp|icmp|igmp))?
    (?:\s+src\s+(?:$DATA_FILTER_ADDRESS)(?:\s+\d+)?)?
    (?:\s+dst\s+(?:$DATA_FILTER_ADDRESS)(?:\s+\d+)?)?
    $
}x;

sub _isDataFilterRule {
    my ($self, $line) = @_;
    $line =~ s/^\s+|\s+$//g;
    $line =~ s/^\$\d+\s+//;
    return $line =~ $DATA_FILTER_RULE ? $TRUE : $FALSE;
}

=head2 acl_chewer

Translate PacketFence access lists (Cisco extended ACL syntax) into the rules
carried by the C<HW-Data-Filter> RADIUS VSA (Huawei VSA 82).

Each returned line is one rule without its number, for example:

    permit tcp dst 192.168.40.10/32 443

The grammar is C<< <permit|deny> [protocol] [src <address> [port]] [dst
<address> [port]] >>, where the protocol is one of tcp, udp, icmp or igmp, an
address is C<any> or C<ip/prefix>, and a port is a single port number bound to
the address it follows.

A rule that cannot be represented is dropped: the switch discards the entire
access list when one rule does not parse, and leaves the endpoint unrestricted.

=cut

sub acl_chewer {
    my ($self, $acl, $role) = @_;

    my ($acl_ref, @direction) = $self->format_acl($acl);

    my $chewed = '';
    my $i = 0;
    foreach my $entry (@{$acl_ref->{'packetfence'}->{'entries'}}) {
        my $dir = $direction[$i++] // 'in';
        my $rule = $self->_dataFilterRule($entry, $dir, $role);
        next if !defined $rule;
        $chewed .= $rule . "\n";
    }

    return $chewed;
}

=head2 _dataFilterRule

Build a single C<HW-Data-Filter> rule from one parsed ACL entry. Returns undef
when the entry cannot be represented.

=cut

sub _dataFilterRule {
    my ($self, $entry, $dir, $role) = @_;
    my $logger = $self->logger;

    # The authentication profile filters traffic sent by the endpoint, so an
    # egress access list has no equivalent.
    if ($dir eq 'out') {
        $logger->warn("(".$self->{'_id'}.") Skipping outbound ACL of role '$role': HW-Data-Filter only filters traffic sent by the endpoint");
        return;
    }

    my @tokens = ($entry->{'action'} eq 'permit' ? 'permit' : 'deny');

    my $protocol = $self->_dataFilterProtocol($entry->{'protocol'});
    if (!defined $protocol) {
        $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': protocol '".($entry->{'protocol'} // '')."' has no HW-Data-Filter keyword");
        return;
    }
    push @tokens, $protocol if $protocol ne '';

    foreach my $side (['source', 'src'], ['destination', 'dst']) {
        my ($key, $keyword) = @$side;
        my $address = $entry->{$key};

        my $port = $address->{'port'};
        if (defined $port && $port !~ /^eq\s+(\d+)$/) {
            $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': port operator '$port' cannot be represented, only 'eq' is supported");
            return;
        }
        my $port_number = defined $port ? $1 : undef;

        # "src any" with no port says nothing, and every token that says nothing
        # is a token the switch could refuse
        next if $self->_aclAddressIsAny($address) && !defined $port_number;

        if ($self->_aclAddressIsAny($address)) {
            push @tokens, $keyword, 'any';
        }
        else {
            my $prefix = $self->_aclWildcardToPrefixLen($address->{'wildcard'});
            if (!defined $prefix) {
                $logger->warn("(".$self->{'_id'}.") Skipping ACL of role '$role': non contiguous wildcard mask '".$address->{'wildcard'}."' has no prefix length");
                return;
            }
            push @tokens, $keyword, $address->{'ipv4_addr'} . "/$prefix";
        }

        push @tokens, $port_number if defined $port_number;
    }

    return join(' ', @tokens);
}

=head2 _dataFilterProtocol

Map the parsed protocol, which looks like "tcp(6)" or "ip()", to its
HW-Data-Filter keyword. Returns the empty string for "ip", which matches every
protocol and is expressed by leaving the keyword out, and undef for a protocol
the attribute has no keyword for.

=cut

sub _dataFilterProtocol {
    my ($self, $protocol) = @_;
    return '' if !defined $protocol;
    return '' if $protocol =~ /^ip\(\)?$/;
    return $DATA_FILTER_PROTOCOLS{$1} if $protocol =~ /\((\d+)\)/ && exists $DATA_FILTER_PROTOCOLS{$1};
    return;
}

=head2 _aclAddressIsAny

Whether a parsed ACL address stanza is the "any" wildcard.

=cut

sub _aclAddressIsAny {
    my ($self, $address) = @_;
    return $address->{'ipv4_addr'} eq '0.0.0.0' && $address->{'wildcard'} eq '255.255.255.255';
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
