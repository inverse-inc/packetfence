package pf::firewalld;

=head1 NAME

pf::firewalld

=cut

=head1 DESCRIPTION

Interface to get information based on /usr/local/pf/conf/firewalld

=cut

use strict;
use warnings;
use File::Copy;
use Template;

BEGIN {
  use Exporter ();
  our ( @ISA, @EXPORT );
  @ISA = qw(Exporter);
  @EXPORT = qw(
    generate_firewalld_configs
    generate_filter_if_src_to_chain

    internal_interfaces_handling
    portal_interfaces_handling
    radius_interfaces_handling
    dhcp_interfaces_handling
    dns_interfaces_handling
    management_interface_handling
    high_availability_interfaces_handling
    nat_back_inline_enabled

    dns_interfaces_handling
    management_interface_handling
    high_availability_interfaces_handling
    nat_back_inline_enabled
    generate_netdata_firewalld_config
    generate_FB_collector_firewalld_config
    generate_eduroam_radius_config
    generate_inline_enforcement

    generate_interception_rules
    generate_dnat_from_docker
    generate_kafka_firewalld_config
  );
}

use pf::config qw(
    %ConfigNetworks
    %Config
    $IPTABLES_MARK_UNREG
    $management_network
    @internal_nets
    $IF_ENFORCEMENT_VLAN
    %ConfigProvisioning
    $IF_ENFORCEMENT_DNS
    @portal_ints
    @ha_ints
    $IPTABLES_MARK_ISOLATION
    $IPTABLES_MARK_REG
    is_inline_enforcement_enabled
    is_type_inline
    @radius_ints
    @dhcp_ints
    @dns_ints
    netflow_enabled
);
use pf::file_paths qw($generated_conf_dir $conf_dir);
use pf::util;
use pf::security_event qw(security_event_view_open_uniq security_event_count);
use pf::authentication;
use pf::cluster;
use pf::ConfigStore::Provisioning;
use pf::ConfigStore::Domain;


use pf::Firewalld::util;
use pf::Firewalld::config qw ( generate_firewalld_file_config );
use pf::Firewalld::lockdown_whitelist qw ( generate_lockdown_whitelist_config );
use pf::Firewalld::helpers qw ( generate_helpers_config );
use pf::Firewalld::icmptypes qw ( generate_icmptypes_config );
use pf::Firewalld::ipsets qw ( generate_ipsets_config );
use pf::Firewalld::services qw ( generate_services_config );
use pf::Firewalld::zones qw ( generate_zones_config );
use pf::Firewalld::policies qw ( generate_policies_config );

sub generate_firewalld_configs {
  generate_firewalld_file_config();
  generate_lockdown_whitelist_config();
  generate_helpers_config();
  generate_icmptypes_config();
  generate_ipsets_config();
  generate_services_config();
  generate_zones_config();
  generate_policies_config();
}

sub generate_filter_if_src_to_chain {
  internal_interfaces_handling();
  portal_interfaces_handling();
  radius_interfaces_handling();
  dhcp_interfaces_handling();
  dns_interfaces_handling();
  management_interface_handling();
  high_availability_interfaces_handling();
  nat_back_inline_enabled();

  dns_interfaces_handling();
  management_interface_handling();
  high_availability_interfaces_handling();
  nat_back_inline_enabled();
  generate_netdata_firewalld_config();
  generate_FB_collector_firewalld_config();
  generate_eduroam_radius_config();
  generate_inline_enforcement();

  generate_interception_rules();
  generate_dnat_from_docker();
  generate_kafka_firewalld_config();
}

