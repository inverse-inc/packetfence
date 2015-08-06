package pf::util::dhcpv6;

=head1 NAME

pf::util::dhcpv6 -

=cut

=head1 DESCRIPTION

pf::util::dhcpv6

=cut

use strict;
use warnings;

BEGIN {
    use Exporter ();
    our (@ISA, @EXPORT, @EXPORT_OK);
    @ISA    = qw(Exporter);
    @EXPORT = qw(decompose_dhcpv6 decode_dhcpv6);
}

use NetPacket::Ethernet;
use NetPacket::IPv6;
use NetPacket::UDP;
use bytes;

use constant SOLICIT             => 1;
use constant ADVERTISE           => 2;
use constant REQUEST             => 3;
use constant CONFIRM             => 4;
use constant RENEW               => 5;
use constant REBIND              => 6;
use constant REPLY               => 7;
use constant RELEASE             => 8;
use constant DECLINE             => 9;
use constant RECONFIGURE         => 10;
use constant INFORMATION_REQUEST => 11;
use constant RELAY_FORW          => 12;
use constant RELAY_REPL          => 13;

use constant OPTION_CLIENTID     => 1;
use constant OPTION_SERVERID     => 2;
use constant OPTION_IA_NA        => 3;
use constant OPTION_IA_TA        => 4;
use constant OPTION_IAADDR       => 5;
use constant OPTION_ORO          => 6;
use constant OPTION_PREFERENCE   => 7;
use constant OPTION_ELAPSED_TIME => 8;
use constant OPTION_RELAY_MSG    => 9;
### There is no option with the value of 10
use constant OPTION_AUTH          => 11;
use constant OPTION_UNICAST       => 12;
use constant OPTION_STATUS_CODE   => 13;
use constant OPTION_RAPID_COMMIT  => 14;
use constant OPTION_USER_CLASS    => 15;
use constant OPTION_VENDOR_CLASS  => 16;
use constant OPTION_VENDOR_OPTS   => 17;
use constant OPTION_INTERFACE_ID  => 18;
use constant OPTION_RECONF_MSG    => 19;
use constant OPTION_RECONF_ACCEPT => 20;
use constant OPTION_DNS_SERVERS   => 23;
use constant OPTION_DOMAIN_LIST   => 24;
use constant OPTION_CLIENT_FQDN   => 39;

our %OPTIONS_FILTER = (
    OPTION_CLIENTID()      => \&_parse_duid,
    OPTION_SERVERID()      => \&_parse_duid,
    OPTION_IA_NA()         => \&_parse_ia_na,
    OPTION_IA_TA()         => \&_parse_ia_ta,
    OPTION_IAADDR()        => \&_parse_iaaddr,
    OPTION_ORO()           => \&_parse_option_request_option,
    OPTION_PREFERENCE()    => \&_parse_preference,
    OPTION_ELAPSED_TIME()  => \&_parse_elapsed_time,
    OPTION_RELAY_MSG()     => \&decode_dhcpv6,
    OPTION_AUTH()          => \&_parse_auth,
    OPTION_UNICAST()       => \&_parse_unicast,
    OPTION_STATUS_CODE()   => \&_parse_status_code,
    OPTION_RAPID_COMMIT()  => \&_zero_length_option,
    OPTION_USER_CLASS()    => \&_parse_user_class,
    OPTION_VENDOR_CLASS()  => \&_parse_vendor_class,
    OPTION_VENDOR_OPTS()   => \&_parse_vendor_opts,
    OPTION_INTERFACE_ID()  => \&_parse_interface_id,
    OPTION_RECONF_MSG()    => \&_parse_reconf_msg,
    OPTION_RECONF_ACCEPT() => \&_zero_length_option,
    OPTION_DNS_SERVERS()   => \&_parse_dns_server,
    OPTION_DOMAIN_LIST()   => \&_parse_domain_list,
    OPTION_CLIENT_FQDN()   => \&_parse_client_fqdn,

);

=head2 decompose_dhcpv6

Parses a raw Ethernet frame and decompose it into layers and
returns every layer as objects (l2, l3, l4) or hashref (dhcp).

=cut

sub decompose_dhcpv6 {
    my ($raw_packet) = @_;

    my $l2   = NetPacket::Ethernet->decode($raw_packet);
    my $l3   = NetPacket::IPv6->decode($l2->{'data'});
    my $l4   = NetPacket::UDP->decode($l3->{'data'});
    my $dhcp = decode_dhcpv6($l4->{'data'});

    return ($l2, $l3, $l4, $dhcp);
}

sub decode_dhcpv6_options {
    my ($rest) = @_;
    my @options;
    while ($rest && length $rest > 0) {
        my ($type, $data);
        ($type, $data, $rest) = unpack("n n/a* a*", $rest);
        $data = $OPTIONS_FILTER{$type}->($data) if exists $OPTIONS_FILTER{$type};
        push @options, {type => $type, data => $data};
    }
    return \@options;
}

