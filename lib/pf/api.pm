package pf::api;
=head1 NAME

pf::api RPC methods exposing PacketFence features

=cut

=head1 DESCRIPTION

pf::api

=cut

use strict;
use warnings;

use pf::config();
use pf::iplog();
use pf::log();
use pf::radius::custom();
use pf::violation();
use pf::soh::custom();
use pf::util();
use pf::node();
use pf::locationlog();
use pf::ipset();
use pf::config;
use pf::vlan::custom;
use pf::roles::custom;

sub event_add {
    my ($class, $date, $srcip, $type, $id) = @_;
    my $logger = pf::log::get_logger();
    $logger->info("violation: $id - IP $srcip");

    # fetch IP associated to MAC
    my $srcmac = pf::iplog::ip2mac($srcip);
    if ($srcmac) {

        # trigger a violation
        pf::violation::violation_trigger($srcmac, $id, $type);

    } else {
        $logger->info("violation on IP $srcip with trigger ${type}::${id}: violation not added, can't resolve IP to mac !");
        return(0);
    }
    return (1);
}

sub echo {
    my ($class, @args) = @_;
    return @args;
}

sub radius_authorize {
    my ($class, %radius_request) = @_;
    my $logger = pf::log::get_logger();

    my $radius = new pf::radius::custom();
    my $return;
    eval {
        $return = $radius->authorize(\%radius_request);
    };
    if ($@) {
        $logger->error("radius authorize failed with error: $@");
    }
    return $return;
}

sub radius_accounting {
    my ($class, %radius_request) = @_;
    my $logger = pf::log::get_logger();

    my $radius = new pf::radius::custom();
    my $return;
    eval {
        $return = $radius->accounting(\%radius_request);
    };
    if ($@) {
        $logger->logdie("radius accounting failed with error: $@");
    }
    return $return;
}

sub soh_authorize {
    my ($class, %radius_request) = @_;
    my $logger = pf::log::get_logger();

    my $soh = pf::soh::custom->new();
    my $return;
    eval {
      $return = $soh->authorize(\%radius_request);
    };
    if ($@) {
      $logger->error("soh authorize failed with error: $@");
    }
    return $return;
}

sub update_iplog {
    my ( $class, $srcmac, $srcip, $lease_length ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::iplog::iplog_update($srcmac, $srcip, $lease_length));
}
 
sub unreg_node_for_pid {
    my ($class, $pid) = @_;

    my $logger = pf::log::get_logger();
    my @node_infos =  pf::node::node_view_reg_pid($pid->{'pid'});
    $logger->info("Unregistering ".scalar(@node_infos)." node(s) for $pid");

    foreach my $node_info ( @node_infos ) {
        pf::node::node_deregister($node_info->{'mac'});
    }

    return 1;
}

sub synchronize_locationlog {
    my ( $class, $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $user_name, $ssid ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::locationlog::locationlog_synchronize($switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $user_name, $ssid));
}

sub insert_close_locationlog {
    my ($class, $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $user_name, $ssid);
    my $logger = pf::log::get_logger();

    return(pf::locationlog::locationlog_insert_closed($switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $user_name, $ssid));
}

sub open_iplog {
    my ( $class, $mac, $ip, $lease_length ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::iplog::iplog_open($mac, $ip, $lease_length));
}

sub close_iplog {
    my ( $class, $ip ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::iplog::iplog_close($ip));
}

sub close_now_iplog {
    my ( $class, $ip ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::iplog::iplog_close_now($ip));
}

sub trigger_violation {
    my ( $class, $mac, $tid, $type ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::violation::violation_trigger($mac, $tid, $type));
}

sub ipset_node_update {
    my ( $class, $oldip, $srcip, $srcmac ) = @_;
    my $logger = pf::log::get_logger();

    return(pf::ipset::update_node($oldip, $srcip, $srcmac));
}

sub firewallsso {
    my ($class, $info) = @_;
    my $logger = pf::log::get_logger();

    foreach my $firewall_conf ( sort keys %pf::config::ConfigFirewallSSO ) {
        my $module_name = 'pf::firewallsso::'.$pf::config::ConfigFirewallSSO{$firewall_conf}->{'type'};
        $module_name = pf::util::untaint_chain($module_name);
        # load the module to instantiate
        if ( !(eval "$module_name->require()" ) ) {
            $logger->error("Can not load perl module: $@");
            return 0;
        }
        my $firewall = $module_name->new();
        $firewall->action($firewall_conf,$info->{'method'},$info->{'mac'},$info->{'ip'},$info->{'timeout'});
    }
    return $pf::config::TRUE;
}


