package pf::api;
=head1 NAME

pf::api RPC methods exposing PacketFence features

=cut

=head1 DESCRIPTION

pf::api

=cut

use strict;
use warnings;

use base qw(pf::api::attributes);
use threads::shared;
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

sub event_add : Public {
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

sub echo : Public {
    my ($class, @args) = @_;
    return @args;
}

sub radius_authorize : Public {
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

sub radius_accounting : Public {
    my ($class, %radius_request) = @_;
    my $logger = pf::log::get_logger();

    my $radius = new pf::radius::custom();
    my $return;
    eval {
        $return = $radius->accounting(\%radius_request);
    };
    if ($@) {
        $logger->error("radius accounting failed with error: $@");
    }
    return $return;
}

sub radius_update_locationlog : Public {
    my ($class, %radius_request) = @_;
    my $logger = pf::log::get_logger();

    my $radius = new pf::radius::custom();
    my $return;
    eval {
        $return = $radius->update_locationlog_accounting(\%radius_request);
    };
    if ($@) {
        $logger->error("radius update locationlog accounting failed with error: $@");
    }
    return $return;
}

sub soh_authorize : Public {
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

sub update_iplog : Public {
    my ($class, %postdata) = @_;
    my @require = qw(mac ip);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    $postdata{'oldip'}  = pf::iplog::mac2ip($postdata{'mac'}) if (!defined($postdata{'oldip'}));
    $postdata{'oldmac'} = pf::iplog::ip2mac($postdata{'ip'}) if (!defined($postdata{'oldmac'}));

    if ( $postdata{'oldmac'} && $postdata{'oldmac'} ne $postdata{'mac'} ) {
        $logger->info(
            "oldmac ($postdata{'oldmac'}) and newmac ($postdata{'mac'}) are different for $postdata{'ip'} - closing iplog entry"
        );
        pf::iplog::iplog_close_now($postdata{'ip'});
    } elsif ($postdata{'oldip'} && $postdata{'oldip'} ne $postdata{'ip'}) {
        $logger->info(
            "oldip ($postdata{'oldip'}) and newip ($postdata{'ip'}) are different for $postdata{'mac'} - closing iplog entry"
        );
        pf::iplog::iplog_close_now($postdata{'oldip'});
    }

    return (pf::iplog::iplog_open($postdata{'mac'}, $postdata{'ip'}, $postdata{'lease_length'}));
}
 
sub unreg_node_for_pid : Public {
    my ($class, %postdata) = @_;
    my $logger = pf::log::get_logger();
    my @require = qw(pid);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    my @node_infos =  pf::node::node_view_reg_pid($postdata{'pid'});
    $logger->info("Unregistering ".scalar(@node_infos)." node(s) for ".$postdata{'pid'});

    foreach my $node_info ( @node_infos ) {
        pf::node::node_deregister($node_info->{'mac'});
    }

    return 1;
}

sub synchronize_locationlog : Public {
    my ( $class, $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $user_name, $ssid ,$stripped_user_name, $realm) = @_;
    my $logger = pf::log::get_logger();

    return (pf::locationlog::locationlog_synchronize($switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $user_name, $ssid, $stripped_user_name, $realm));
}

sub insert_close_locationlog : Public {
    my ($class, $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $user_name, $ssid, $stripped_user_name, $realm);
    my $logger = pf::log::get_logger();

    return(pf::locationlog::locationlog_insert_closed($switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $user_name, $ssid, $stripped_user_name, $realm));
}

sub open_iplog : Public {
    my ( $class, $mac, $ip, $lease_length ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::iplog::iplog_open($mac, $ip, $lease_length));
}

sub close_iplog : Public {
    my ( $class, $ip ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::iplog::iplog_close($ip));
}

sub close_now_iplog : Public {
    my ( $class, $ip ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::iplog::iplog_close_now($ip));
}

sub ipset_node_update : Public {
    my ( $class, $oldip, $srcip, $srcmac ) = @_;
    my $logger = pf::log::get_logger();

    return(pf::ipset::update_node($oldip, $srcip, $srcmac));
}

sub firewallsso : Public {
    my ($class, %postdata) = @_;
    my @require = qw(method mac ip timeout);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

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
        $firewall->action($firewall_conf,$postdata{'method'},$postdata{'mac'},$postdata{'ip'},$postdata{'timeout'});
    }
    return $pf::config::TRUE;
}


sub ReAssignVlan : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(connection_type switch mac ifIndex);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

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

sub desAssociate : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(switch mac connection_type ifIndex);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

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

sub firewall : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    # verify if firewall rule is ok
    my $inline = new pf::inline::custom();
    $inline->performInlineEnforcement($postdata{'mac'});
}


# Handle connection types $WIRED_SNMP_TRAPS
sub _reassignSNMPConnections {
    my ( $switch, $mac, $ifIndex, $connection_type ) = @_;
    my $logger = pf::log::get_logger();
    # find open non VOIP entries in locationlog. Fail if none found.
    my @locationlog = pf::locationlog::locationlog_view_open_switchport_no_VoIP( $switch->{_id}, $ifIndex );
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

        _node_determine_and_set_into_VLAN( $mac, $switch, $ifIndex, $connection_type );
        
        # We treat phones differently. We never bounce their ports except if there is an outstanding
        # violation. 
        if ( $switch->hasPhoneAtIfIndex($ifIndex)  ) {
            my @violations = pf::violation::violation_view_open_desc($mac);
            if ( scalar(@violations) == 0 ) {
                $logger->warn("[$mac] VLAN changed and is behind VoIP phone. Not bouncing the port!");
                return;
            }
        }

    } # end case PORTSEC
    
    $logger->info( "[$mac] Flipping admin status on switch (".$switch->{'_id'}.") ifIndex $ifIndex. " );
    $switch->bouncePort($ifIndex);
}