sub internal_interfaces_handling {
  my $logger = get_logger();
  my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
  my $isolation_passthrough_enabled = isenabled($Config{'fencing'}{'isolation_passthrough'});
  my $internal_portal_ip = $Config{captive_portal}{ip_address};

  # internal interfaces handling
  foreach my $interface (@internal_nets) {
    my @all_dev_rules;
    my $dev = $interface->tag("int");
    my $ip = $interface->tag("vip") || $interface->tag("ip");
    my $enforcement_type = $Config{"interface $dev"}{'enforcement'};
    my $cluster_ip = $ConfigCluster{$CLUSTER}->{"interface $dev"}->{ip};
    # VLAN enforcement
    if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
      if ($dev =~ m/(\w+):\d+/) {
        $dev = $1;
      }
      my $type = $pf::config::NET_TYPE_VLAN_REG;
      my $chain = $FW_FILTER_INPUT_INT_VLAN;
      foreach my $network ( keys %ConfigNetworks ) {
        # We skip non-inline networks/interfaces
        next if ( pf::config::is_network_type_inline($network) );
        if ( $ConfigNetworks{$network}{'type'} eq $pf::config::NET_TYPE_VLAN_ISOL ) {
          my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
          my $ip_test = new NetAddr::IP::Lite clean_ip($ip);
          if ($net_addr->contains($ip_test)) {
            $chain = $FW_FILTER_INPUT_INT_ISOL_VLAN;
            $type = $pf::config::NET_TYPE_VLAN_ISOL;
          }
        }
      }
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination address="224.0.0.0/8" accept' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" protocol value="vrrp" accept' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" port="647/tcp" accept' ) if ($pf::cluster_enabled);
      util_apply_rich_rule( $dev , 'rule family="ipv4" port="67/udp" accept' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination="'. $internal_portal_ip .'" '. $chain .'' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination="'. $cluster_ip .'" '. $chain .'' ) if ($cluster_enabled);
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination="'. $interface->tag("vip") .'" '. $chain .'' ) if $interface->tag("vip");
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination="'. $interface->tag("ip") .'" '. $chain .'' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination="255.255.255.255" '. $chain .'' );

      if ($passthrough_enabled && ($type eq $pf::config::NET_TYPE_VLAN_REG)) {
        util_apply_direct_add_rule( "ipv4 filter FORWARD 0 -i $dev -j $FW_FILTER_FORWARD_INT_VLAN");
        util_apply_direct_add_rule( "ipv4 filter FORWARD 0 -o $dev -j $FW_FILTER_FORWARD_INT_VLAN");
      }
      if ($isolation_passthrough_enabled && ($type eq $pf::config::NET_TYPE_VLAN_ISOL)) {
        util_apply_direct_add_rule( "ipv4 filter FORWARD 0 -i $dev -j $FW_FILTER_FORWARD_INT_ISOL_VLAN");
        util_apply_direct_add_rule( "ipv4 filter FORWARD 0 -o $dev -j $FW_FILTER_FORWARD_INT_ISOL_VLAN");
      }

    # inline enforcement
    } elsif (is_type_inline($enforcement_type)) {
      my $mgmt_ip = (defined($management_network->tag('vip'))) ? $management_network->tag('vip') : $management_network->tag('ip');
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination address="224.0.0.0/8" accept' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" protocol value="vrrp" accept' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" port="647/tcp" accept' ) if ($pf::cluster_enabled);
      util_apply_rich_rule( $dev , 'rule family="ipv4" port="67/udp" accept' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination="'. $internal_portal_ip .'" '. $FW_FILTER_INPUT_INT_VLAN .' ' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination="'. $cluster_ip .'" '. $FW_FILTER_INPUT_INT_INLINE .'' ) if ($cluster_enabled);
      util_apply_rich_rule( $dev , 'rule family="ipv4" port="53/tcp" '.$FW_FILTER_INPUT_INT_INLINE.' ' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" port="53/udp" '.$FW_FILTER_INPUT_INT_INLINE.' ' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination="'. $ip .'" '. $FW_FILTER_INPUT_INT_INLINE .' ' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination="255.255.255.255" '. $FW_FILTER_INPUT_INT_INLINE .' ' );
      util_apply_rich_rule( $dev , 'rule family="ipv4" destination="'.$mgmt_ip.'" port="443/udp" accept' );
      util_apply_direct_add_rule("ipv4 filter FORWARD 0 -i $dev -j $FW_FILTER_FORWARD_INT_INLINE");

    # nothing? something is wrong
    } else {
      $logger->warn("Didn't assign any firewall rules to interface $dev.");
    }
  }
}

sub portal_interfaces_handling {
  # 'portal' interfaces handling
  foreach my $portal_interface ( @portal_ints ) {
    my $dev = $portal_interface->tag("int");
    util_apply_rich_rule( $dev , 'rule family="ipv4" destination address="224.0.0.0/8" accept' );
    util_apply_rich_rule( $dev , 'rule family="ipv4" protocol value="vrrp" accept' );
    util_apply_rich_rule( $dev , 'rule family="ipv4" '.$FW_FILTER_INPUT_PORTAL );
  }
}

sub radius_interfaces_handling {
  # 'radius' interfaces handling
  foreach my $radius_interface ( @radius_ints ) {
    my $dev = $radius_interface->tag("int");
    util_apply_rich_rule( $dev , 'rule family="ipv4" destination address="224.0.0.0/8" accept' );
    util_apply_rich_rule( $dev , 'rule family="ipv4" protocol value="vrrp" accept' );
    util_apply_rich_rule( $dev , 'rule family="ipv4" '.$FW_FILTER_INPUT_RADIUS );
  }
}

