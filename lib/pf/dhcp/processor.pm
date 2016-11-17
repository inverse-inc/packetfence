package pf::dhcp::processor;

=head1 NAME

pf::dhcp::processor

=cut

=head1 DESCRIPTION

Processes DHCP packets

=cut

use strict;
use warnings;

use Try::Tiny;
use pf::client;
use pf::constants;
use pf::constants::dhcp qw($DEFAULT_LEASE_LENGTH);
use pf::clustermgmt;
use pf::config qw(
    $INLINE_API_LEVEL
    %ConfigNetworks
    %Config
    @inline_nets
    $NO_VOIP
    $NO_PORT
    %connection_type_to_str
    $INLINE
);
use pf::config::cached;
use pf::db;
use pf::firewallsso;
use pf::inline::custom $INLINE_API_LEVEL;
use pf::iplog;
use pf::lookup::node;
use pf::node;
use pf::util;
use pf::config::util;
use pf::services::util;
use pf::util::dhcp;
use List::MoreUtils qw(any);
use pf::api::jsonrpcclient;
use NetAddr::IP;
use pf::SwitchFactory;
use pf::log;
use pf::StatsD::Timer;
use pf::Redis;
use pf::CHI;
use pf::locationlog;
use DateTime::Format::MySQL;
use pf::parking;
use pf::cluster;
use pf::dhcp_option82 qw(dhcp_option82_insert_or_update);

our $logger = get_logger;
my $ROGUE_DHCP_TRIGGER = '1100010';
my @local_dhcp_servers_mac;
my @local_dhcp_servers_ip;

#
# This lua script appends an offer comment to a list for the rogue DHCP server
# If the length of the list exceeds the threshold, the list is emptied and its content returned
# It is called like the following
# EVAL LUA_ROGUE_DHCP_APPEND 0 ROGUE_DHCP_IP COMMENT THRESHOLD
#
our $LUA_ROGUE_DHCP_APPEND = <<EOS ;
    local key_name = "rogue_dhcp_servers_"..ARGV[1];
    redis.call("RPUSH",key_name,ARGV[2]);
    local rogue_dhcp_servers_detected = redis.call("LLEN",key_name);
    if tonumber(rogue_dhcp_servers_detected) >= tonumber(ARGV[3]) then
        local elements = redis.call("LRANGE",key_name,0,rogue_dhcp_servers_detected);
        redis.call("DEL", key_name)
        return elements
    end
    return {}
EOS

our $LUA_ROGUE_DHCP_SHA1;

=head2 new

Create a new DHCP processor

=cut

sub new {
    my ( $class, %argv ) = @_;
    my $self = bless {}, $class;
    foreach my $attr (keys %argv){
        $self->{$attr} = $argv{$attr};
    }
    if($self->{is_inline_vlan}){
        $self->{accessControl} = new pf::inline::custom();
    }
    $self->{api_client} = pf::client::getClient();
    $self->_build_DHCP_networks();
    return $self;
}

=head2 _build_DHCP_networks

Builds the list of networks on which PacketFence is the DHCP server

=cut

sub _build_DHCP_networks {
    my ($self) = @_;

    my @dhcp_networks;
    foreach my $network (keys %ConfigNetworks) {
        my %net = %{$ConfigNetworks{$network}};
        my $network_obj = NetAddr::IP->new($network,$ConfigNetworks{$network}{netmask});
        if(isenabled($net{dhcpd})){
            push @dhcp_networks, $network_obj;
        }
    }

    $self->{dhcp_networks} = \@dhcp_networks;
}

=head2 _get_redis_client

Get the redis client

=cut

sub _get_redis_client {
    my ($self) = @_;
    if($self->{redis_client}){
        return $self->{redis_client};
    }
    else {
        my $config = pf::CHI::get_redis_config();
        $self->{redis_client} = pf::Redis->new(%$config, on_connect => \&_on_redis_connect);
        return $self->{redis_client};
    }
}


=head2 process_packet

Process a packet

=cut

