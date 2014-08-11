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

sub description { 'OpenDaylight SDN controller' }
sub supportsFlows { return $TRUE }
sub getIfType{ return $SNMP::ETHERNET_CSMACD; }

sub authorizeMac {
    my ($self, $mac, $vlan, $port) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my @uplinks = $self->getUpLinks();

    my $violation = violation_view_top($mac);

    if(defined($violation) && $violation->{vid} eq "1100010"){
        $logger->info("Rogue DHCP detected. Packets from $mac will be dropped");
        $self->install_drop_flow($port, $mac, $vlan);
        return;
    }

    # install a new outbound flow
    $self->install_tagged_outbound_flow($port, $uplinks[0], $mac, $vlan);
    # install a new inbound flow on the uplink
    $self->install_tagged_inbound_flow($uplinks[0], $port, $mac, $vlan );
    # instal a flow for broadcast packets
    $self->install_tagged_inbound_flow($uplinks[0], $port, "ff:ff:ff:ff:ff:ff", $vlan, "broadcast" );
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
    else{
        $logger->error("Invalid type sent. Returning nothing.");
    }
}

sub deauthorizeMac {
    my ($self, $mac, $vlan, $port) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my @uplinks = $self->getUpLinks();
    $logger->info("Deleting flows for $mac on port $port on $self->{_ip}");
    # delete a possible drop flow
    $self->delete_flow("drop", $mac);
    $self->delete_flow("outbound", $mac);
    $self->delete_flow("inbound", $mac);
    $self->delete_flow("broadcast", "ff:ff:ff:ff:ff:ff");
}

sub delete_flow {
    my ($self, $type, $mac) = @_;
    my $flow_name = $self->get_flow_name($type, $mac);
    $self->send_json_request("controller/nb/v2/flowprogrammer/default/node/OF/$self->{_OpenflowId}/staticFlow/$flow_name", {}, "DELETE");
}

sub send_json_request {
    my ($self, $path, $data, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $url = "http://$self->{_controllerIp}:8080/$path";
    my $json_data = encode_json $data;

    my $command = 'curl -u admin:admin -X '.$method.' -d \''.$json_data.'\' --header "Content-type: application/json" '.$url; 
    $logger->info("Running $command");
    $logger->info("Result of command : ".pf_run($command));
}

sub install_tagged_outbound_flow {
    my ($self, $source_int, $dest_int, $mac, $vlan) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    $logger->info("Installing tagged outbound flow on source port $source_int, destination port $dest_int, tagged with $vlan, on switch $self->{_OpenflowId}");
    
    my $clean_mac = $mac;
    $clean_mac =~ s/://g;
    my $flow_name = $self->get_flow_name("outbound", $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$self->{_OpenflowId}/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");
    my %data = (
        "installInHw" => "true",
        "name" => "$flow_name",
        "node" => {
            "id" => $self->{_OpenflowId},
            "type" => "OF",
        },
        "ingressPort" => "$source_int",
        "priority" => "500",
        "dlSrc" => "$mac",
        "actions" => [
            "SET_VLAN_ID=$vlan",
            "OUTPUT=$dest_int",
        ],
    );
    
    $self->send_json_request($path, \%data, "PUT");
   
}

sub install_tagged_inbound_flow {
    my ($self, $source_int, $dest_int, $mac, $vlan, $flow_prefix) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if(!defined($flow_prefix)){
        $flow_prefix = "inbound";
    }

    my $flow_name = $self->get_flow_name($flow_prefix, $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$self->{_OpenflowId}/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $self->{_OpenflowId},
            "type" => "OF",
        },
        "ingressPort" => "$source_int",
        "priority" => "500",
        "vlanId" => $vlan,
        "dlDst" => $mac,
        "installInHw" => "true",
        "actions" => [
            "OUTPUT=$dest_int"
        ]
    );
    
    $self->send_json_request($path, \%data, "PUT");
   
}

sub install_drop_flow {
    my ($self, $source_int, $mac, $vlan, $flow_prefix) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if(!defined($flow_prefix)){
        $flow_prefix = "drop";
    }

    my $flow_name = $self->get_flow_name($flow_prefix, $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$self->{_OpenflowId}/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $self->{_OpenflowId},
            "type" => "OF",
        },
        "ingressPort" => "$source_int",
        "priority" => "500",
        "installInHw" => "true",
        "actions" => [
            "DROP"
        ]
    );
    
    $self->send_json_request($path, \%data, "PUT");
 
}

sub handleReAssignVlanTrapForWiredMacAuth {
    my ($self, $ifIndex, $mac) = @_;
    my $vlan_obj = new pf::vlan::custom();    
    my ($vlan, $wasInline, $user_role) = $vlan_obj->fetchVlanForNode($mac, $self, $ifIndex, undef, undef, undef);
    $self->deauthorizeMac($mac, $vlan, $ifIndex);
    $self->authorizeMac($mac, $vlan, $ifIndex);
}

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