sub dhcp_interfaces_handling {
  # 'dhcp' interfaces handling
  foreach my $dhcp_interface ( @dhcp_ints ) {
    my $dev = $dhcp_interface->tag("int");
    util_apply_rich_rule( $dev , 'rule family="ipv4" '.$FW_FILTER_INPUT_DHCP );
  }
}

sub dns_interfaces_handling {
  # 'dns' interfaces handling
  foreach my $dns_interface ( @dns_ints ) {
    my $dev = $dns_interface->tag("int");
    util_apply_rich_rule( $dev , 'rule family="ipv4" '.$FW_FILTER_INPUT_DNS );
  }
}

sub management_interface_handling {
  # management interface handling
  if($management_network) {
    my $dev = $management_network->tag("int");
    util_apply_rich_rule( $dev , 'rule family="ipv4" '.$FW_FILTER_INPUT_MGMT );
  }
}

sub high_availability_interfaces_handling {
  # high-availability interfaces handling
  foreach my $dev (map { $_ ? $_->{Tint} : () } @ha_ints) {
    util_apply_rich_rule( $dev , 'rule family="ipv4" '.$FW_FILTER_INPUT_INT_HA );
  }
}

sub nat_back_inline_enabled {
  # Allow the NAT back inside through the forwarding table if inline is enabled
  if ( is_inline_enforcement_enabled() ) {
    my @values = split( ',' , get_inline_snat_interface() );
    foreach my $dev (@values) {
      foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
        my $nat = $ConfigNetworks{$network}{'nat_enabled'};
        if ( defined ( $nat ) && ( isdisabled($nat) ) ) {
          util_apply_rich_rule( $dev , 'rule family="ipv4" destination address="'.$network.'/'.$inline_obj->{BITS}.'" accept' );
        }
      }
      util_apply_direct_add_rule("ipv4 filter FORWARD 0 -i $val -m state --state ESTABLISHED,RELATED -j ACCEPT");
    }
    if($management_network) {
      my $mgmt_int = $management_network->tag("int");
      util_apply_direct_add_rule("ipv4 filter FORWARD 0 -i $mgmt_int -m state --state ESTABLISHED,RELATED -j ACCEPT");
    }
  }
}

sub generate_netdata_firewalld_config {
  my $mgnt_zone =  $management_network->{Tip};
  util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="19999/tcp" source address="127.0.0.1" accept' );
  if ($cluster_enabled) {
    push my @mgmt_backend, map { $_->{management_ip} } pf::cluster::config_enabled_servers();
    foreach my $mgmt_back (uniq(@mgmt_backend)) {
      util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="19999/tcp" source address="'.$rule.'" accept' );
    }
  }
  util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="19999/tcp" drop' );
}

sub generate_FB_collector_firewalld_config {
  # The dynamic range used to access the fingerbank collector that are connected via a remote connector
  my $mgnt_zone =  $management_network->{Tip};
  $tags{'pfconnector'} = "";
  my @pfconnector_ips = ("127.0.0.1");
  push @pfconnector_ips, (map { $_->{management_ip} } pf::cluster::config_enabled_servers()) if ($cluster_enabled);
  push @pfconnector_ips, $management_network->{Tip};
  @pfconnector_ips = uniq sort @pfconnector_ips;
  for my $ip (@pfconnector_ips) {
    util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="23001-23256/tcp" source address="'.$ip.'" accept' );
  }
}

sub generate_eduroam_radius_config {
  # eduroam RADIUS virtual-server
  if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
    my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
    my $eduroam_listening_port = $eduroam_authentication_source[0]{'auth_listening_port'};    # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
    my $eduroam_listening_port_backend = $eduroam_listening_port + 10;

    my $mgnt_zone =  $management_network->{Tip};
    util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="'.$eduroam_listening_port.'/tcp" accept' );
    util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="'.$eduroam_listening_port.'/udp" accept' );
    util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="'.$eduroam_listening_port_backend.'/tcp" accept' );
    util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="'.$eduroam_listening_port_backend.'/udp" accept' );

    foreach my $radius_zone ( @radius_ints ) {
      util_apply_rich_rule( $radius_zone, 'rule family="ipv4" port="'.$eduroam_listening_port.'/tcp" accept' );
      util_apply_rich_rule( $radius_zone, 'rule family="ipv4" port="'.$eduroam_listening_port.'/udp" accept' );
      util_apply_rich_rule( $radius_zone, 'rule family="ipv4" port="'.$eduroam_listening_port_backend.'/tcp" accept' );
      util_apply_rich_rule( $radius_zone, 'rule family="ipv4" port="'.$eduroam_listening_port_backend.'/udp" accept' );
    }
  }
  else {
    get_logger->info( "# eduroam integration is not configured" );
  }
}