sub process_packet {
    my $timer = pf::StatsD::Timer->new();
    my ( $self ) = @_;

    my $dhcp = $self->{dhcp};

    if ( !node_exist($dhcp->{'chaddr'}) ) {
        $logger->debug( sub { "Unseen before node added: $dhcp->{'chaddr'}" } );
        node_add_simple($dhcp->{'chaddr'});
    }

    # opcode 1 = request, opcode 2 = reply

    # Option 53: DHCP Message Type (RFC2132)
    # Value   Message Type
    # -----   ------------
    #   1     DHCPDISCOVER
    #   2     DHCPOFFER
    #   3     DHCPREQUEST
    #   4     DHCPDECLINE
    #   5     DHCPACK
    #   6     DHCPNAK
    #   7     DHCPRELEASE
    #   8     DHCPINFORM

    if ( $dhcp->{'op'} == 2 ) {
        $self->parse_dhcp_offer($dhcp) if ( $dhcp->{'options'}{'53'} == 2 );

        $self->parse_dhcp_ack($dhcp) if ( $dhcp->{'options'}{'53'} == 5 );

    } elsif ( $dhcp->{'op'} == 1 ) {

        # returning on Discover in order to avoid some unnecessary work (we expect clients to do a dhcp request anyway)
        return $self->parse_dhcp_discover($dhcp) if ( $dhcp->{'options'}{'53'} == 1 );

        $self->parse_dhcp_request($dhcp) if ( $dhcp->{'options'}{'53'} == 3 );

        return $self->parse_dhcp_release($dhcp) if ( $dhcp->{'options'}{'53'} == 7 );

        return $self->parse_dhcp_inform($dhcp) if ( $dhcp->{'options'}{'53'} == 8 );

        # Option 82 Relay Agent Information (RFC3046)
        if ( isenabled( $Config{'network'}{'dhcpoption82logger'} ) && defined( $dhcp->{'options'}{'82'} ) ) {
            $self->parse_dhcp_option82($dhcp);
        }

        # updating the node first
        # in case the fingerprint generates a violation and that autoreg uses fingerprint to auto-categorize nodes
        # see #1216 for details
        my %tmp;
        $tmp{'dhcp_fingerprint'} = defined($dhcp->{'options'}{'55'}) ? $dhcp->{'options'}{'55'} : '';
        $tmp{'dhcp_vendor'} = defined($dhcp->{'options'}{'60'}) ? $dhcp->{'options'}{'60'} : '';
        $tmp{'last_dhcp'} = mysql_date();
        if (defined($dhcp->{'options'}{'12'})) {
            $tmp{'computername'} = $dhcp->{'options'}{'12'};
            if(isenabled($Config{network}{hostname_change_detection})){
                $self->{api_client}->notify('detect_computername_change', $dhcp->{'chaddr'}, $tmp{'computername'});
            }
        }

        node_modify( $dhcp->{'chaddr'}, %tmp );

        # Fingerbank interaction
        my %fingerbank_query_args = (
            dhcp_fingerprint    => $tmp{'dhcp_fingerprint'},
            dhcp_vendor         => $tmp{'dhcp_vendor'},
            mac                 => $dhcp->{'chaddr'},
            computer_name       => $tmp{'computername'},
        );

        # When listening on the mgmt interface, we can't rely on yiaddr as we only see requests
        my $ip = ($dhcp->{'yiaddr'} ne "0.0.0.0") ? $dhcp->{'yiaddr'} : $dhcp->{'options'}{'50'};
        $fingerbank_query_args{'ip'} = $ip if defined($ip);

        $self->{api_client}->notify('fingerbank_process', \%fingerbank_query_args );

        $logger->debug( sub {
            my $modified_node_log_message = '';
            while(my ($k, $v) = each %tmp) {
                $modified_node_log_message .= "$k = $v,";
            }
            chop($modified_node_log_message);
            "$dhcp->{'chaddr'} requested an IP with the following informations: $modified_node_log_message"
        });
    } else {
        $logger->debug( sub { "unrecognized DHCP opcode from $dhcp->{'chaddr'}: $dhcp->{op}" });
    }
}

=head2 parse_dhcp_discover

=cut

sub parse_dhcp_discover {
    my ($self, $dhcp) = @_;
    $logger->debug("DHCPDISCOVER from $dhcp->{'chaddr'}");
}

=head2 parse_dhcp_offer

=cut

sub parse_dhcp_offer {
    my $timer = pf::StatsD::Timer->new({level => 7});
    my ($self, $dhcp) = @_;

    if ($dhcp->{'yiaddr'} =~ /^0\.0\.0\.0$/) {
        $logger->warn("DHCPOFFER invalid IP in DHCP's yiaddr for $dhcp->{'chaddr'}");
        return;
    }

    $logger->info("DHCPOFFER from $dhcp->{src_ip} ($dhcp->{src_mac}) to host $dhcp->{'chaddr'} ($dhcp->{yiaddr})");

    $self->rogue_dhcp_handling($dhcp->{'src_ip'}, $dhcp->{'src_mac'}, $dhcp->{'yiaddr'}, $dhcp->{'chaddr'}, $dhcp->{'giaddr'});
}

