package pf::Switch::OpenDaylight;

=head1 NAME

pf::Switch::Brocade::RFS

=head1 SYNOPSIS

Brocade RF Switches module

=head1 STATUS

This module is currently only a placeholder, see L<pf::Switch::Motorola>

=cut

use strict;
use warnings;

use base ('pf::Switch');
use JSON::XS;
use WWW::Curl::Easy;
use Log::Log4perl;
use pf::util;
use pf::config;
use pf::vlan::custom;
use pf::violation;
use pf::node;

sub description { 'OpenDaylight SDN controller' }
sub supportsFlows { return $TRUE }
sub getIfType{ return $SNMP::ETHERNET_CSMACD; }

sub authorizeMac {
    my ($self, $mac, $vlan, $port, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my @uplinks = $self->getUpLinks();

    my $violation = violation_view_top($mac);

    if(defined($violation) && $violation->{vid} eq "1100010"){
        $logger->info("Rogue DHCP detected. Packets from $mac will be dropped");
        $self->install_drop_flow($port, $mac, $vlan);
        return;
    }

    # install a new outbound flow
    $self->install_tagged_outbound_flow($port, $uplinks[0], $mac, $vlan, $switch_id) || return $FALSE;
    # install a new inbound flow on the uplink
    $self->install_tagged_inbound_flow($uplinks[0], $port, $mac, $vlan, $switch_id ) || return $FALSE;
    # instal a flow for broadcast packets
    $self->install_tagged_inbound_flow($uplinks[0], $port, "ff:ff:ff:ff:ff:ff", $vlan, "broadcast", $switch_id ) || return $FALSE;
}

sub get_flow_name{
    my ($self, $type, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $clean_mac = $mac;
    $clean_mac =~ s/://g;

    if($type eq "outbound"){
        return "outbound".$clean_mac;
    }
    elsif($type eq "inbound"){
        return "inbound".$clean_mac; 
    }
    elsif($type eq "broadcast"){
        return "broadcast".$clean_mac;
    }
    elsif($type eq "drop"){
        return "drop".$clean_mac;
    }   
    elsif($type eq "dnsredirect"){
        return "dnsredirect".$clean_mac;
    }
    else{
        $logger->error("Invalid type sent. Returning something that should work.");
        return $type.$clean_mac;
    }
}

sub deauthorizeMac {
    my ($self, $mac, $vlan, $port, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my @uplinks = $self->getUpLinks();
    $logger->info("Deleting flows for $mac on port $port on $self->{_ip}");
    # delete a possible drop flow
    $self->delete_flow("drop", $mac, $switch_id) || return $FALSE;
    $self->delete_flow("outbound", $mac, $switch_id) || return $FALSE;
    $self->delete_flow("inbound", $mac, $switch_id) || return $FALSE;
    $self->delete_flow("broadcast", "ff:ff:ff:ff:ff:ff", $switch_id) || return $FALSE;
}

sub delete_flow {
    my ($self, $type, $mac, $switch_id) = @_;
    my $flow_name = $self->get_flow_name($type, $mac);
    return $self->send_json_request("controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name", {}, "DELETE");
}

sub send_json_request {
    my ($self, $path, $data, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $url = "$self->{_wsTransport}://$self->{_ip}:8080/$path";
    my $json_data = encode_json $data;

    my $command = 'curl -u '.$self->{_wsUser}.':'.$self->{_wsPwd}.' -X '.$method.' -d \''.$json_data.'\' --header "Content-type: application/json" '.$url; 
    $logger->info("Running $command");
    my $result = pf_run($command);
    $logger->info("Result of command : ".$result);
    if ( !($method eq "GET") && ( $result eq "Success" || $result eq "No modification detected" || $result eq "") ){
        return $TRUE;
    }
    elsif ($method eq "GET"){
        return $result;
    }
    return $FALSE;
}

sub install_tagged_outbound_flow {
    my ($self, $source_int, $dest_int, $mac, $vlan, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    $logger->info("Installing tagged outbound flow on source port $source_int, destination port $dest_int, tagged with $vlan, on switch $switch_id");
    
    my $clean_mac = $mac;
    $clean_mac =~ s/://g;
    my $flow_name = $self->get_flow_name("outbound", $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");
    my %data = (
        "installInHw" => "true",
        "name" => "$flow_name",
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        "ingressPort" => "$source_int",
        "etherType" => "0x800",
        "priority" => "500",
        "dlSrc" => "$mac",
        "actions" => [
            "SET_VLAN_ID=$vlan",
            "OUTPUT=$dest_int",
        ],
    );
    
    return $self->send_json_request($path, \%data, "PUT");
   
}

sub install_tagged_inbound_flow {
    my ($self, $source_int, $dest_int, $mac, $vlan, $flow_prefix, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if(!defined($flow_prefix)){
        $flow_prefix = "inbound";
    }

    my $flow_name = $self->get_flow_name($flow_prefix, $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        "ingressPort" => "$source_int",
        "etherType" => "0x800",
        "priority" => "500",
        "vlanId" => $vlan,
        "dlDst" => $mac,
        "installInHw" => "true",
        "actions" => [
            "OUTPUT=$dest_int"
        ]
    );
    
    return $self->send_json_request($path, \%data, "PUT");
   
}

sub install_drop_flow {
    my ($self, $source_int, $mac, $vlan, $flow_prefix, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if(!defined($flow_prefix)){
        $flow_prefix = "drop";
    }

    my $flow_name = $self->get_flow_name($flow_prefix, $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        "ingressPort" => "$source_int",
        "priority" => "500",
        "etherType" => "0x800",
        "installInHw" => "true",
        "actions" => [
            "DROP"
        ]
    );
    
    return $self->send_json_request($path, \%data, "PUT");
 
}

sub handleReAssignVlanTrapForWiredMacAuth {
    my ($self, $ifIndex, $mac) = @_;
    my $vlan_obj = new pf::vlan::custom();    
    my $info = pf::node::node_view($mac);
    my $violation_count = pf::violation::violation_count_trap($mac);

    if($self->{_IsolationStrategy} eq "VLAN"){
        my ($vlan, $wasInline, $user_role) = $vlan_obj->fetchVlanForNode($mac, $self, $ifIndex, undef, undef, undef);
        $self->deauthorizeMac($mac, $vlan, $ifIndex);
        $self->authorizeMac($mac, $vlan, $ifIndex);
    }
    elsif($self->{_IsolationStrategy} eq "DNS"){
        if (!defined($info) || $violation_count > 0 || $info->{status} eq $pf::node::STATUS_UNREGISTERED || $info->{status} eq $pf::node::STATUS_PENDING){
            $self->reactivate_dns_redirect($ifIndex, $mac);
        }
        else{
            $self->uninstall_dns_redirect($ifIndex, $mac);
        }
    }
}

sub block_network_detection {
    my ($self, $ifIndex, $mac, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    
    my $flow_name = $self->get_flow_name("block-network-detection", $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        "ingressPort" => "$ifIndex",
        "dlSrc" => $mac,
        "priority" => "1100",
        "etherType" => "0x800",
        "nwDst" => "192.195.20.194/32",
        "tpDst" => "80",
        "protocol" => "tcp",
        "installInHw" => "true",
        "actions" => [
            "DROP"
        ]
    );
    return $self->send_json_request($path, \%data, "PUT");

}

sub install_dns_redirect {
    my ($self, $ifIndex, $mac, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    
    if ( $self->reactivate_dns_redirect($ifIndex, $mac) ){
        $logger->warn("Couldn't reactivate dnsredirect. Installing a new one");
        return $TRUE;
    }


    #$self->block_network_detection($ifIndex, $mac);

    my $flow_name = $self->get_flow_name("dnsredirect", $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        "ingressPort" => "$ifIndex",
        "dlSrc" => $mac,
        "priority" => "1000",
        "etherType" => "0x800",
        "nwDst" => "0.0.0.0/0",
        "tpDst" => "53",
        "protocol" => "udp",
        "installInHw" => "true",
        "actions" => [
            "CONTROLLER"
        ]
    );
    return $self->send_json_request($path, \%data, "PUT");
}

sub uninstall_dns_redirect {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    #$self->find_and_delete_flow("dnsredirect", $mac);
    my $flow_name = $self->get_flow_name("dnsredirect", $mac);
    $self->deactivate_flow($flow_name); 

    return $TRUE;
}

sub reactivate_dns_redirect {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $flow_name = $self->get_flow_name("dnsredirect", $mac);
    return $self->reactivate_flow($flow_name); 
}

sub find_flow_by_name {
    my ($self, $name) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $path = "controller/nb/v2/flowprogrammer/default";
    my %data = ();
    my $json_response = $self->send_json_request( $path, \%data, "GET" );
    my $data = decode_json($json_response);

    my $flows = $data->{flowConfig};
    foreach my $flow (@$flows){
        if($flow->{name} eq $name){
            return $flow;
        }
    }

    return $FALSE;

}

sub find_and_delete_flow {
    my ($self, $type, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $flow_name = $self->get_flow_name($type, $mac);
    my $flow = $self->find_flow_by_name($flow_name);
    $self->delete_flow($type, $mac, $flow->{node}->{id});
}

sub deactivate_flow{
    my ($self, $flow_name) = @_;
    my $flow = $self->find_flow_by_name($flow_name);
    if($flow && $flow->{installInHw} eq "true"){
        $self->toggle_flow($flow);
    }
}

sub reactivate_flow{
    my ($self, $flow_name) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $flow = $self->find_flow_by_name($flow_name);
    if($flow && $flow->{installInHw} eq "false"){
        $self->toggle_flow($flow);
        return $TRUE;
    }
    else{
        return $FALSE;
    }
}

sub toggle_flow {
    my ($self, $flow) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$flow->{node}->{id}/staticFlow/$flow->{name}";
    $logger->info("Computed path is : $path");

    return $self->send_json_request($path, {}, "POST");
}



#sub uninstall_dns_redirect {
#    my ($self, $ifIndex, $mac) = @_;
#    my $logger = Log::Log4perl::get_logger( ref($self) );
#    
#    my $flow_name = $self->get_flow_name("dnsredirect", $mac);
#    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$self->{_OpenflowId}/staticFlow/$flow_name";
#    $logger->info("Computed path is : $path");
#
#    my %data = (
#        "name" => $flow_name,
#        "node" => {
#            "id" => $self->{_OpenflowId},
#            "type" => "OF",
#        },
#        "ingressPort" => "$ifIndex",
#        "dlSrc" => $mac,
#        "priority" => "1002",
#        "etherType" => "0x800",
#        "nwDst" => "0.0.0.0/0",
#        "tpDst" => "53",
#        "protocol" => "udp",
#        "installInHw" => "true",
#        "actions" => [
#            "FLOOD"
#        ]
#    );
#
#
#    #$self->delete_flow("block-network-detection", $mac);
#
#    return $self->send_json_request($path, \%data, "PUT");
#}

#sub send_json_request {
#    my ($self, $path, $data, $method) = @_;
#    my $logger = Log::Log4perl::get_logger( ref($self) );
#    my $url = "http://172.20.20.99:8080/$path";
#    my $json_data = encode_json $data;
#    my $curl = WWW::Curl::Easy->new;
#    $curl->setopt(CURLOPT_HEADER, 1);
#    #$curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
#    #$curl->setopt(CURLOPT_NOSIGNAL, 1);
#    $curl->setopt(CURLOPT_URL, $url);
#    $curl->setopt(CURLOPT_HTTPHEADER, ['Content-type: application/json', 'Authorization: Basic YWRtaW46YWRtaW4=']);
#    #$curl->setopt(CURLOPT_HTTPAUTH, CURLOPT_HTTPAUTH);
#    #$curl->setopt(CURLOPT_USERNAME, "admin");
#    #$curl->setopt(CURLOPT_PASSWORD, "admin");
#    
#
#
#    my $request = $json_data;
#    my $response_body;
#    my $response;
#    #$curl->setopt(CURLOPT_POSTFIELDSIZE,length($request));
#    #$curl->setopt(CURLOPT_POST, 1);
#    if($method eq "PUT"){
#        $logger->info("USING PUT");
#        $curl->setopt(CURLOPT_PUT, 1);     
#    }   
#    $curl->setopt(CURLOPT_POSTFIELDS, $request);
#    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
#
#    use Data::Dumper;
#    $logger->info($json_data);
#    # Starts the actual request
#    my $curl_return_code = $curl->perform;
#
#    if ( $curl_return_code == 0 ) {
#       my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
#       if($response_code == 200) {
#           $response = decode_json($response_body);
#           use Data::Dumper;
#           $logger->info(Dumper($response));
#       } else {
#           $logger->error("An error occured while processing the JSON request return code ($response_code)");
#           $logger->error(Dumper($response_body));
#           die "An error occured while processing the JSON request return code ($response_code)";
#       }
#   } else {
#       my $msg = "An error occured while sending a JSON request: $curl_return_code ".$curl->strerror($curl_return_code)." ".$curl->errbuf;
#       $logger->error($msg);
#       die $msg;
#   }
#
#   
#    
#}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