sub generate_inline_enforcement {
  if ( is_inline_enforcement_enabled() ) {
    # Note: I'm giving references to this guy here so he can directly mess with the tables
    generate_inline_rules();
    # Mangle
    generate_inline_if_src_to_chain($FW_TABLE_MANGLE);
    generate_mangle_rules();
    # NAT chain targets and redirections (other rules injected by generate_inline_rules)
    generate_inline_if_src_to_chain($FW_TABLE_NAT);
    generate_nat_redirect_rules();
  }

}


sub generate_inline_rules {
  my $logger = get_logger();
  $logger->info("Adding DNS DNAT rules for unregistered and isolated inline clients.");

  foreach my $network ( keys %ConfigNetworks ) {
    # We skip non-inline networks/interfaces
    next if ( !pf::config::is_network_type_inline($network) );
    # Set the correct gateway if it is an inline Layer 3 network
    my $dev = $NetworkConfig{$network}{'interface'}{'int'};
    my $gateway = $Config{"interface $dev"}{'ip'};

    my $rule = "--protocol udp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
    util_apply_direct_add_rule("ipv4 filter $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_UNREG --jump DNAT --to $gateway");
    util_apply_direct_add_rule("ipv4 filter $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump DNAT --to $gateway";

    if (isenabled($ConfigNetworks{$network}{'split_network'}) && defined($ConfigNetworks{$network}{'reg_network'}) && $ConfigNetworks{$network}{'reg_network'} ne '') {
      $rule = "--protocol udp --destination-port 53 -s $ConfigNetworks{$network}{'reg_network'}";
      util_apply_direct_add_rule("ipv4 filter $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_UNREG --jump DNAT --to $gateway");
      util_apply_direct_add_rule("ipv4 filter $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump DNAT --to $gateway");
    }

    if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
      $logger->info("Adding Proxy interception rules");
      foreach my $intercept_port ( split(',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
        my $rule = "--protocol tcp --destination-port $intercept_port -s $network/$ConfigNetworks{$network}{'netmask'}";
        util_apply_direct_add_rule("ipv4 filter $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_UNREG --jump DNAT --to $gateway");
        util_apply_direct_add_rule("ipv4 filter $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump DNAT --to $gateway");
      }
    }
  }

  if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
    $logger->info("Adding Proxy interception rules");
    foreach my $intercept_port ( split(',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
      util_apply_direct_add_rule("ipv4 filter $FW_FILTER_INPUT_INT_INLINE --protocol tcp --match tcp --dport $intercept_port --match mark --mark 0x$IPTABLES_MARK_UNREG  --jump ACCEPT");
      util_apply_direct_add_rule("ipv4 filter $FW_FILTER_INPUT_INT_INLINE --protocol tcp --match tcp --dport $intercept_port --match mark --mark 0x$IPTABLES_MARK_UNREG  --jump ACCEPT");
      util_apply_direct_add_rule("ipv4 filter $FW_FILTER_INPUT_INT_INLINE --protocol tcp --match tcp --dport $intercept_port --match mark --mark 0x$IPTABLES_MARK_REG  --jump DROP");
    }
  }

  $logger->info("Adding NAT Masquarade statement (PAT)");
  util_apply_direct_add_rule("ipv4 filter $FW_POSTROUTING_INT_INLINE --jump MASQUERADE");

  $logger->info("Addind ROUTED statement");
  util_apply_direct_add_rule("ipv4 filter $FW_POSTROUTING_INT_INLINE_ROUTED --jump ACCEPT");

  $logger->info("building firewall to accept registered users through inline interface");
  my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));

  if ($passthrough_enabled) {
    util_apply_direct_add_rule("ipv4 filter $FW_FILTER_FORWARD_INT_INLINE --match mark --mark 0x$IPTABLES_MARK_UNREG -m set --match-set pfsession_passthrough dst,dst --jump ACCEPT");
    util_apply_direct_add_rule("ipv4 filter $FW_FILTER_FORWARD_INT_INLINE --match mark --mark 0x$IPTABLES_MARK_ISOLATION -m set --match-set pfsession_isol_passthrough dst,dst --jump ACCEPT");
  }
  util_apply_direct_add_rule("ipv4 filter $FW_FILTER_FORWARD_INT_INLINE --match mark --mark 0x$IPTABLES_MARK_REG --jump ACCEPT");
}

