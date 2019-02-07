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
    our (@ISA, @EXPORT);
    @ISA    = qw(Exporter);
    @EXPORT = qw(decompose_dhcpv6 decode_dhcpv6);
}

use NetPacket::Ethernet;
use NetPacket::IPv6;
use NetPacket::UDP;
use bytes;
use pf::constants::dhcpv6 qw(:all);


## The parser maps for the options
##
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
    OPTION_DNS_SERVERS()   => \&_parse_ipv6_list,
    OPTION_DOMAIN_LIST()   => \&_parse_domain_list,
    OPTION_IA_PD()         => \&_parse_ia_pd,
    OPTION_IAPREFIX()      => \&_parse_ia_prefix,
    OPTION_CLIENT_FQDN()   => \&_parse_client_fqdn,
    OPTION_SIP_SERVER_D()  => \&_parse_domain_list,
    OPTION_SIP_SERVER_A()  => \&_parse_ipv6_list,
    OPTION_NIS_SERVERS()   => \&_parse_ipv6_list,
    OPTION_NISP_SERVERS()  => \&_parse_ipv6_list,
    OPTION_NIS_DOMAIN()    => \&_parse_client_fqdn,
    OPTION_NISP_DOMAIN()   => \&_parse_client_fqdn,
    OPTION_SNTP_SERVERS()  => \&_parse_ipv6_list,
    OPTION_INFO_REFRESH_TIME() => \&_parse_option_info_refresh_time,
    OPTION_BCMCS_SERVER_D()  => \&_parse_domain_list,
    OPTION_BCMCS_SERVER_A()  => \&_parse_ipv6_list,
    OPTION_GEOCONF_CIVIC()  => \&_parse_geoconf_civic,
    OPTION_REMOTE_ID()      => \&_parse_remote_id,
    OPTION_SUBSCRIBER_ID()  => \&_parse_subscriber_id,
    OPTION_NEW_POSIX_TIMEZONE() => \&_parse_new_posix_timezone,
    OPTION_NEW_TZDB_TIMEZONE() => \&_parse_new_tzdb_timezone,
    OPTION_ERO() => \&_parse_ero,
    OPTION_LQ_QUERY() => \&_parse_lq_query,
    OPTION_CLIENT_DATA() => \&_parse_client_data,
    OPTION_CLT_TIME() => \&_parse_clt_time,
    OPTION_LQ_RELAY_DATA() => \&_parse_lq_relay_data,
    OPTION_LQ_CLIENT_LINK() => \&_parse_ipv6_list,
    OPTION_PANA_AGENT()     => \&_parse_ipv6_list,
    OPTION_V6_LOST()        => \&_parse_client_fqdn,

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

=head2 decode_dhcpv6_options

Decoded the dhcpv6 options into an array of hashes

=cut

sub decode_dhcpv6_options {
    my ($rest) = @_;
    my @options;
    while ($rest && length $rest > 0) {
        my %option;
        my ($type, $data);
        ($type, $data, $rest) = unpack("n n/a* a*", $rest);
        if( exists $OPTIONS_FILTER{$type} ) {
            my $option_data = $OPTIONS_FILTER{$type}->($data);
            #Copy all the data into the option hash
            %option = %$option_data;
        } else {
            #No filter then you get it raw
            $option{option_raw_data} = $data;
        }
        $option{option_type} = $type;
        push @options, \%option;
    }
    return \@options;
}

=head2 decode_dhcpv6

Decodes the dhcpv6 packet into a hash representation

=cut