sub decode_dhcpv6 {
    my ($data) = @_;

    # Get the type (1 byte) and the rest of the data
    my ($type, $rest) = unpack("Ca*", $data);

    #Check for relay type of messages
    if ($type == RELAY_REPL || $type == RELAY_FORW) {
        my ($hop, @link, @peer, $options);

        # Get hop (1 byte) , link ipv6 addr (16 bytes or 4 32 bit numbers) , peer ipv6 addr (16 bytes or 4 32 bit numbers),
        # and the options (the rest of the packet)
        ($hop, @link[0 .. 3], @peer[0 .. 3], $options) = unpack("C N4 N4 a*", $rest);
        return {
            'type'    => $type,
            'hop'     => $hop,
            'link'    => NetPacket::IPv6::int_to_hexstr(@link),
            'peer'    => NetPacket::IPv6::int_to_hexstr(@peer),
            'options' => decode_dhcpv6_options($options)
        };
    }

    # Get the trans id (3 bytes) and the options (the rest of the packet)
    my ($tid, $options) = unpack("a3 a*", $rest);
    return {type => $type, options => decode_dhcpv6_options($options), tid => $tid};
}

=head2 _zero_length_option

For options that have zero length just return undef

=cut

sub _zero_length_option {undef}

=head2 _parse_duid

Parse a duid

=cut

sub _parse_duid {
    my ($data) = @_;
    return $data;
}

=head2 _parse_ia_na

=cut

sub _parse_ia_na {
    my ($data) = @_;
    my ($iaid, $t1, $t2, $options) = unpack("a4 N N a*", $data);
    return {iaid => $iaid, t1 => $t1, t2 => $t2, options => $options};
}

=head2 _parse_ia_ta

=cut

sub _parse_ia_ta {
    my ($data) = @_;
    my ($iaid, $options) = unpack("a4 a*", $data);
    return {iaid => $iaid, options => $options};
}

=head2 _parse_iaaddr

=cut

sub _parse_iaaddr {
    my ($data) = @_;
    my (@addr, $preferred_lifetime, $valid_lifetime, $options);
    (@addr[0 .. 3], $preferred_lifetime, $valid_lifetime, $options) = unpack("N4 N N a*", $data);
    return {
        addr               => NetPacket::IPv6::int_to_hexstr(@addr),
        preferred_lifetime => $preferred_lifetime,
        valid_lifetime     => $valid_lifetime,
        options            => $options
    };
}

=head2 _parse_option_request_option

=cut

sub _parse_option_request_option {
    my ($data) = @_;
    my @requested_options = unpack("n*", $data);
    return {requested_options => \@requested_options};
}

=head2 _parse_preference

=cut

sub _parse_preference {
    my ($data) = @_;
    return {'pref_value' => unpack("c", $data)};
}

=head2 _parse_elapsed_time

=cut

sub _parse_elapsed_time {
    my ($data) = @_;
    return {'elapsed_time' => unpack("n", $data)};
}

=head2 _parse_auth

=cut

sub _parse_auth {
    my ($data) = @_;
    my ($protocol, $algorithm, $RDM, $replay_detection, $information) = unpack("C C n Q a*", $data);
    return {
        protocol         => $protocol,
        algorithm        => $algorithm,
        RDM              => $RDM,
        replay_detection => $replay_detection,
        information      => $information
    };
}

=head2 _parse_unicast

=cut

sub _parse_unicast {
    my ($data) = @_;
    my @addr = unpack("N4", $data);
    return {'server_address' => NetPacket::IPv6::int_to_hexstr(@addr)};
}

=head2 _parse_status_code

=cut

sub _parse_status_code {
    my ($data) = @_;
    my ($status_code, $status_message) = unpack("n a*", $data);
    return {status_code => $status_code, status_message => $status_message};
}

=head2 _parse_user_class

=cut

sub _parse_user_class {
    my ($data) = @_;
    return {data => $data};
}

=head2 _parse_vendor_class

=cut

sub _parse_vendor_class {
    my ($data) = @_;
    my ($enterprise_number, $vdata) = unpack("N a*", $data);
    return {enterprise_number => $enterprise_number, data => $vdata};
}

=head2 _parse_vendor_opts

=cut

sub _parse_vendor_opts {
    my ($data) = @_;
    my ($enterprise_number, $vdata) = unpack("N a*", $data);
    return {enterprise_number => $enterprise_number, data => $vdata};
}

=head2 _parse_interface_id

=cut

sub _parse_interface_id {
    my ($data) = @_;
    return {interface_id => $data};
}

=head2 _parse_reconf_msg

=cut

sub _parse_reconf_msg {
    my ($data) = @_;
    return {type => unpack("C", $data)};
}

=head2 _parse_dns_server

=cut

sub _parse_dns_server {
    my ($data) = @_;
    my (@servers) = unpack("(a16)*", $data);
    @servers = map {NetPacket::IPv6::int_to_hexstr(unpack("N4", $_))} @servers;
    return {servers => \@servers};
}

=head2 _parse_domain_list

=cut

sub _parse_domain_list {
    my ($data) = @_;
    my (@domains) = unpack("Z*", $data);
    return { domains => \@domains};
}

=head2 _parse_client_fqdn

=cut

sub _parse_client_fqdn {
    my ($data) = @_;
    my ($flags, $fqdn) = unpack("c a*", $data);
    return {flags => $flags, fqdn => $fqdn};
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