sub generate_inline_if_src_to_chain {
  my $table = shift;
  my $logger = get_logger();
  # internal interfaces handling
  foreach my $interface (@internal_nets) {
    my $dev = $interface->tag("int");
    my $enforcement_type = $Config{"interface $dev"}{'enforcement'};

    # inline enforcement
    if (is_type_inline($enforcement_type)) {
      # send everything from inline interfaces to the inline chain
      util_apply_direct_add_rule("ipv4 filter PREROUTING --in-interface $dev --jump $FW_PREROUTING_INT_INLINE");
      util_apply_direct_add_rule("ipv4 filter POSTROUTING --out-interface $dev --jump $FW_POSTROUTING_INT_INLINE");
    }
  }

  # POSTROUTING
  if ( $table ne $FW_TABLE_NAT ) {
    my @values = split(',', get_inline_snat_interface());
    foreach my $val (@values) {
      util_apply_direct_add_rule("ipv4 filter POSTROUTING --out-interface $val --jump $FW_POSTROUTING_INT_INLINE");
    }
  }

  # NAT POSTROUTING
  if ($table eq $FW_TABLE_NAT) {
    my $mgmt_int = $management_network->tag("int");

    # Every marked packet should be NATed
    # Note that here we don't wonder if they should be allowed or not. This is a filtering step done in FORWARD.
    foreach ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
      my @values = split(',', get_inline_snat_interface());
      foreach my $val (@values) {
        foreach my $network ( keys %ConfigNetworks ) {
          next if ( !pf::config::is_network_type_inline($network) );
          my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
          my $nat = $ConfigNetworks{$network}{'nat_enabled'};
          if (defined ($nat) && (isdisabled($nat))) {
            util_apply_direct_add_rule("ipv4 filter POSTROUTING -s $network/$inline_obj->{BITS} --out-interface $val --match mark --mark 0x$_ --jump $FW_POSTROUTING_INT_INLINE_ROUTED");
          }
        }
        util_apply_direct_add_rule("ipv4 filter POSTROUTING --out-interface $val --match mark --mark 0x$_ --jump $FW_POSTROUTING_INT_INLINE");
      }
    }
  }
}

sub generate_mangle_rules {
  $tags{'mangle_prerouting_inline'} .= $self->generate_mangle_rules();                # TODO: These two should be combined... 2015.05.25 dwuelfrath@inverse.ca
  my ($self) =@_;
  my $logger = get_logger();
  my $mangle_rules = '';
  my @ops = ();

  # pfdhcplistener in most cases will be enforcing access
  # however we insert these marks on startup in case PacketFence is restarted

  # default catch all: mark unreg
  util_apply_direct_add_rule("ipv4 filter $FW_PREROUTING_INT_INLINE --jump MARK --set-mark 0x$IPTABLES_MARK_UNREG");
  foreach my $network ( keys %ConfigNetworks ) {
    next if ( !pf::config::is_network_type_inline($network) );
    foreach my $IPTABLES_MARK ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
      my $rule = "";
      if ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE_L3$/i) {
        $rule = "$FW_PREROUTING_INT_INLINE -m set --match-set pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network src ";
      } else {
        $rule .= "$FW_PREROUTING_INT_INLINE -m set --match-set pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network src,src ";
      }
      $rule .= "--jump MARK --set-mark 0x$IPTABLES_MARK";
      util_apply_direct_add_rule("ipv4 filter $rule");
    }
  }

  # Build lookup table for MAC/IP mapping
  my @iplog_open = pf::ip4log::list_open();
  my %iplog_lookup = map { $_->{'mac'} => $_->{'ip'} } @iplog_open;

  # mark registered nodes that should not be isolated
  # TODO performance: mark all *inline* registered users only
  my @registered = nodes_registered_not_violators();
  foreach my $row (@registered) {
    foreach my $network ( keys %ConfigNetworks ) {
      next if ( !pf::config::is_network_type_inline($network) );
      my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
      my $mac = $row->{'mac'};
      my $iplog = $iplog_lookup{clean_mac($mac)};
      if (defined $iplog) {
        my $ip = new NetAddr::IP::Lite clean_ip($iplog);
        if ($net_addr->contains($ip)) {
          if ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE_L3$/i) {
            push(@ops, "add pfsession_$mark_type_to_str{$IPTABLES_MARK_REG}\_$network $iplog");
            push(@ops, "add PF-iL3_ID$row->{'category_id'}_$network $iplog");
          } else {
            push(@ops, "add pfsession_$mark_type_to_str{$IPTABLES_MARK_REG}\_$network $iplog,$mac");
            push(@ops, "add PF-iL2_ID$row->{'category_id'}_$network $iplog");
          }
        }
      }
    }
  }

  # mark all open security_events
  # TODO performance: only those whose's last connection_type is inline?
  require pf::security_event;
  my @macarray = pf::security_event::security_event_view_open_uniq();
  if ( $macarray[0] ) {
    foreach my $row (@macarray) {
      foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
        my $mac = $row->{'mac'};
        my $iplog = $iplog_lookup{clean_mac($mac)};
        if (defined $iplog) {
          my $ip = new NetAddr::IP::Lite clean_ip($iplog);
          if ($net_addr->contains($ip)) {
            if ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE_L3$/i) {
              push(@ops, "add pfsession_$mark_type_to_str{$IPTABLES_MARK_ISOLATION}\_$network $iplog");
            } else {
              push(@ops, "add pfsession_$mark_type_to_str{$IPTABLES_MARK_ISOLATION}\_$network $iplog,$mac");
            }
          }
        }
      }
    }
  }

  if (@ops) {
    my $cmd = "LANG=C sudo ipset restore 2>&1";
    open(IPSET, "| $cmd") || die "$cmd failed: $!\n";
    print IPSET join("\n", @ops);
    close IPSET;
  }
}