sub ReAssignVlan {
    my ($class, %postdata )  = @_;
    my $logger = pf::log::get_logger();

    if ( not defined( $postdata{'connection_type'} )) { 
        $logger->error("Connection type is unknown. Could not reassign VLAN."); 
        return;
    }

    my $switch = pf::SwitchFactory->getInstance()->instantiate( $postdata{'switch'} );
    unless ($switch) {
        $logger->error("switch $postdata{'switch'} not found for ReAssignVlan");
        return;
    }

    sleep $pf::config::Config{'trapping'}{'wait_for_redirect'}; 

    # SNMP traps connections need to be handled specially to account for port-security etc.
    if ( ($postdata{'connection_type'} & $pf::config::WIRED_SNMP_TRAPS) == $pf::config::WIRED_SNMP_TRAPS ) {
        _reassignSNMPConnections($switch, $postdata{'mac'}, $postdata{'ifIndex'}, $postdata{'connection_type'} );
    }
    elsif ( $postdata{'connection_type'} & $pf::config::WIRED) {
        my ( $switchdeauthMethod, $deauthTechniques )
            = $switch->wiredeauthTechniques( $switch->{_deauthMethod}, $postdata{'connection_type'} );
        $switch->$deauthTechniques( $postdata{'ifIndex'}, $postdata{'mac'} );
    }
    else { 
        $logger->error("Connection type is not wired. Could not reassign VLAN."); 
    }
}

sub desAssociate {
    my ($class, %postdata )  = @_;
    my $logger = pf::log::get_logger();

    my $switch = pf::SwitchFactory->getInstance()->instantiate($postdata{'switch'});
    unless ($switch) {
        $logger->error("switch $postdata{'switch'} not found for desAssociate");
        return;
    }

    my ($switchdeauthMethod, $deauthTechniques) = $switch->deauthTechniques($switch->{'_deauthMethod'});

    # sleep long enough to give the device enough time to fetch the redirection page.
    sleep $pf::config::Config{'trapping'}{'wait_for_redirect'}; 

    $logger->info("[$postdata{'mac'}] DesAssociating mac on switch (".$switch->{'_id'}.")");
    $switch->$deauthTechniques($postdata{'mac'});
}

sub firewall {
    my ($class, %postdata )  = @_;
    my $logger = pf::log::get_logger();

    # verify if firewall rule is ok
    my $inline = new pf::inline::custom();
    $inline->performInlineEnforcement($postdata{'mac'});
}

sub sdn_authorize {
    my ($class, $postdata ) = @_;
    my $logger = pf::log::get_logger();
    my $mac = $postdata->{mac};
    my $switch_id = $postdata->{switch_id};
    my $port = $postdata->{port};
   
    my $switch = pf::SwitchFactory->getInstance()->instantiate($switch_id);
    $postdata->{switch} = $switch;
    if (!$switch){
        $logger->error("Can't get instance of $switch_id");
        return {action => "failed"};
    }

    if ($switch->isUpLink($port)){
        $logger->info("Received an openflow authorize to an uplink. Not doing anything");
        return {action => "ignored"};
    }
    else{
        $logger->info("Authorizing $mac on switch $switch_id port $port.");
    }

    my $info = pf::node::node_view($mac);
    my $violation_count = pf::violation::violation_count_trap($mac);
    my $roles_obj = pf::roles::custom->new();
    my $role = $roles_obj->getRoleForNode($mac, $switch);

    if (!defined($info) || $violation_count > 0 || $info->{status} eq $pf::node::STATUS_UNREGISTERED || $info->{status} eq $pf::node::STATUS_PENDING){
        if($switch->{_IsolationStrategy} eq "VLAN"){
            $class->sdn_vlan_authorize($postdata) || return { action => "failed" };
        }
        elsif($switch->{_IsolationStrategy} eq "DNS"){
            $switch->install_dns_redirect($port, $mac) || return { action => "failed" };
        }
        return { action => "isolate", strategy => $switch->{_IsolationStrategy} };
    } 
    else{
        if($switch->{_IsolationStrategy} eq "VLAN"){
            $class->sdn_vlan_authorize($postdata) || return { action => "failed" };
        }
        elsif($switch->{_IsolationStrategy} eq "DNS"){
            $switch->uninstall_dns_redirect($port, $mac) || return {action => "failed"};
        }
        return { action => "accept", strategy => $switch->{_IsolationStrategy} , role => $role } ;
    }
}

