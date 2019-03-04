#!/usr/bin/perl

=head1 NAME

replay-pcap

=head1 SYNOPSIS

replay-pcap -i <interface> -p <pcap_file>

 Options:
   -i <interface>     The interface
   -p <pcap_file>     The path to the pcap file
   -h                 Display this help

=cut

=head1 DESCRIPTION

replay-pcap

Will replay a pcap to simulate pfdhcplistener traffic

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::dhcp::processor_v4();
use pf::dhcp::processor_v6();
use pf::util::dhcpv6();
use pf::client;
pf::client::setClient("pf::api::can_fork");
use NetPacket::Ethernet;
use NetPacket::UDP;
use Getopt::Long;
use pf::log;
use NetPacket::Ethernet qw(ETH_TYPE_IP);
use NetPacket::IP;
use NetPacket::IPv6;
use NetPacket::UDP;
use pf::constants qw($TRUE);
use pf::config qw(%Config @listen_ints @dhcplistener_ints $NO_VLAN %ConfigNetworks @inline_enforcement_nets);
use NetAddr::IP;
use Net::Pcap qw(pcap_open_offline pcap_loop);
use Pod::Usage;
use List::MoreUtils qw(any);
use pf::util;
use pf::node;
use pf::fingerbank;
use pf::api;
my %options;
GetOptions(\%options, "interface|i=s", "pcap|p=s", "help|h") or die("Error in command line arguments\n");

pod2usage( -verbose => 1 ) if $options{help} || !(defined $options{interface} && defined $options{pcap} );

start_processing($options{interface}, $options{pcap});


sub start_processing {
    my ($interface, $filename) = @_;
    my $logger = get_logger();
    my ($net_type, $interface_ip, $interface_vlan, $is_inline_vlan);
    my $net_addr = NetAddr::IP->new($Config{"interface $interface"}{'ip'},$Config{"interface $interface"}{'mask'});
    my %user_data = (interface => $interface);
    if (any {$_ eq $interface} @listen_ints, @dhcplistener_ints) {
        $user_data{net_type}       = $Config{"interface $interface"}{'type'};
        $user_data{interface_ip}   = $Config{"interface $interface"}{'ip'};
        $user_data{interface_vlan} = get_vlan_from_int($interface) || $NO_VLAN;
        foreach my $network (keys %ConfigNetworks) {
            my %net = %{$ConfigNetworks{$network}};
            my $network_obj = NetAddr::IP->new($network, $ConfigNetworks{$network}{netmask});

            # are we listening on an inline interface ?
            next if (!pf::config::is_network_type_inline($network));
            my $ip = new NetAddr::IP::Lite clean_ip($net{'next_hop'}) if defined($net{'next_hop'});
            if (grep({$_->tag("int") eq $interface} @inline_enforcement_nets) != 0
                || (defined($net{'next_hop'}) && $net_addr->contains($ip)))
            {
                $logger->warn("DHCP detector on an inline interface");
                $user_data{is_inline_vlan} = $TRUE;
            }
        }
        $logger->info("DHCP detector on $interface enabled");
        my $err;
        my $pcap = pcap_open_offline($filename, \$err)
          or die "Can't read '$filename': $err\n";
        my $value = pcap_loop($pcap, -1, \&process_pkt, \%user_data);
    }
}

sub process_pkt {
    my ( $user_data, $hdr, $pkt ) = @_;
    eval {
        my $l2 = NetPacket::Ethernet->decode($pkt);
        my $l3 = $l2->{type} eq ETH_TYPE_IP ? NetPacket::IP->decode($l2->{'data'}) : NetPacket::IPv6->decode($l2->{'data'});
        my $l4 = NetPacket::UDP->decode($l3->{'data'});
        my %args = (
            src_mac => clean_mac($l2->{'src_mac'}),
            dest_mac => clean_mac($l2->{'dest_mac'}),
            src_ip => $l3->{'src_ip'},
            dest_ip => $l3->{'dest_ip'},
            is_inline_vlan => $user_data->{is_inline_vlan},
            interface => $user_data->{interface},
            interface_ip => $user_data->{interface_ip},
            interface_vlan => $user_data->{interface_vlan},
            net_type => $user_data->{net_type},
            udp_payload => $l4->{data},
        );
        # we send all IPv4 DHCPv4 codepath
        if($l2->{type} eq ETH_TYPE_IP) {
            pf::dhcp::processor_v4->new(%args)->process_packet();
        } else {
            #ignore for now
            process_dhcpv6("pf::api", $l4->{data});
        }
    };
    if($@) {
        get_logger->error("Error processing packet: $@");
    }
}

sub process_dhcpv6 {
    my ( $class, $udp_payload ) = @_;
    my $logger = pf::log::get_logger();

    my $dhcpv6 = pf::util::dhcpv6::decode_dhcpv6($udp_payload);

    # these are relaying packets.
    # in that case we take the inner part
    if($dhcpv6->{msg_type} eq 12 || $dhcpv6->{msg_type} eq 13){
        $logger->debug("Found relaying packet. Taking inner request/reply from it.");
        $dhcpv6 = $dhcpv6->{options}->[0];
    }

    # we are only interested in solicits for the fingerprint and enterprise ID
    if($dhcpv6->{msg_type} ne 1){
        $logger->debug("Skipping DHCPv6 packet because it's not a solicit.");
        return;
    }

    my ($mac_address, $dhcp6_enterprise, $dhcp6_fingerprint) = (undef, '', '');
    foreach my $option (@{$dhcpv6->{options}}){
        if(defined($option->{enterprise_number})){
            $dhcp6_enterprise = $option->{enterprise_number};
            $logger->debug("Found DHCPv6 enterprise ID '$dhcp6_enterprise'");
        }
        elsif(defined($option->{requested_options})){
            $dhcp6_fingerprint = join ',', @{$option->{requested_options}};
            $logger->debug("Found DHCPv6 fingerprint '$dhcp6_fingerprint'");
        }
        elsif(defined($option->{addr})){
            $mac_address = $option->{addr};
            $logger->debug("Found DHCPv6 link address (MAC) '$mac_address'");
        }
    }
    Log::Log4perl::MDC->put('mac', $mac_address);
    $logger->trace("Found DHCPv6 packet with fingerprint '$dhcp6_fingerprint' and enterprise ID '$dhcp6_enterprise'.");

    my %fingerbank_query_args = (
        mac                 => $mac_address,
        dhcp6_fingerprint   => $dhcp6_fingerprint,
        dhcp6_enterprise    => $dhcp6_enterprise,
    );

    pf::fingerbank::process(\%fingerbank_query_args);

    pf::node::node_modify($mac_address, dhcp6_fingerprint => $dhcp6_fingerprint, dhcp6_enterprise => $dhcp6_enterprise);
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