sub generate_nat_redirect_rules {
  $tags{'nat_prerouting_inline'} .= $self->generate_nat_redirect_rules();
  my $logger = get_logger();
  my $rule = '';

  # Exclude the OAuth from the DNAT
  my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));

  if ($passthrough_enabled) {
    $rule = "$FW_PREROUTING_INT_INLINE -m set --match-set pfsession_passthrough dst,dst ".
    "--match mark --mark 0x$IPTABLES_MARK_UNREG --jump ACCEPT";
    util_apply_direct_add_rule("ipv4 filter $rule");
    $rule = "$FW_PREROUTING_INT_INLINE -m set --match-set pfsession_isol_passthrough dst,dst ".
    "--match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump ACCEPT";
    util_apply_direct_add_rule("ipv4 filter $rule");
  }

  # Now, do your magic
  foreach my $redirectport ( split( /\s*,\s*/, $Config{'inline'}{'ports_redirect'} ) ) {
    my ( $port, $protocol ) = split( "/", $redirectport );
    foreach my $network ( keys %ConfigNetworks ) {
      # We skip non-inline networks/interfaces
      next if ( !pf::config::is_network_type_inline($network) );
      # Set the correct gateway if it is an inline Layer 3 network
      my $dev = $NetworkConfig{$network}{'interface'}{'int'};
      my $gateway = $Config{"interface $dev"}{'ip'};

      # Destination NAT to the portal on the ISOLATION mark
      $rule =
      " $FW_PREROUTING_INT_INLINE --protocol $protocol --destination-port $port -s $network/$ConfigNetworks{$network}{'netmask'} " .
      "--match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump DNAT --to $gateway";
      util_apply_direct_add_rule("ipv4 filter $rule");
    }
  }
}

sub generate_interception_rules {
  my $logger = get_logger();
  # internal interfaces handling
  foreach my $interface (@internal_nets) {
    my $dev = $interface->tag("int");
    my $enforcement_type = $Config{"interface $dev"}{'enforcement'};
    my $net_addr = NetAddr::IP->new($Config{"interface $dev"}{'ip'},$Config{"interface $dev"}{'mask'});
    # vlan enforcement
    if ($enforcement_type eq $IF_ENFORCEMENT_VLAN) {
      # send everything from vlan interfaces to the vlan chain
      $$nat_if_src_to_chain .= "-A PREROUTING --in-interface $dev --jump $FW_PREROUTING_INT_VLAN\n";
      foreach my $network ( keys %ConfigNetworks ) {
        next if (pf::config::is_network_type_inline($network));
        my %net = %{$ConfigNetworks{$network}};
        my $ip;
        if (defined($net{'next_hop'})) {
          $ip = new NetAddr::IP::Lite clean_ip($net{'next_hop'});
        } else {
          $ip = new NetAddr::IP::Lite clean_ip($net{'gateway'});
        }
        if ($net_addr->contains($ip)) {
          my $destination = $Config{"interface $dev"}{'vip'} || $Config{"interface $dev"}{'ip'};
          if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
            foreach my $intercept_port ( split( ',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
              my $rule = "--protocol tcp --destination-port $intercept_port -s $network/$ConfigNetworks{$network}{'netmask'}";
              util_apply_direct_add_rule("ipv4 filter $FW_PREROUTING_INT_VLAN $rule --jump DNAT --to $destination");
            }
          }
          my $rule = "--protocol udp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
          util_apply_direct_add_rule("ipv4 filter $FW_PREROUTING_INT_VLAN $rule --jump DNAT --to $destination");
          $rule = "--protocol tcp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
          util_apply_direct_add_rule("ipv4 filter $FW_PREROUTING_INT_VLAN $rule --jump DNAT --to $destination");
        }
      }
    }
  }
  if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
    foreach my $intercept_port ( split( ',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
      my $rule = "--protocol tcp --destination-port $intercept_port";
      util_apply_direct_add_rule("ipv4 filter $FW_FILTER_INPUT_INT_VLAN $rule --jump ACCEPT");
    }
  }
}