=head2 parse_dhcp_request

=cut

sub parse_dhcp_request {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ($self, $dhcp) = @_;
    $logger->debug("DHCPREQUEST from $dhcp->{'chaddr'}");

    my $lease_length = $dhcp->{'options'}{'51'};
    my $client_ip = $dhcp->{'options'}{'50'};
    my $client_mac;
    if (defined($client_ip) && $client_ip !~ /^0\.0\.0\.0$/) {
        $logger->info(
            "DHCPREQUEST from $dhcp->{'chaddr'} ($client_ip)"
            . ( defined($lease_length) ? " with lease of $lease_length seconds" : "")
        );
        $client_mac = $dhcp->{'chaddr'};
    }
    unless (defined($client_ip) && defined($client_mac)) { 
        $logger->debug("Undefined client IP or client MAC. Not acting on DHCPREQUEST");
        return undef;
    }
    

    # We check if we are running without dhcpd
    # This means we don't see ACK so we need to act on requests
    if( !$self->pf_is_dhcp($client_ip) && 
        !isenabled($Config{network}{force_listener_update_on_ack}) ){
        $self->handle_new_ip($client_mac, $client_ip, $lease_length);
    }

    # As per RFC2131 in a DHCPREQUEST if ciaddr is set and we broadcast, we are in re-binding state
    # in which case we are not interested in detecting rogue DHCP
    if ($dhcp->{'ciaddr'} !~ /^0\.0\.0\.0$/) {
        $self->rogue_dhcp_handling($dhcp->{'options'}{54}, undef, $client_ip, $dhcp->{'chaddr'}, $dhcp->{'giaddr'});
    }

    if ($self->{is_inline_vlan}) {
        $self->{api_client}->notify('synchronize_locationlog',$self->{interface_ip},$self->{interface_ip},undef, $NO_PORT, $self->{interface_vlan}, $dhcp->{'chaddr'}, $NO_VOIP, $INLINE, $self->{inline_sub_connection_type});
        $self->{accessControl}->performInlineEnforcement($dhcp->{'chaddr'});
    }
    else {
        $logger->debug("Not acting on DHCPREQUEST");
    }
}


=head2 parse_dhcp_ack

=cut

sub parse_dhcp_ack {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ($self, $dhcp) = @_;

    my $s_ip = $dhcp->{'src_ip'};
    my $s_mac = $dhcp->{'src_mac'};
    my $lease_length = $dhcp->{'options'}->{'51'};

    my $client_ip;
    my $client_mac;

    if ($dhcp->{'yiaddr'} !~ /^0\.0\.0\.0$/) {
        $logger->info(
            "DHCPACK from $s_ip ($s_mac) to host $dhcp->{'chaddr'} ($dhcp->{yiaddr})"
            . ( defined($lease_length) ? " for $lease_length seconds" : "" )
        );
        $client_ip = $dhcp->{'yiaddr'};
        $client_mac = $dhcp->{'chaddr'};
    }
    elsif ($dhcp->{'ciaddr'} !~ /^0\.0\.0\.0$/) {

        $logger->info(
            "DHCPACK CIADDR from $s_ip ($s_mac) to host $dhcp->{'chaddr'} ($dhcp->{ciaddr})"
            . ( defined($lease_length) ? " for $lease_length seconds" : "")
        );
        $client_ip = $dhcp->{'ciaddr'};
        $client_mac = $dhcp->{'chaddr'};
    }
    else {
        $logger->warn(
            "invalid DHCPACK from $s_ip ($s_mac) to host $dhcp->{'chaddr'} [$dhcp->{yiaddr} - $dhcp->{ciaddr}]"
        );
    }
    unless (defined($client_ip) && defined($client_mac)) { 
        $logger->debug("Undefined client IP or client MAC. Not acting on DHCPACK");
        return undef;
    }

    # We check if we are running with the DHCPd process.
    # If yes, we are interested with the ACK
    # Packet also has to be valid
    if( $self->pf_is_dhcp($client_ip) || 
        isenabled $Config{network}{force_listener_update_on_ack} ){
        $self->handle_new_ip($client_mac, $client_ip, $lease_length);
    }
    else {
        $logger->debug("Not acting on DHCPACK");
    }

}