=head2 _node_determine_and_set_into_VLAN

Set the vlan for the node on the switch

=cut

sub _node_determine_and_set_into_VLAN {
    my ( $mac, $switch, $ifIndex, $connection_type ) = @_;

    my $vlan_obj = new pf::vlan::custom();

    my ($vlan,$wasInline) = $vlan_obj->fetchVlanForNode($mac, $switch, $ifIndex, $connection_type);

    my %locker_ref;
    $locker_ref{$switch->{_ip}} = &share({});

    $switch->setVlan(
        $ifIndex,
        $vlan,
        \%locker_ref,
        $mac
    );
}


=head2 violation_delayed_run

runs the delayed violation now

=cut

sub violation_delayed_run : Public {
    my ($self, $violation) = @_;
    pf::violation::_violation_run_delayed($violation);
    return ;
}

=head2 trigger_violation

Trigger a violation

=cut

sub trigger_violation : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac tid type);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    return (pf::violation::violation_trigger($postdata{'mac'}, $postdata{'tid'}, $postdata{'type'}));
}


=head2 add_node

Modify a node

=cut

sub modify_node : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    if (defined($postdata{'unregdate'})) {
        if (pf::util::valid_date($postdata{'unregdate'})) {
            $postdata{'unregdate'} = pf::config::dynamic_unreg_date($postdata{'unregdate'});
        } else {
            $postdata{'unregdate'} = pf::config::access_duration($postdata{'unregdate'});
        }
    }
    pf::node::node_modify($postdata{'mac'}, %postdata);
    return;
}

=head2 register_node

Register a node

=cut

sub register_node : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac pid);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    pf::node::node_register($postdata{'mac'}, $postdata{'pid'}, %postdata);
    return;
}

=head2 deregister_node

Deregister a node

=cut

sub deregister_node : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    pf::node::node_deregister($postdata{'mac'}, %postdata);
    return;
}

=head2 node_information

Return all the node attributes

=cut

sub node_information : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    my $node_info = pf::node::node_view($postdata{'mac'});
    return $node_info;
}

=head2 validate_argv

Test if the required arguments are provided

=cut

sub validate_argv {
    my ($require, $found) = @_;
    my $logger = pf::log::get_logger();

    if (!(@{$require} == @{$found})) {
        my %diff;
        @diff{ @{$require} } = @{$require};
        delete @diff{ @{$found} };
        $logger->error("Missing argument ". join(',',keys %diff) ." for the function ".whowasi());
        return 0;
    }
    return 1;
}

=head2 whowasi

Return the parent function name

=cut

sub whowasi { ( caller(2) )[3] }

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