sub generate_dnat_from_docker {
  #DNAT traffic from docker to mgmt ip
  my $logger = get_logger();
  my $mgmt_ip = (defined($management_network->tag('vip'))) ? $management_network->tag('vip') : $management_network->tag('ip');
  util_apply_direct_add_rule("ipv4 filter PREROUTING --protocol udp -s 100.64.0.0/10 -d $mgmt_ip --jump DNAT --to 100.64.0.1");
}

sub generate_passthrough_rules {
  # OAuth
  my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
  if ($passthrough_enabled) {
    my $logger = get_logger();
    $logger->info("Adding Forward rules to allow connections to the OAuth2 Providers and passthrough.");
    if ($passthrough) {
      util_apply_direct_add_rule("ipv4 filter $FW_FILTER_FORWARD_INT_VLAN -m set --match-set pfsession_passthrough dst,dst --jump ACCEPT");
      util_apply_direct_add_rule("ipv4 filter $FW_FILTER_FORWARD_INT_VLAN -m set --match-set pfsession_passthrough src,src --jump ACCEPT");
      util_apply_direct_add_rule("ipv4 filter $FW_FILTER_FORWARD_INT_ISOL_VLAN -m set --match-set pfsession_isol_passthrough dst,dst --jump ACCEPT");
      util_apply_direct_add_rule("ipv4 filter $FW_FILTER_FORWARD_INT_ISOL_VLAN -m set --match-set pfsession_isol_passthrough src,src --jump ACCEPT");
    }

    # add passthroughs required by the provisionings
    generate_provisioning_passthroughs();

    $logger->info("Adding IP based passthrough for connectivitycheck.gstatic.com");
    # Allow the host for the onboarding of devices
    my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough 172.217.13.99,80 2>&1");
    pf_run($cmd);
    $cmd = untaint_chain("sudo ipset --add pfsession_passthrough 172.217.13.99,443 2>&1");
    pf_run($cmd);

    $logger->info("Adding NAT Masquerade statement.");
    my ($SNAT_ip, $mgmt_int);
    if ($management_network) {
      $mgmt_int = $management_network->tag("int");
      if (defined($management_network->{'Tip'}) && $management_network->{'Tip'} ne '') {
        if (defined($management_network->{'Tvip'}) && $management_network->{'Tvip'} ne '') {
          $SNAT_ip = $management_network->{'Tvip'};
        } else {
          $SNAT_ip = $management_network->{'Tip'};
        }
      }
    }

    if ($SNAT_ip) {
      foreach my $network ( keys %ConfigNetworks ) {
        my $network_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
        if ( pf::config::is_network_type_inline($network) ) {
          my $nat = $ConfigNetworks{$network}{'nat_enabled'};
          if (defined ($nat) && (isenabled($nat))) {
            util_apply_direct_add_rule("ipv4 filter POSTROUTING -s $network/$network_obj->{BITS} -o $mgmt_int -j SNAT --to $SNAT_ip");
          }
        } else {
          util_apply_direct_add_rule("ipv4 filter POSTROUTING -s $network/$network_obj->{BITS} -o $mgmt_int -j SNAT --to $SNAT_ip");
        }
      }
    }

    # Enable nat if we defined another interface to route to internet
    my @ints = split(',', get_network_snat_interface());
    foreach my $int (@ints) {
      my $if   = IO::Interface::Simple->new($int);
      next unless defined($if);
      foreach my $network ( keys %ConfigNetworks ) {
        my $network_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
        if ( pf::config::is_network_type_inline($network) ) {
          my $nat = $ConfigNetworks{$network}{'nat_enabled'};
          if (defined ($nat) && (isenabled($nat))) {
            util_apply_direct_add_rule("ipv4 filter POSTROUTING -s $network/$network_obj->{BITS} -o $int -j SNAT --to $if->address");
          }
        } else {
          util_apply_direct_add_rule("ipv4 filter POSTROUTING -s $network/$network_obj->{BITS} -o $int -j SNAT --to $if->address");
        }
      }
    }
    generate_passthrough_rules();
    generate_netflow_rules();
  }
}