=head2 pf_is_dhcp

Verifies if PacketFence is the DHCP server for the network the IP is in

=cut

sub pf_is_dhcp {
    my ($self, $client_ip) = @_;

    foreach my $network_obj (@{$self->{dhcp_networks}}) {
        # We need to rebuild it everytime with the mask from the network as
        # a DHCPREQUEST does not contain the subnet mask
        my $net_addr = NetAddr::IP->new($client_ip,$network_obj->mask);
        if($network_obj->contains($net_addr)){
            $logger->info("The listener process is on the same server as the DHCP server.");
            return $TRUE;
        }
    }
    $logger->info("The listener process is NOT on the same server as the DHCP server.");
    return $FALSE;
}

=head2 handle_new_ip

Handle the tasks related to a device getting an IP address

=cut

sub handle_new_ip {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ($self, $client_mac, $client_ip, $lease_length) = @_;
    $logger->info("Updating iplog and SSO for $client_mac -> $client_ip");
    $self->update_iplog( $client_mac, $client_ip, $lease_length );

    $self->check_for_parking($client_mac, $client_ip);

    my %data = (
       'ip' => $client_ip,
       'mac' => $client_mac,
       'net_type' => $self->{net_type},
    );
    $self->{api_client}->notify('trigger_scan', %data );
    my $firewallsso = pf::firewallsso->new;
    $firewallsso->do_sso('Update', $client_mac, $client_ip, $lease_length || $DEFAULT_LEASE_LENGTH);
}

=head2 check_for_parking

Check if a device should be in parking and adjust the lease time through OMAPI

=cut

sub check_for_parking {
    my ($self, $client_mac, $client_ip) = @_;

    unless(defined($Config{parking}{threshold}) && $Config{parking}{threshold}){
        get_logger->trace("Not parking threshold configured, so will not try to do parking detection");
        return;
    }

    get_logger->debug("Checking if $client_mac is in parking state");

    my $node = node_view($client_mac);

    if($node->{status} eq $STATUS_REGISTERED){
        get_logger->debug("Not checking parking for $client_mac since the node is registered");
        return;
    }

    my @locationlogs = locationlog_history_mac($client_mac);
    my $locationlog;
    # Trying the oldest locationlog entry that contains the same role as the
    # current one
    foreach my $entry (@locationlogs){
        unless(defined($locationlog)){
            $locationlog = $entry;
        }
        else {
            if($entry->{role} eq $locationlog->{role}){
                 $locationlog = $entry;
            }
            else {
                last;
            }
        }
    }

    unless(defined($locationlog)){
        get_logger->warn("Couldn't find any locationlog entry for $client_mac");
        return;
    }

    get_logger->info("Found locationlog entry with role : with start date ".$locationlog->{start_time});
    my $time = DateTime::Format::MySQL->parse_datetime($locationlog->{'start_time'});
    $time->set_time_zone("local");
    my $now = DateTime->now(time_zone => "local");
    if (($now->epoch - $time->epoch) > $Config{parking}{threshold}) {
        my $diff = $now->epoch - $time->epoch;
        $logger->debug("Current connection type : ".$locationlog->{connection_type});
        my $connection = pf::Connection->new();
        $connection->_stringToAttributes($locationlog->{connection_type});
        # This doesn't work against SNMP as there is no reauthentication, so
        # the locationlog entries will always be old.
        unless( $connection->isSNMP() ){
            $logger->warn("$client_mac STUCK on the registration role for $diff seconds $client_ip. Triggering parking violation");
            pf::parking::trigger_parking($client_mac, $client_ip);
        }
        else {
            $logger->debug("Cannot trigger parking for $client_mac as it is connected via SNMP enforcement.");
        }
    }

}

=head2 parse_dhcp_release

=cut

sub parse_dhcp_release {
    my $timer = pf::StatsD::Timer->new({level => 7});
    my ($self, $dhcp) = @_;
    $logger->debug("DHCPRELEASE from $dhcp->{'chaddr'} ($dhcp->{ciaddr})");
    $self->{api_client}->notify('close_iplog',$dhcp->{'ciaddr'});
}

=head2 parse_dhcp_inform

=cut

sub parse_dhcp_inform {
    my ($self, $dhcp) = @_;
    $logger->debug("DHCPINFORM from $dhcp->{'chaddr'} ($dhcp->{ciaddr})");
}