sub decode_dhcpv6 {
    my ($data) = @_;

    # Get the type (1 byte) and the rest of the data
    my ($type, $rest) = unpack("Ca*", $data);

    #Check for relay type of messages
    if ($type == RELAY_REPL || $type == RELAY_FORW) {

        # Get hop (1 byte) , link ipv6 addr (16 bytes) , peer ipv6 addr (16 bytes),
        # and the options (the rest of the packet)
        my ($hop, $link, $peer, $options) = unpack("C a16 a16 a*", $rest);
        return {
            'msg_type'    => $type,
            'hop'     => $hop,
            'link'    => _parse_ipv6_addr($link),
            'peer'    => _parse_ipv6_addr($peer),
            'options' => decode_dhcpv6_options($options)
        };
    }

    # Get the trans id (3 bytes) and the options (the rest of the packet)
    my ($tid, $options) = unpack("a3 a*", $rest);
    return {msg_type => $type, options => decode_dhcpv6_options($options), tid => $tid};
}

sub _parse_ipv6_addr {
    my ($data) = @_;
    my @ints = unpack("N4", $data);
    return NetPacket::IPv6::int_to_hexstr(@ints);
}

sub _hex_data {
    my ($data) = @_;
    return join(":",unpack "(H2)*", $data);
}

=head2 _zero_length_option

For options that have zero length just return an empty hash

=cut

sub _zero_length_option { {} }

our %DUID_FILTERS = (
    1 => \&_parse_duid_type1,
    2 => \&_parse_duid_type2,
    3 => \&_parse_duid_type3,
    4 => \&_parse_duid_type4,
);

=head2 _parse_duid_type1

=cut

sub _parse_duid_type1 {
    my ($type, $data) = @_;
    my ($hardware_type, $time,$addr) = unpack("n N a*", $data);
    return {duid_type => $type, hardware_type => $hardware_type, 'time' => $time, addr => _hex_data($addr)};
}

=head2 _parse_duid_type2

=cut

sub _parse_duid_type2 {
    my ($type, $data) = @_;
    my ($enterprise_number, $id) = unpack("N a*", $data);
    return {duid_type => $type, enterprise_number => $enterprise_number, id => $id};
}

=head2 _parse_duid_type3

=cut

sub _parse_duid_type3 {
    my ($type, $data) = @_;
    my ($hardware_type, $addr) = unpack("n a*", $data);
    return {duid_type => $type, hardware_type => $hardware_type, addr => _hex_data($addr)};
}

=head2 _parse_duid_type4

=cut

sub _parse_duid_type4 {
    my ($type, $data) = @_;
    return {duid_type => $type, uuid => $data};
}

=head2 _parse_duid

Parse a duid

=cut

sub _parse_duid {
    my ($data) = @_;
    my ($type, $rest) = unpack("n a*",$data);
    return $DUID_FILTERS{$type}->($type, $rest) if exists $DUID_FILTERS{$type};
    return { duid_type => $type, duid_raw_data => $data};
}

=head2 _parse_ia_na

=cut

sub _parse_ia_na {
    my ($data) = @_;
    my ($iaid, $t1, $t2, $options) = unpack("a4 N N a*", $data);
    return {iaid => $iaid, t1 => $t1, t2 => $t2, options => decode_dhcpv6_options($options)};
}

=head2 _parse_ia_ta

=cut

sub _parse_ia_ta {
    my ($data) = @_;
    my ($iaid, $options) = unpack("a4 a*", $data);
    return {iaid => $iaid, options => decode_dhcpv6_options($options)};
}

=head2 _parse_iaaddr

=cut