sub sdn_vlan_authorize {
    my ($class, $postdata ) = @_;
    my $logger = pf::log::get_logger();
    use Data::Dumper;
    $logger->info(Dumper($postdata));

    my $connection_type = $WIRED_MAC_AUTH;
    my $ssid;
    my $eap_type;
    my $user_name;
    my $mac = $postdata->{mac};
    my $switch_id = $postdata->{switch_id};
    my $switch_mac;
    my $port = $postdata->{port};
    my $switch = $postdata->{switch};

    #add node if necessary
    if ( !pf::node::node_exist($mac) ) {
        $logger->info("node $mac does not yet exist in database. Adding it now");
        pf::node::node_add_simple($mac);
    }

    # There is activity from that mac, call node wakeup
    pf::node::node_mac_wakeup($mac);

    $switch_id =  $switch->{_id};

    # determine if we need to perform automatic registration
    my $isPhone = $switch->isPhoneAtIfIndex($mac, $port);

    # determine if we need to remove an old flow entry
    my $old_location = pf::locationlog::locationlog_view_open_mac($mac);
    use Data::Dumper;
    $logger->info(Dumper($old_location));
    eval{
        my $old_switch = pf::SwitchFactory->getInstance()->instantiate({ switch_ip => $old_location->{switch_ip}, switch_mac => $old_location->{switch_mac} });
        if($old_switch->supportsFlows()){
            $logger->info("$mac moved between two supported openflow ports. Removing previous flows on $old_switch->{_ip} port $old_location->{port}");
            $old_switch->deauthorizeMac($mac, $old_location->{vlan}, $old_location->{port}); 
        }
    };

    my $vlan_obj = new pf::vlan::custom();
    # should we auto-register? let's ask the VLAN object
    if ($vlan_obj->shouldAutoRegister($mac, $switch->isRegistrationMode(), 0, $isPhone,
        $connection_type, $user_name, $ssid, $eap_type, $switch, $port)) {

        # automatic registration
        my %autoreg_node_defaults = $vlan_obj->getNodeInfoForAutoReg($switch->{_id}, $port,
            $mac, undef, $switch->isRegistrationMode(), $FALSE, $isPhone, $connection_type, $user_name, $ssid, $eap_type);

        $logger->debug("auto-registering node $mac");
        if (!pf::node::node_register($mac, $autoreg_node_defaults{'pid'}, %autoreg_node_defaults)) {
            $logger->error("auto-registration of node $mac failed");
        }
        pf::locationlog::locationlog_synchronize($switch, $switch_id, $switch_id, $port, undef, $mac,
            $isPhone ? $VOIP : $NO_VOIP, $connection_type, $user_name, $ssid
        );
    }

    # if it's an IP Phone, let _authorizeVoip decide (extension point)
    if ($isPhone) {
        # do something intelligent
    }

    # Fetch VLAN depending on node status
    my ($vlan, $wasInline, $user_role) = $vlan_obj->fetchVlanForNode($mac, $switch, $port, $connection_type, $user_name, $ssid);



    # should this node be kicked out?
    if (defined($vlan) && $vlan == -1) {
        $logger->info("According to rules in fetchVlanForNode this node must be kicked out. Returning USERLOCK");
        $switch->disconnectRead();
        $switch->disconnectWrite();
        return $vlan;
    }

    $logger->info("Returning VLAN $vlan");

    my $result = $switch->authorizeMac($mac, $vlan, $port ); 

    if($result){
        $switch->synchronize_locationlog($port, $vlan, $mac,
            $isPhone ? $VOIP : $NO_VOIP, $connection_type, $user_name, $ssid
        ) if (!$wasInline);
    }

    return $result;

}


# Handle connection types $WIRED_SNMP_TRAPS
sub _reassignSNMPConnections {
    my ( $switch, $mac, $ifIndex, $connection_type ) = @_;
    my $logger = pf::log::get_logger();
    # find open non VOIP entries in locationlog. Fail if none found.
    my @locationlog = locationlog_view_open_switchport_no_VoIP( $switch->{_id}, $ifIndex );
    unless ( (@locationlog) && ( scalar(@locationlog) > 0 ) && ( $locationlog[0]->{'mac'} ne '' ) ) {
        $logger->warn(
            "[$mac] received reAssignVlan trap on (".$switch->{'_id'}.") ifIndex $ifIndex but can't determine non VoIP MAC"
        );
        return;
    }

    # case PORTSEC : When doing port-security we need to reassign the VLAN before 
    # bouncing the port. 
    if ( $switch->isPortSecurityEnabled($ifIndex) ) {
        $logger->info( "[$mac] security traps are configured on (".$switch->{'_id'}.") ifIndex $ifIndex. Re-assigning VLAN" );

        node_determine_and_set_into_VLAN( $mac, $switch, $ifIndex, $connection_type );
        
        # We treat phones differently. We never bounce their ports except if there is an outstanding
        # violation. 
        if ( $switch->hasPhoneAtIfIndex($ifIndex)  ) {
            my @violations = violation_view_open_desc($mac);
            if ( scalar(@violations) == 0 ) {
                $logger->warn("[$mac] VLAN changed and is behind VoIP phone. Not bouncing the port!");
                return;
            }
        }

    } # end case PORTSEC
    
    $logger->info( "[$mac] Flipping admin status on switch (".$switch->{'_id'}.") ifIndex $ifIndex. " );
    $switch->bouncePort($ifIndex);
}
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