=head2 rogue_dhcp_handling

Requires DHCP Server IP

Optional but very useful DHCP Server MAC

=cut

sub rogue_dhcp_handling {
    my $timer = pf::StatsD::Timer->new({level => 7});
    my ($self, $dhcp_srv_ip, $dhcp_srv_mac, $offered_ip, $client_mac, $relay_ip) = @_;

    return if (isdisabled($Config{'network'}{'rogue_dhcp_detection'}));

    # if server ip is empty, it means that the client is asking for it's old IP and this should be legit
    if (!defined($dhcp_srv_ip)) {
        $logger->debug(
            "received empty DHCP Server IP in rogue detection. " .
            "Offered IP: " . ( defined($offered_ip) ? $offered_ip : 'unknown' )
        );
        return;
    }

    # ignore local DHCP servers
    return if ( grep({$_ eq $dhcp_srv_ip} get_local_dhcp_servers_by_ip()) );
    if ( defined($dhcp_srv_mac) ) {
        return if ( grep({$_ eq $dhcp_srv_mac} get_local_dhcp_servers_by_mac()) );
    }

    # ignore whitelisted DHCP servers
    return if ( grep({$_ eq $dhcp_srv_ip} split(/\s*,\s*/, $Config{'general'}{'dhcpservers'})) );

    my $rogue_offer = sprintf( "%s: %15s to %s on interface %s", mysql_date(), $offered_ip, $client_mac, $self->{interface} );
    if (defined($relay_ip) && $relay_ip !~ /^0\.0\.0\.0$/) {
        $rogue_offer .= " received via relay $relay_ip";
    }
    $rogue_offer .= "\n";
    my $previous_offers = $self->add_rogue_dhcp($dhcp_srv_ip, $rogue_offer, $Config{'network'}{'rogueinterval'});

    # if I have a MAC use it, otherwise look it up
    $dhcp_srv_mac = pf::iplog::ip2mac($dhcp_srv_ip) if (!defined($dhcp_srv_mac));
    if ($dhcp_srv_mac) {
        my %data = (
           'mac' => $dhcp_srv_mac,
           'tid' => $ROGUE_DHCP_TRIGGER,
           'type' => 'INTERNAL',
        );
        $self->{api_client}->notify('trigger_violation', %data );
    } else {
        $logger->info("Unable to find MAC based on IP $dhcp_srv_ip for rogue DHCP server");
        $dhcp_srv_mac = 'unknown';
    }

    $logger->warn("$dhcp_srv_ip ($dhcp_srv_mac) was detected offering $offered_ip to $client_mac on ".$self->{interface});
    if (@$previous_offers) {
        my %rogue_message;
        $rogue_message{'subject'} = "ROGUE DHCP SERVER DETECTED AT $dhcp_srv_ip ($dhcp_srv_mac) ON ".$self->{interface}."\n";
        $rogue_message{'message'} = '';
        if ($dhcp_srv_mac ne 'unknown') {
            $rogue_message{'message'} .= pf::lookup::node::lookup_node($dhcp_srv_mac) . "\n";
        }
        $rogue_message{'message'} .= "Detected Offers\n---------------\n";
        while ( @$previous_offers ) {
            $rogue_message{'message'} .= pop( @$previous_offers );
        }
        $rogue_message{'message'} .=
            "\n\nIf this DHCP Server is legitimate, make sure to add it to the dhcpservers list under General.\n"
        ;
        pfmailer(%rogue_message);
    }
}

=head2 _on_redis_connect

To execute when connecting to redis
Allows to install the Lua script for the rogue DHCP

=cut

sub _on_redis_connect {
    my ($redis) = @_;
    if($LUA_ROGUE_DHCP_SHA1) {
        my ($loaded) = $redis->script('EXISTS',$LUA_ROGUE_DHCP_SHA1);
        return if $loaded;
    }
    ($LUA_ROGUE_DHCP_SHA1) = $redis->script('LOAD',$LUA_ROGUE_DHCP_APPEND);
}

=head2 add_rogue_dhcp

Save a rogue DHCP, along with it's offer
If the amount of offers detected exceeds the threshold, they are returned.
Otherwise, an empty array is returned

=cut