sub _parse_iaaddr {
    my ($data) = @_;
    my ($addr, $preferred_lifetime, $valid_lifetime, $options)  = unpack("a16 N N a*", $data);
    return {
        addr               => _parse_ipv6_addr($addr),
        preferred_lifetime => $preferred_lifetime,
        valid_lifetime     => $valid_lifetime,
        options            => decode_dhcpv6_options($options)
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
    return {'server_address' => _parse_ipv6_addr($data)};
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
    my ($enterprise_number, @vdata) = unpack("N (n/a*)*", $data);

    return {enterprise_number => $enterprise_number, data => \@vdata};
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

=head2 _parse_domain_list

=cut

sub _parse_domain_list {
    my ($data) = @_;
    my @domains = map { _parse_domainname($_) } unpack("Z*", $data);
    return { domains => \@domains};
}

=head2 _parse_ia_pd

=cut

sub _parse_ia_pd {
    my ($data) = @_;
    my ($iaid,$t1,$t2,$options) = unpack("a4 N N a*", $data);
    return {iaid => $iaid, t1 => $t1, t2 => $t2,options => decode_dhcpv6_options($options)};
}

=head2 _parse_ia_prefix

=cut

sub _parse_ia_prefix {
    my ($data) = @_;
    my ($preferred_lifetime, $valid_lifetime, $prefix_length, $prefix, $options) = unpack("N N C a16 a*", $data);
    return {
        preferred_lifetime => $preferred_lifetime,
        valid_lifetime     => $valid_lifetime,
        prefix_length      => $prefix_length,
        prefix             => _parse_ipv6_addr($prefix),
        options            => decode_dhcpv6_options($options)
    };
}

=head2 _parse_client_fqdn

=cut

sub _parse_client_fqdn {
    my ($data) = @_;
    my ($flags, $fqdn) = unpack("c a*", $data);
    my $full = 0;
    if ($fqdn =~ s/\0$//) {
        $full = 1;
    }
    return {flags => $flags, fqdn => _parse_domainname($fqdn), full => $full };
}

=head2 _parse_domainname

=cut

sub _parse_domainname {
    my ($data) = @_;
    return join('.', unpack("(c/a*)*", $data));
}


=head2 _parse_ipv6_list

=cut

sub _parse_ipv6_list {
    my ($data) = @_;
    return { ipv6_addresses =>  [map { _parse_ipv6_addr($_) } unpack("(a16)*",$data) ] };
}

=head2 _parse_option_info_refresh_time

=cut

sub _parse_option_info_refresh_time {
    my ($data) = @_;
    return { information_refresh_time => unpack("N", $data) };
}

=head2 _parse_geoconf_civic

=cut

sub _parse_geoconf_civic {
    my ($data) = @_;
    my ($what,$cc,@elements) = unpack("C a2 (C C/a*)*");
    return {what => $what, cc => $cc, elements => \@elements};
}

=head2 _parse_subscriber_id

=cut

sub _parse_subscriber_id {
    my ($data) = @_;
    return {subscriber_id => $data};
}

=head2 _parse_remote_id

=cut

sub _parse_remote_id {
    my ($data) = @_;
    my ($enterprise_number, $remote_id) = unpack("N a*",$data);
    return {enterprise_number => $enterprise_number, remote_id => $remote_id};
}

=head2 _parse_new_posix_timezone

=cut

sub _parse_new_posix_timezone {
    my ($data) = @_;
    return { tz_posix => $data } ;
}

=head2 _parse_new_tzdb_timezone

=cut

sub _parse_new_tzdb_timezone {
    my ($data) = @_;
    return { tzname => $data };
}

=head2 _parse_ero

=cut

sub _parse_ero {
    my ($data) = @_;
    return { echo_options => [unpack("S*",$data)] } ;
}

=head2 _parse_lq_query

=cut

sub _parse_lq_query {
    my ($data) = @_;
    my ($type,$link, $options) = unpack("c a16 a*");
    return {
        query_type => $type,
        link_addr  => _parse_ipv6_addr($link),
        query_options    => decode_dhcpv6_options($options)
    };
}

=head2 _parse_client_data

=cut

sub _parse_client_data {
    my ($data) = @_;
    return { client_options => decode_dhcpv6_options($data) };
}

=head2 _parse_clt_time

=cut

sub _parse_clt_time {
    my ($data) = @_;
    return { clt_time => unpack("N", $data) };
}

=head2 _parse_lq_relay_data

=cut

sub _parse_lq_relay_data {
    my ($data) = @_;
    my ($link, $relay_message) = unpack("c a16 a*");
    return {
        peer_address => _parse_ipv6_addr($link),
        dhcp_relay_message => decode_dhcpv6($relay_message),
    };
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