sub generate_provisioning_passthroughs {
  my $logger = get_logger();
  $logger->debug("Installing passthroughs for provisioning");
  foreach my $config (tied(%ConfigProvisioning)->search(type => 'kandji')) {
    $logger->info("Adding passthrough for Kandji");
    my $enroll_host = $config->{enroll_url} ? URI->new($config->{enroll_url})->host : $config->{host};
    my $enroll_port = $config->{enroll_url} ? URI->new($config->{enroll_url})->port : $config->{port};
    my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough ".$enroll_host.",".$enroll_port." 2>&1");
    my @lines  = pf_run($cmd);
  }

  foreach my $config (tied(%ConfigProvisioning)->search(type => 'mobileiron')) {
    $logger->info("Adding passthrough for MobileIron");
    # Allow the host for the onboarding of devices
    my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$config->{boarding_port} 2>&1");
    my @lines  = pf_run($cmd);
    # Allow http communication with the MobileIron server
    $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$HTTP_PORT 2>&1");
    @lines  = pf_run($cmd);
    # Allow https communication with the MobileIron server
    $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$HTTPS_PORT 2>&1");
    @lines  = pf_run($cmd);
  }

  foreach my $config (tied(%ConfigProvisioning)->search(type => 'opswat')) {
    $logger->info("Adding passthrough for OPSWAT");
    # Allow http communication with the OSPWAT server
    my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTP_PORT 2>&1");
    my @lines  = pf_run($cmd);
    # Allow https communication with the OPSWAT server
    $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTPS_PORT 2>&1");
    @lines  = pf_run($cmd);
  }

  foreach my $config (tied(%ConfigProvisioning)->search(type => 'sentinelone')) {
    $logger->info("Adding passthrough for SentinelOne");
    # Allow http communication with the SentinelOne server
    my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTP_PORT 2>&1");
    my @lines  = pf_run($cmd);
    # Allow https communication with the SentinelOne server
    $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTPS_PORT 2>&1");
    @lines  = pf_run($cmd);
  }
}


sub generate_netflow_rules {
  if (netflow_enabled()) {
    util_apply_direct_add_rule("ipv4 filter -I FORWARD -j NETFLOW");
  }
}

sub generate_kafka_firewalld_config {
  my $mgnt_zone =  $management_network->{Tip};
  for my $client (@{$ConfigKafka{iptables}{clients}}) {
    util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="9092/tcp" source address="'.$client.'" accept' );
  }
  for my $ip (@{$ConfigKafka{iptables}{cluster_ips}}) {
    util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="29092/tcp" source address="'.$ip.'" accept' );
    util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="9092/tcp" source address="'.$ip.'" accept' );
    util_apply_rich_rule( $mgnt_zone, 'rule family="ipv4" port="9093/tcp" source address="'.$ip.'" accept' );
  }
}


# need a function that return information like a wrapper of firewalld-cmd
# need a function that return services from a zone
# need a function that check integrity for zones and services

# need a function that add/remove a service into/from a zone
sub service_to_zone {
  my $service   = shift;
  my $status    = shift;
  my $zone      = shift;
  my $permanent = shift;
  my $p_value   = "--permanent";
 
  #$service   ||= "noservice";
  #$status    ||= "add";
  #$zone      ||= "eth0";
  #$permanent ||= "yes";

  if ($service ne "noservice") {
    print("provide a service");
    return 0 ;
  }

  if ( $status ne "add" && $status ne "remove") {
    print("Status $status is unknown. Should be 'add' or 'remove'");
    return 0 ;
  }

  if ( not service_is_in_default( $service ) ) {
    print("Please run generate config to create file services");
    return 0 ;
  }

  if ( $permanent ne "yes" ) {
    $p_value="";
  }

  # handle service's file
  if ( $status eq "add" ){
    service_copy_from_default_to_applied($service);
  } else {
    service_remove_from_applied( $service );
  }

  # handle service in zone
  if ( $status eq "add" ) {
    print("Service $service added from Zone $zone configuration status:");
  } else {
    print("Service $service removed from Zone $zone configuration status:");
  }
  if (firewalld_action("--zone=$zone --$status-service $service $p_value")){
    return reload_firewalld();
  } else {
    return 1 ;
  }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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