sub add_rogue_dhcp {
    my ($self, $rogue_dhcp, $offer, $threshold) = @_;
    my $redis = $self->_get_redis_client;
    _on_redis_connect($redis);
    my @offers = $redis->evalsha($LUA_ROGUE_DHCP_SHA1, 0, $rogue_dhcp, $offer, $threshold);
    return \@offers;
}

=head2 parse_dhcp_option82

Option 82 is Relay Agent Information. Defined in RFC 3046.

=cut

sub parse_dhcp_option82 {
    my $timer = pf::StatsD::Timer->new({level => 7});
    my ($self, $dhcp) = @_;

    # slicing the hash to retrive the stuff we are interested in
    my ($switch_id, $switch, $vlan, $mod, $port, $host, $circuit_id_string)  = @{$dhcp->{'options'}{'82'}}{'switch_id', 'switch', 'vlan', 'module', 'port', 'host', 'circuit_id_string'};
    if ( defined($switch_id) || defined($switch) || defined($vlan) || defined($mod) || defined($port) || defined ($circuit_id_string) || defined ($host) ) {
        my $mac = clean_mac($dhcp->{'chaddr'});
        dhcp_option82_insert_or_update(
            'mac'               => $mac,
            'module'            => $mod,
            'port'              => $port,
            'circuit_id_string' => $circuit_id_string,
            'vlan'              => $vlan,
            'option82_switch'   => $switch,
            'host'              => $host,
            'switch_id'   => $switch_id,
        );
    }
}

=head2 update_iplog

Update the iplog entry for a device
Also handles the SSO stop if the IP changes

=cut

sub update_iplog {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $self, $srcmac, $srcip, $lease_length ) = @_;
    $logger->debug("$srcip && $srcmac");

    # return if MAC or IP is not valid
    if ( !valid_mac($srcmac) || !valid_ip($srcip) ) {
        $logger->error("invalid MAC or IP: $srcmac $srcip");
        return;
    }

    # we have to check directly in the DB since the OMAPI already contains the current lease info
    my $oldip  = pf::iplog::_mac2ip_sql($srcmac);
    my $oldmac = pf::iplog::_ip2mac_sql($srcip);
    if ( $oldip && $oldip ne $srcip ) {
        my $view_mac = node_view($srcmac);
        my $firewallsso = pf::firewallsso->new;
        $firewallsso->do_sso('Stop', $srcmac,$oldip,undef);
        $firewallsso->do_sso('Start', $srcmac, $srcip, $lease_length || $DEFAULT_LEASE_LENGTH);

        my $last_connection_type = $view_mac->{'last_connection_type'};
        if (defined $last_connection_type && $last_connection_type eq $connection_type_to_str{$INLINE}) {
            $self->{api_client}->notify('ipset_node_update',$oldip, $srcip, $srcmac);
        }
    }
    elsif ($oldmac && $oldmac ne $srcmac) {
        # Remove the actions that were for the previous MAC address
        pf::parking::remove_parking_actions($oldmac,$srcip);
    }
    my %data = (
        'mac' => $srcmac,
        'ip' => $srcip,
        'lease_length' => $lease_length,
        'oldip' => $oldip,
        'oldmac' => $oldmac,
    );
    $self->{api_client}->notify('update_iplog', %data);
}

=head2 get_local_dhcp_servers_by_ip

Return a list of all dhcp servers IP that could be running locally.

Caches results on first run then returns from cache.

TODO: Should be refactored and putted into a class. IP and MAC methods should also be put into a single one.

=cut

sub get_local_dhcp_servers_by_ip {

    # return from cache
    return @local_dhcp_servers_ip if (@local_dhcp_servers_ip);

    # look them up, fill cache and return result
    foreach my $network (keys %ConfigNetworks) {

        push @local_dhcp_servers_ip, $ConfigNetworks{$network}{'gateway'}
            if ($ConfigNetworks{$network}{'dhcpd'} eq 'enabled');
    }
    return @local_dhcp_servers_ip;
}

=head2 get_local_dhcp_servers_by_mac

Return a list of all mac addresses that could be issuing DHCP offers/acks locally.

Caches results on first run then returns from cache.

TODO: Should be refactored and putted into a class. IP and MAC methods should also be put into a single one.

=cut

sub get_local_dhcp_servers_by_mac {
    # return from cache
    return @local_dhcp_servers_mac if ( @local_dhcp_servers_mac );

    # look them up, fill cache and return result
    @local_dhcp_servers_mac = get_internal_macs();

    return @local_dhcp_servers_mac;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
