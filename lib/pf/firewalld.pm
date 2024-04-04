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
use File::Path qw(rmtree);

use IO::Interface::Simple;
use pf::log;
use Readonly;
use NetAddr::IP;
use List::MoreUtils qw(uniq);
use pf::constants;
use pf::config::cluster;
use File::Slurp qw(read_file);
use URI ();
use pf::services;
use pf::Firewalld::util;

BEGIN {
  use Exporter ();
  our ( @ISA, @EXPORT );
  @ISA = qw(Exporter);
  @EXPORT = qw(
    firewalld_clean_configs
    firewalld_clean_pfconf_configs
    firewalld_generate_configs
    firewalld_generate_pfconf_configs
    fd_create_all_zones
    fd_services_rules
    fd_keepalived_rules
    fd_radiusd_lb_rules
    fd_proxysql_rules
    fd_haproxy_admin_rules
    fd_httpd_webservices_rules
    fd_httpd_aaa_rules
    fd_api_frontend_rules
    fd_httpd_portal_rules
    fd_haproxy_db_rules
    fd_haproxy_portal_rules
    fd_radiusd_acct_rules
    fd_radiusd_auth_rules
    fd_radiusd_cli_rules
    fd_pfdns_rules
    fd_pfdhcp_rules
    fd_pfipset_rules
    fd_netdata_rules
    fd_pfconnector_server_rules
    fd_galera_autofix_rules
    fd_mariadb_rules
    fd_mysql_prob_rules
    fd_kafka_rules
    fd_docker_dnat_rules
    fd_fingerbank_collector_rules
    fd_radiusd_eduroam_rules
    fd_firewalld_rules
  );
}

use pf::config qw(
    %ConfigNetworks
    %Config
    %ConfigProvisioning
    $IPTABLES_MARK_UNREG
    $IF_ENFORCEMENT_VLAN
    $IF_ENFORCEMENT_DNS
    $IPTABLES_MARK_ISOLATION
    $IPTABLES_MARK_REG
    is_inline_enforcement_enabled
    is_type_inline
    netflow_enabled
    $management_network
    @inline_enforcement_nets
    @internal_nets
    @listen_ints
    @ha_ints
    @portal_ints
    @radius_ints
    @dhcp_ints
    @dhcplistener_ints
    @dns_ints
    $NET_TYPE_INLINE_L3
    %mark_type_to_str
);
use pf::file_paths qw(
    $generated_conf_dir
    $conf_dir
    $firewalld_config_path_generated
    $firewalld_config_path_applied
);
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

# This is the content that needs to match in the iptable rules for the service
# to be considered as running
Readonly my $FW_FILTER_INPUT_INT_INLINE => 'input-internal-inline-if';
Readonly my $FW_FILTER_FORWARD_INT_INLINE => 'forward-internal-inline-if';
Readonly my $FW_PREROUTING_INT_INLINE => 'prerouting-int-inline-if';
Readonly my $FW_POSTROUTING_INT_INLINE => 'postrouting-int-inline-if';
Readonly my $FW_POSTROUTING_INT_INLINE_ROUTED => 'postrouting-inline-routed';
Readonly my $FW_PREROUTING_INT_VLAN => 'prerouting-int-vlan-if';

tie our %NetworkConfig, 'pfconfig::cached_hash', "resource::network_config($host_id)";
tie our %ConfigKafka, 'pfconfig::cached_hash', "config::Kafka";

sub firewalld_clean_configs {
  fd_firewalld_rules("remove");
  firewalld_clean_pfconf_configs();
}

sub firewalld_clean_pfconf_configs {
  rmtree $firewalld_config_path_generated;
}

sub firewalld_generate_configs {
  #firewalld_generate_pfconf_configs();
  fd_create_all_zones();
  fd_firewalld_rules("add");
  fd_services_rules("add");
}

sub firewalld_generate_pfconf_configs {
  pf_run("sudo systemctl stop packetfence-iptables");
  pf_run("sudo systemctl disable packetfence-iptables");
  generate_firewalld_file_config();
  generate_lockdown_whitelist_config();
  generate_helpers_config();
  generate_icmptypes_config();
  generate_ipsets_config();
  generate_services_config();
  generate_zones_config();
  generate_policies_config();
}

sub fd_create_all_zones {
  my $name_files = util_get_name_files_from_dir("zones");
  foreach my $tint ( @listen_ints ) {
    if ( defined $name_files && exists $name_files->{$tint} ) {
      get_logger->error( "Network Interface $tint  is handle by configuration files" );
    } else {
      util_firewalld_job( " --permanent --delete-zone=$tint" );
      util_firewalld_job( " --permanent --new-zone=$tint" );
      util_firewalld_job( " --permanent --zone=$tint --set-target=DROP");
      util_firewalld_job( " --permanent --zone=$tint --change-interface=$tint");
      if ( scalar grep( { $_ eq $tint } @dhcplistener_ints ) ) { # Why DHCP interfaces need ssh?
        service_to_zone($tint, "add", "ssh");
      }
    }
  }
  my $tint =  $management_network->{Tint};
  util_set_default_zone( $tint );
  service_to_zone($tint, "add", "ssh");
  service_to_zone($tint, "add", "haproxy-admin");
  util_reload_firewalld();
}

# need to get services that are running and use the dedicated function to restart accordingly
sub fd_services_rules {
  my $action = shift;
  my $services = [qw(
      docker.service
      packetfence-api-frontend.service
      packetfence-base.slice
      packetfence-base.target
      packetfence-cluster.target
      packetfence-config.service
      packetfence-docker-iptables.service
      packetfence-fingerbank-collector.service
      packetfence-firewalld.service
      packetfence-galera-autofix.service
      packetfence-haproxy-admin.service
      packetfence-haproxy-db.service
      packetfence-haproxy-portal.service
      packetfence-httpd.aaa.service
      packetfence-httpd.admin_dispatcher.service
      packetfence-httpd.dispatcher.service
      packetfence-httpd.portal.service
      packetfence-httpd.webservices.service
      packetfence-ip6tables.service
      packetfence-iptables.service
      packetfence-kafka.service
      packetfence-keepalived.service
      packetfence-mariadb.service
      packetfence-mysql-probe.service
      packetfence-netdata.service
      packetfence-ntlm-auth-api-domain@.service
      packetfence-ntlm-auth-api.service
      packetfence-pfacct.service
      packetfence-pfconnector-client.service
      packetfence-pfconnector-server.service
      packetfence-pfcron.service
      packetfence-pfdetect.service
      packetfence-pfdhcp.service
      packetfence-pfdhcplistener.service
      packetfence-pfdns.service
      packetfence-pffilter.service
      packetfence-pfipset.service
      packetfence-pfldapexplorer.service
      packetfence-pfperl-api.service
      packetfence-pfpki.service
      packetfence-pfqueue-backend.service
      packetfence-pfqueue-go.service
      packetfence-pfqueue-perl.service
      packetfence-pfsetacls.service
      packetfence-pfsso.service
      packetfence-pfstats.service
      packetfence-proxysql.service
      packetfence-radiusd-acct.service
      packetfence-radiusd-auth.service
      packetfence-radiusd-cli.service
      packetfence-radiusd-eduroam.service
      packetfence-radiusd-load_balancer.service
      packetfence-radsniff.service
      packetfence-redis-cache.service
      packetfence-redis_ntlm_cache.service
      packetfence-redis_queue.service
      packetfence-snmptrapd.service
      packetfence-tracking-config.service
      )];
  my $states = pf::services::getServiveState($services,[qw(Id ActiveState)]);
  foreach my $state ( @{ $states } ) {
    if ( $state->{"ActiveState"} eq "active" ) {
      if ( $state->{"Id"} eq "packetfence-api-frontend.service" ){
        fd_api_frontend_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-keepalived.service" ){
        fd_keepalived_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-haproxy-portal.service" ){
        fd_haproxy_portal_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-haproxy-admin.service" ){
        fd_haproxy_admin_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-httpd.webservices.service" ){
        fd_httpd_webservices_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-httpd.aaa.service" ){
        fd_httpd_aaa_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-httpd.portal.service" ){
        fd_httpd_portal_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-haproxy-db.service" ){
        fd_haproxy_db_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-pfdns.service" ){
        fd_pfdns_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-pfdhcp.service" ){
        fd_pfdhcp_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-pfipset.service" ){
        fd_pfipset_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-netdata.service" ){
        fd_netdata_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-pfconnector-server.service" ){
        fd_pfconnector_server_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-galera-autofix.service" ){
        fd_galera_autofix_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-mariadb.service" ){
        fd_mariadb_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-mysql-probe.service" ){
        fd_mysql_prob_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-kafka.service" ){
        fd_kafka_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-fingerbank-collector.service" ){
        fd_fingerbank_collector_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-radiusd-eduroam.service" ){
        fd_radiusd_eduroam_rules($action);
      } elsif ( $state->{"Id"} eq "docker.service" ){
        fd_docker_dnat_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-radiusd-cli.service" ){
        fd_radiusd_cli_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-radiusd-auth.service" ){
        fd_radiusd_auth_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-radiusd-acct.service" ){
        fd_radiusd_acct_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-proxysql.service" ){
        fd_proxysql_rules($action);
      } elsif ( $state->{"Id"} eq "packetfence-radiusd-load_balancer.service" ){
        fd_radiusd_lb_rules($action);
      }
    }
  }
}

sub fd_keepalived_rules {
  foreach my $tint ( @listen_ints ){
    # Never remove, used several time
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -d 224.0.0.0/8 -j ACCEPT", "add" );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p vrrp -j ACCEPT", "add" ) if ($cluster_enabled);
    util_reload_firewalld();
  }
}

sub fd_radiusd_lb_rules {
  my $action = shift;
  foreach my $network ( @radius_ints ) {
    my $tint =  $network->{Tint};
    service_to_zone($tint, $action, "radius_lb");
  }
  my $tint =  $management_network->{Tint};
  service_to_zone($tint, $action, "radius_lb");
  util_reload_firewalld();
}

sub fd_proxysql_rules {
  # Proxysql
  my $action = shift;
  my $tint =  $management_network->{Tint};
  service_to_zone($tint, $action, "proxysql");
  util_reload_firewalld();
}

sub fd_haproxy_admin_rules {
  # Web Admin
  my $action = shift;
  my $tint =  $management_network->{Tint};
  my $web_admin_port = $Config{'ports'}{'admin'};
  util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp --match tcp --dport $web_admin_port -j ACCEPT", $action );
  util_reload_firewalld();
}

sub fd_httpd_webservices_rules {
  # Webservices
  my $action = shift;
  my $tint =  $management_network->{Tint};
  my $webservices_port = $Config{'ports'}{'soap'};
  util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp --match tcp --dport $webservices_port -j ACCEPT", $action );
  util_reload_firewalld();
}

sub fd_httpd_aaa_rules {
  # AAA
  my $action = shift;
  my $tint =  $management_network->{Tint};
  my $aaa_port = $Config{'ports'}{'aaa'};
  util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp --match tcp --dport $aaa_port -j ACCEPT", $action );
  util_reload_firewalld();
}

sub fd_api_frontend_rules {
  # Unified API
  my $action = shift;
  my $mgnt_zone =  $management_network->{Tint};
  my $unifiedapi_port = $Config{'ports'}{'unifiedapi'};
  util_direct_rule( "ipv4 filter INPUT 0 -i $mgnt_zone -p tcp --match tcp --dport $unifiedapi_port -j ACCEPT", $action );
  service_to_zone( $mgnt_zone, $action, "api_frontend");
  util_reload_firewalld();
}

sub fd_httpd_portal_rules {
  # httpd.portal modstatus
  my $action = shift;
  my $mgnt_zone =  $management_network->{Tint};
  my $httpd_portal_modstatus = $Config{'ports'}{'httpd_portal_modstatus'};
  util_direct_rule( "ipv4 filter INPUT 0 -i $mgnt_zone -p tcp --match tcp --dport $httpd_portal_modstatus -j ACCEPT", $action );
  foreach my $tint ( @portal_ints ) {
    service_to_zone($tint, $action, "http");
    service_to_zone($tint, $action, "https");
    service_to_zone($tint, $action, "web-portal");
  }
  util_reload_firewalld();
}

sub fd_haproxy_db_rules {
  my $action = shift;
  my $mgnt_zone =  $management_network->{Tint};
  service_to_zone($mgnt_zone, $action, "haproxy-db");
  util_reload_firewalld();
}

sub fd_haproxy_portal_rules {
  my $action = shift;
  foreach my $tint (@ha_ints){
    service_to_zone($tint, $action, "haproxy-portal");
  }
  util_reload_firewalld();
}

sub fd_radiusd_acct_rules {
  my $action = shift;
  foreach my $network ( @radius_ints ) {
    my $tint =  $network->{Tint};
    service_to_zone($tint, $action, "radius_acct");
    service_to_zone($tint, $action, "radius_acct_clu") if ($cluster_enabled);
  }
  util_reload_firewalld();
}

sub fd_radiusd_auth_rules {
  my $action = shift;
  foreach my $network ( @radius_ints ) {
    my $tint =  $network->{Tint};
    service_to_zone($tint, $action, "radius_auth");
    service_to_zone($tint, $action, "radius_auth_clu") if ($cluster_enabled);
  }
  util_reload_firewalld();
}

sub fd_radiusd_cli_rules {
  my $action = shift;
  foreach my $network ( @radius_ints ) {
    my $tint =  $network->{Tint};
    service_to_zone($tint, $action, "radius_cli");
    service_to_zone($tint, $action, "radius_cli_clu") if ($cluster_enabled);
  }
  util_reload_firewalld();
}

sub get_network_type_and_chain {
  my $ip = shift;
  my $type = $pf::config::NET_TYPE_VLAN_REG;
  my $chain = "input-internal-vlan-if";
  foreach my $network ( keys %ConfigNetworks ) {
    # We skip non-inline networks/interfaces
    next if ( pf::config::is_network_type_inline($network) );
    if ( $ConfigNetworks{$network}{'type'} eq $pf::config::NET_TYPE_VLAN_ISOL ) {
      my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
      my $ip_test = new NetAddr::IP::Lite clean_ip($ip);
      if ($net_addr->contains($ip_test)) {
        $type = $pf::config::NET_TYPE_VLAN_ISOL;
        $chain = "input-internal-isol_vlan-if";
      }
    }
  }
  return ($type,$chain);
}

sub fd_pfdns_rules {
  my $action = shift;
  foreach my $tint ( @dns_ints ) {
    service_to_zone($tint, $action, "dns");
  }
  foreach my $network ( @inline_enforcement_nets ) {
    my $tint =  $network->{Tint};
    service_to_zone($tint, $action, "dns");
  }
  # OAuth
  oauth_passthrough_rules();
  my $internal_portal_ip = $Config{captive_portal}{ip_address};
  foreach my $interface (@internal_nets) {
    my @all_dev_rules;
    my $tint = $interface->tag("int");
    my $ip = $interface->tag("vip") || $interface->tag("ip");
    my $enforcement_type = $Config{"interface $tint"}{'enforcement'};
    my $cluster_ip = $ConfigCluster{$CLUSTER}->{"interface $tint"}->{ip};

    if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
      if ($tint =~ m/(\w+):\d+/) {
        $tint = $1;
      }
      util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $internal_portal_ip -p tcp -m tcp --dport 53 -j ACCEPT", $action );
      util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $internal_portal_ip -p udp -m udp --dport 53 -j ACCEPT", $action );
    }
  }
  util_reload_firewalld();
}

sub oauth_passthrough_rules {
  my $action = shift;
  # OAuth
  my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
  if ($passthrough_enabled) {
    my $logger = get_logger();
    $logger->info("Adding Forward rules to allow connections to the OAuth2 Providers and passthrough.");
    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
    my $isolation_passthrough_enabled = isenabled($Config{'fencing'}{'isolation_passthrough'});
    foreach my $interface (@internal_nets) {
      my $tint = $interface->tag("int");
      my $ip = $interface->tag("vip") || $interface->tag("ip");
      my $enforcement_type = $Config{"interface $tint"}{'enforcement'};

      my $cluster_ip = $ConfigCluster{$CLUSTER}->{"interface $tint"}->{ip};
      # VLAN enforcement
      if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
        if ($tint =~ m/(\w+):\d+/) {
            $tint = $1;
        }
        my ($type,$chain) = get_network_type_and_chain($ip);
        if ($passthrough_enabled && ($type eq $pf::config::NET_TYPE_VLAN_REG)) {
          util_direct_rule("ipv4 filter FORWARD 0 --in-interface $tint -m set --match-set pfsession_passthrough dst,dst --jump ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD 0 --in-interface $tint -m set --match-set pfsession_passthrough src,src --jump ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD 0 --out-interface $tint -m set --match-set pfsession_passthrough dst,dst --jump ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD 0 --out-interface $tint -m set --match-set pfsession_passthrough src,src --jump ACCEPT", $action );
        }
        if ($isolation_passthrough_enabled && ($type eq $pf::config::NET_TYPE_VLAN_ISOL)) {
          util_direct_rule("ipv4 filter FORWARD 0 --in-interface $tint -m set --match-set pfsession_isol_passthrough dst,dst --jump ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD 0 --in-interface $tint -m set --match-set pfsession_isol_passthrough src,src --jump ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD 0 --out-interface $tint -m set --match-set pfsession_isol_passthrough dst,dst --jump ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD 0 --out-interface $tint -m set --match-set pfsession_isol_passthrough src,src --jump ACCEPT", $action );
        }            
      }
    }
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
            util_direct_rule("ipv4 filter POSTROUTING 0 -s $network/$network_obj->{BITS} -o $mgmt_int -j SNAT --to $SNAT_ip", $action );
          }
        } else {
          util_direct_rule("ipv4 filter POSTROUTING 0 -s $network/$network_obj->{BITS} -o $mgmt_int -j SNAT --to $SNAT_ip", $action );
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
            util_direct_rule("ipv4 filter POSTROUTING 0 -s $network/$network_obj->{BITS} -o $int -j SNAT --to $if->address", $action );
          }
        } else {
          util_direct_rule("ipv4 filter POSTROUTING 0 -s $network/$network_obj->{BITS} -o $int -j SNAT --to $if->address", $action );
        }
      }
    }
  }
}

=item get_network_snat_interface

Return the list of network interface to enable SNAT for passthrough.

=cut

sub get_network_snat_interface {
  my ($self) = @_;
  my $logger = get_logger();
  if (defined ($Config{'network'}{'interfaceSNAT'}) && $Config{'network'}{'interfaceSNAT'} ne '') {
    return $Config{'network'}{'interfaceSNAT'};
  }
}

sub get_inline_snat_interface {
  my ($self) = @_;
  my $logger = get_logger();
  if (defined ($Config{'inline'}{'interfaceSNAT'}) && $Config{'inline'}{'interfaceSNAT'} ne '') {
    return $Config{'inline'}{'interfaceSNAT'};
  } else {
    return  $management_network->tag("int");
  }
}

sub fd_pfdhcp_rules {
  my $action = shift;
  my $logger = get_logger();
  foreach my $tint ( @dhcp_ints ) {
    service_to_zone($tint, $action, "dhcp");
  }
  foreach my $tint ( @dhcplistener_ints ) {
    service_to_zone($tint, $action, "dhcp");
  }
  my $internal_portal_ip = $Config{captive_portal}{ip_address};
  foreach my $interface ( @internal_nets ) {
    my @all_dev_rules;
    my $tint = $interface->tag("int");
    my $ip = $interface->tag("vip") || $interface->tag("ip");
    my $enforcement_type = $Config{"interface $tint"}{'enforcement'};
    my $cluster_ip = $ConfigCluster{$CLUSTER}->{"interface $tint"}->{ip};

    if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
      if ($tint =~ m/(\w+):\d+/) {
        $tint = $1;
      }
      my ($type,$chain) = get_network_type_and_chain($ip);
      if ( $type eq $pf::config::NET_TYPE_VLAN_REG && $chain eq "input-internal-isol_vlan-if" ) {
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $internal_portal_ip -p tcp -m tcp --dport 67 -j ACCEPT", $action );
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $internal_portal_ip -p udp -m udp --dport 67 -j ACCEPT", $action );
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $cluster_ip -p tcp -m tcp --dport 67 -j ACCEPT", $action ) if ($cluster_enabled);
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $cluster_ip -p udp -m udp --dport 67 -j ACCEPT", $action ) if ($cluster_enabled);
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $interface->tag('vip') -p tcp -m tcp --dport 67 -j ACCEPT", $action ) if $interface->tag("vip");
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $interface->tag('vip') -p udp -m udp --dport 67 -j ACCEPT", $action ) if $interface->tag("vip");
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $interface->tag('ip') -p tcp -m tcp --dport 67 -j ACCEPT", $action );
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $interface->tag('ip') -p udp -m udp --dport 67 -j ACCEPT", $action );
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d 255.255.255.255 -p tcp -m tcp --dport 67 -j ACCEPT", $action );
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d 255.255.255.255 -p udp -m udp --dport 67 -j ACCEPT", $action );
      }
    } elsif (is_type_inline($enforcement_type)) {
      if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
        $logger->info("Adding Proxy interception rules");
        foreach my $intercept_port ( split(',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
          util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $cluster_ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $cluster_ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $cluster_ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_REG   -j DROP", $action );
          util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_REG   -j DROP", $action );
          util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d 255.255.255.255 -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d 255.255.255.255 -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d 255.255.255.255 -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_REG   -j DROP", $action );
        }
      }
    }
  }
  util_reload_firewalld();
}

sub fd_pfipset_rules {
  my $action = shift;
  pfipset_provisioning_passthroughs();
  my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
  my $isolation_passthrough_enabled = isenabled($Config{'fencing'}{'isolation_passthrough'});
  foreach my $interface (@internal_nets) {
    my @all_dev_rules;
    my $tint = $interface->tag("int");
    my $ip = $interface->tag("vip") || $interface->tag("ip");
    my $enforcement_type = $Config{"interface $tint"}{'enforcement'};
    my $cluster_ip = $ConfigCluster{$CLUSTER}->{"interface $tint"}->{ip};

    if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
      if ($tint =~ m/(\w+):\d+/) {
        $tint = $1;
      }
      my ($type,$chain) = get_network_type_and_chain($ip);
      if ( $type eq $pf::config::NET_TYPE_VLAN_REG) {
        if ( $passthrough_enabled && ( $type eq $pf::config::NET_TYPE_VLAN_REG ) ) {
          util_direct_rule( "ipv4 filter FORWARD 0 --in-interface  $tint -m set --match-set pfsession_passthrough dst,dst --jump ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD 0 --out-interface $tint -m set --match-set pfsession_passthrough dst,dst --jump ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD 0 --in-interface  $tint -m set --match-set pfsession_passthrough src,src --jump ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD 0 --out-interface $tint -m set --match-set pfsession_passthrough src,src --jump ACCEPT", $action );
        }
        if ( $isolation_passthrough_enabled && ( $type eq $pf::config::NET_TYPE_VLAN_ISOL ) ) {
          util_direct_rule( "ipv4 filter FORWARD 0 --in-interface  $tint -m set --match-set pfsession_isol_passthrough dst,dst --jump ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD 0 --out-interface $tint -m set --match-set pfsession_isol_passthrough dst,dst --jump ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD 0 --in-interface  $tint -m set --match-set pfsession_isol_passthrough src,src --jump ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD 0 --out-interface $tint -m set --match-set pfsession_isol_passthrough src,src --jump ACCEPT", $action );
        }
      }
    }
  }
  util_reload_firewalld();
}

sub pfipset_provisioning_passthroughs {
  my $logger = get_logger();
  $logger->debug("Installing passthroughs for provisioning");
  foreach my $config (tied(%ConfigProvisioning)->search(type => 'kandji')) {
    $logger->info("Adding passthrough for Kandji");
    my $enroll_host = $config->{enroll_url} ? URI->new($config->{enroll_url})->host : $config->{host};
    my $enroll_port = $config->{enroll_url} ? URI->new($config->{enroll_url})->port : $config->{port};
    my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough ".$enroll_host.",".$enroll_port." 2>&1");
    pf_run($cmd);
  }

  foreach my $config (tied(%ConfigProvisioning)->search(type => 'mobileiron')) {
    $logger->info("Adding passthrough for MobileIron");
    # Allow the host for the onboarding of devices
    my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$config->{boarding_port} 2>&1");
    my @lines  = pf_run($cmd);
    # Allow http communication with the MobileIron server
    $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$HTTP_PORT 2>&1");
    pf_run($cmd);
    # Allow https communication with the MobileIron server
    $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$HTTPS_PORT 2>&1");
    pf_run($cmd);
  }

  foreach my $config (tied(%ConfigProvisioning)->search(type => 'opswat')) {
    $logger->info("Adding passthrough for OPSWAT");
    # Allow http communication with the OSPWAT server
    my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTP_PORT 2>&1");
    pf_run($cmd);
    # Allow https communication with the OPSWAT server
    $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTPS_PORT 2>&1");
    pf_run($cmd);
  }

  foreach my $config (tied(%ConfigProvisioning)->search(type => 'sentinelone')) {
    $logger->info("Adding passthrough for SentinelOne");
    # Allow http communication with the SentinelOne server
    my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTP_PORT 2>&1");
    pf_run($cmd);
    # Allow https communication with the SentinelOne server
    $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTPS_PORT 2>&1" );
    pf_run($cmd);
  }
  my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
  if ($passthrough_enabled) {
    $logger->info("Adding IP based passthrough for connectivitycheck.gstatic.com");
    # Allow the host for the onboarding of devices
    my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough 172.217.13.99,80 2>&1");
    pf_run($cmd);
    $cmd = untaint_chain("sudo ipset --add pfsession_passthrough 172.217.13.99,443 2>&1");
    pf_run($cmd);
  }
}

sub fd_netdata_rules {
  my $action = shift;
  my $tint =  $management_network->{Tint};
  util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp --match tcp -s 127.0.0.1 --dport 19999 -j ACCEPT", $action );
  if ($cluster_enabled) {
    push my @mgmt_backend, map { $_->{management_ip} } pf::cluster::config_enabled_servers();
    foreach my $mgmt_back (uniq(@mgmt_backend)) {
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp --match tcp -s $mgmt_back --dport 19999 -j ACCEPT", $action );
    }
  }
  util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp --match tcp --dport 19999 -j DROP", $action );
  util_reload_firewalld();
}

sub fd_pfconnector_server_rules {
  my $action = shift;
  # The dynamic range used to access the fingerbank collector that are connected via a remote connector
  my $tint =  $management_network->{Tint};
  my @pfconnector_ips = ("127.0.0.1");
  push @pfconnector_ips, (map { $_->{management_ip} } pf::cluster::config_enabled_servers()) if ($cluster_enabled);
  push @pfconnector_ips, $management_network->{Tip};
  @pfconnector_ips = uniq sort @pfconnector_ips;
  for my $ip (@pfconnector_ips) {
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp --match multiport -s $ip --dports 23001:23256 -j ACCEPT", $action );
  }
  util_reload_firewalld();
}

sub fd_galera_autofix_rules {
  my $action = shift;
  foreach my $network ( @ha_ints ) {
    my $tint =  $network->{Tint};
    service_to_zone($tint, $action, "galera-autofix");
  }
  foreach my $tint ( @dhcplistener_ints ) {
    service_to_zone($tint, $action, "galera-autofix");
  }
  util_reload_firewalld();
}

sub fd_mariadb_rules {
  my $action = shift;
  my $tint =  $management_network->{Tint};
  service_to_zone($tint, $action, "mysql");
  util_reload_firewalld();
}

sub fd_mysql_prob_rules {
  my $action = shift;
  my $tint =  $management_network->{Tint};
  service_to_zone($tint, $action, "mysql-prob");
  util_reload_firewalld();
}

sub fd_kafka_rules {
  my $action = shift;
  my $tint =  $management_network->{Tint};
  for my $client (@{$ConfigKafka{iptables}{clients}}) {
    util_direct_rule( "ipv4 filter INPUT 0 -i $tint --protocol tcp --match tcp -s $client --dport 9092 --jump ACCEPT" , $action );
  }
  for my $ip (@{$ConfigKafka{iptables}{cluster_ips}}) {
    util_direct_rule( "ipv4 filter INPUT 0 -i $tint --protocol tcp --match tcp -s $ip --dport 29092 --jump ACCEPT" , $action );
    util_direct_rule( "ipv4 filter INPUT 0 -i $tint --protocol tcp --match tcp -s $ip --dport 9092 --jump ACCEPT" , $action );
    util_direct_rule( "ipv4 filter INPUT 0 -i $tint --protocol tcp --match tcp -s $ip --dport 9093 --jump ACCEPT" , $action );
  }
  util_reload_firewalld();
}

sub fd_docker_dnat_rules {
  my $action = shift;
  #DNAT traffic from docker to mgmt ip
  my $logger = get_logger();
  my $mgmt_ip = (defined($management_network->tag('vip'))) ? $management_network->tag('vip') : $management_network->tag('ip');
  util_direct_rule("ipv4 nat PREROUTING 0 --protocol udp -s 100.64.0.0/10 -d $mgmt_ip --jump DNAT --to 100.64.0.1", $action );
  util_reload_firewalld();
}

sub fd_fingerbank_collector_rules {
  my $action = shift;
  if (netflow_enabled()) {
    util_direct_rule( "ipv4 filter FORWARD 0 -j NETFLOW" , $action );
  }
  util_reload_firewalld();
}

sub fd_radiusd_eduroam_rules {
  my $action = shift;
  my $logger = get_logger();
  # eduroam RADIUS virtual-server
  if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
    my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
    my $eduroam_listening_port = $eduroam_authentication_source[0]{'auth_listening_port'};    # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
    my $eduroam_listening_port_backend = $eduroam_listening_port + 10;
    my $mgnt_zone =  $management_network->{Tint};
    util_direct_rule( "ipv4 filter INPUT 0 -i $mgnt_zone -p tcp --match tcp --dport $eduroam_listening_port --jump ACCEPT", $action );
    util_direct_rule( "ipv4 filter INPUT 0 -i $mgnt_zone -p udp --match udp --dport $eduroam_listening_port --jump ACCEPT", $action );
    util_direct_rule( "ipv4 filter INPUT 0 -i $mgnt_zone -p tcp --match tcp --dport $eduroam_listening_port_backend --jump ACCEPT", $action ) if ($cluster_enabled);
    util_direct_rule( "ipv4 filter INPUT 0 -i $mgnt_zone -p udp --match udp --dport $eduroam_listening_port_backend --jump ACCEPT", $action ) if ($cluster_enabled);
    foreach my $network ( @radius_ints ) {
      my $tint =  $network->{Tint};
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp --match tcp --dport $eduroam_listening_port --jump ACCEPT", $action );
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp --match udp --dport $eduroam_listening_port --jump ACCEPT", $action );
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp --match tcp --dport $eduroam_listening_port_backend --jump ACCEPT", $action ) if ($cluster_enabled);
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp --match udp --dport $eduroam_listening_port_backend --jump ACCEPT", $action ) if ($cluster_enabled);
    }
    util_reload_firewalld();
  }
  else {
    get_logger->info( "# eduroam integration is not configured" );
  }
}

sub fd_firewalld_rules {
  my $action = shift;
  generate_chains("add");
  nat_back_inline_rules($action);
  #NAT Intercept Proxy
  interception_rules($action);
  # Note: I'm giving references to this guy here so he can directly mess with the tables
  inline_rules($action);
  # Mangle
  inline_if_src_rules("mangle",$action);
  mangle_rules($action);
  # NAT chain targets and redirections (other rules injected by generate_inline_rules)
  inline_if_src_rules("nat",$action);
  nat_redirect_rules($action);
  util_reload_firewalld();
}

sub generate_chains {
  my $action = shift;
  my @chains = qw (
    input-internal-inline-if
    forward-internal-inline-if
    prerouting-int-inline-if
    postrouting-int-inline-if
    postrouting-inline-routed
    prerouting-int-vlan-if
  );
  for my $chain (@chains) {
    generate_chain( "ipv4", "filter", $chain, $action );
  }
}

sub generate_chain {
  my $ipv   = shift;
  my $table = shift;
  my $chain = shift;
  my $action = shift;
  if ( ! defined $ipv || $ipv eq "" ){
    get_logger->error( "The generate_chain ipv is not defined or empty. default will be 'ipv4'." );
    $ipv = "ipv4";
  }
  if ( ! defined $table || $table eq "" ){
    get_logger->error( "The generate_chain table is not defined or empty. default will be 'filter'." );
    $table = "filter";
  }
  if ( ! defined $action || $action eq "" ){
    get_logger->error( "The generate_chain action is not defined or empty. default will be 'add'." );
    $action = "add";
  }
  util_chain( "ipv4", "filter", $chain, $action );
}

sub nat_back_inline_rules {
  my $action = shift;
  my $logger = get_logger();
  $logger->info("Nat back inline rules to forward is starting.");
  # Allow the NAT back inside through the forwarding table if inline is enabled
  if ( is_inline_enforcement_enabled() ) {
    my @values = split( ',' , get_inline_snat_interface() );
    foreach my $dev (@values) {
      foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
        my $nat = $ConfigNetworks{$network}{'nat_enabled'};
        if ( defined ( $nat ) && ( isdisabled($nat) ) ) {
          util_direct_rule("ipv4 filter FORWARD 0 -d $network/$inline_obj->{BITS} -i $dev -j ACCEPT", $action );
        }
      }
      util_direct_rule("ipv4 filter FORWARD 0 -i $dev -m state --state ESTABLISHED,RELATED -j ACCEPT", $action );
    }
    if($management_network) {
      my $mgmt_int = $management_network->tag("int");
      util_direct_rule("ipv4 filter FORWARD 0 -i $mgmt_int -m state --state ESTABLISHED,RELATED -j ACCEPT", $action );
    } else {
      $logger->info("NO Action taken on nat back inline rules to forwaard for management network.");
    }
  } else {
    $logger->info("NO Action taken on nat back inline rules to forward.");
  }
  $logger->info("Nat back inline rules to forward are done.");
}

sub interception_rules {
  my $action = shift;
  my $logger = get_logger();
  $logger->info("Interception rules are starting.");
  # internal interfaces handling
  foreach my $interface (@internal_nets) {
    my $dev = $interface->tag("int");
    my $enforcement_type = $Config{"interface $dev"}{'enforcement'};
    my $net_addr = NetAddr::IP->new($Config{"interface $dev"}{'ip'},$Config{"interface $dev"}{'mask'});
    # vlan enforcement
    if ($enforcement_type eq $IF_ENFORCEMENT_VLAN) {
      # send everything from vlan interfaces to the vlan chain
      util_direct_rule("ipv4 filter PREROUTING 0 --in-interface $dev --jump $FW_PREROUTING_INT_VLAN");
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
              util_direct_rule("ipv4 nat $FW_PREROUTING_INT_VLAN 0 $rule --jump DNAT --to $destination", $action );
            }
          }
          my $rule = "--protocol udp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
          util_direct_rule("ipv4 nat $FW_PREROUTING_INT_VLAN 0 $rule --jump DNAT --to $destination", $action );
          $rule = "--protocol tcp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
          util_direct_rule("ipv4 nat $FW_PREROUTING_INT_VLAN 0 $rule --jump DNAT --to $destination", $action );
        }
      }
    }
  }
  if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
    my $internal_portal_ip = $Config{captive_portal}{ip_address};
    foreach my $intercept_port ( split( ',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
      foreach my $interface (@internal_nets) {
        my $tint = $interface->tag("int");
        my $enforcement_type = $Config{"interface $tint"}{'enforcement'};
        if (is_type_inline($enforcement_type)) {
          my $rule = "--protocol tcp --destination-port $intercept_port";
          util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $internal_portal_ip $rule -j ACCEPT", $action );
        }
      }
    }
  }
  $logger->info("Interception rules are done.");
}

sub inline_rules {
  my $action = shift;
  my $logger = get_logger();
  $logger->info("Inline rules are starting.");
  if ( is_inline_enforcement_enabled() ) {
    $logger->info("The action $action has been set on DNS DNAT rules for unregistered and isolated inline clients.");
    foreach my $network ( keys %ConfigNetworks ) {
      # We skip non-inline networks/interfaces
      next if ( !pf::config::is_network_type_inline($network) );
      # Set the correct gateway if it is an inline Layer 3 network
      my $dev = $NetworkConfig{$network}{'interface'}{'int'};
      my $gateway = $Config{"interface $dev"}{'ip'};

      my $rule = "--protocol udp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
      util_direct_rule("ipv4 nat $FW_PREROUTING_INT_INLINE 0 $rule --match mark --mark 0x$IPTABLES_MARK_UNREG --jump DNAT --to $gateway", $action );
      util_direct_rule("ipv4 nat $FW_PREROUTING_INT_INLINE 0 $rule --match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump DNAT --to $gateway", $action );

      if (isenabled($ConfigNetworks{$network}{'split_network'}) && defined($ConfigNetworks{$network}{'reg_network'}) && $ConfigNetworks{$network}{'reg_network'} ne '') {
        $rule = "--protocol udp --destination-port 53 -s $ConfigNetworks{$network}{'reg_network'}";
        util_direct_rule("ipv4 nat $FW_PREROUTING_INT_INLINE 0 $rule --match mark --mark 0x$IPTABLES_MARK_UNREG --jump DNAT --to $gateway", $action );
        util_direct_rule("ipv4 nat $FW_PREROUTING_INT_INLINE 0 $rule --match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump DNAT --to $gateway", $action );
      }

      if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
        $logger->info("Adding Proxy interception rules");
        foreach my $intercept_port ( split(',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
          my $rule = "--protocol tcp --destination-port $intercept_port -s $network/$ConfigNetworks{$network}{'netmask'}";
          util_direct_rule("ipv4 nat $FW_PREROUTING_INT_INLINE 0 $rule --match mark --mark 0x$IPTABLES_MARK_UNREG --jump DNAT --to $gateway", $action );
          util_direct_rule("ipv4 nat $FW_PREROUTING_INT_INLINE 0 $rule --match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump DNAT --to $gateway", $action );
        }
      }
    }

    if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
      $logger->info("Adding Proxy interception rules");
      foreach my $intercept_port ( split(',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
        util_direct_rule("ipv4 filter $FW_FILTER_INPUT_INT_INLINE 0 --protocol tcp --match tcp --dport $intercept_port --match mark --mark 0x$IPTABLES_MARK_UNREG  --jump ACCEPT", $action );
        util_direct_rule("ipv4 filter $FW_FILTER_INPUT_INT_INLINE 0 --protocol tcp --match tcp --dport $intercept_port --match mark --mark 0x$IPTABLES_MARK_UNREG  --jump ACCEPT", $action );
        util_direct_rule("ipv4 filter $FW_FILTER_INPUT_INT_INLINE 0 --protocol tcp --match tcp --dport $intercept_port --match mark --mark 0x$IPTABLES_MARK_REG  --jump DROP", $action );
      }
    }

    $logger->info("Adding NAT Masquarade statement (PAT)");
    util_direct_rule("ipv4 filter $FW_POSTROUTING_INT_INLINE 0 --jump MASQUERADE", $action );

    $logger->info("Addind ROUTED statement");
    util_direct_rule("ipv4 filter $FW_POSTROUTING_INT_INLINE_ROUTED 0 --jump ACCEPT", $action );

    $logger->info("building firewall to accept registered users through inline interface");
    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));

    if ($passthrough_enabled) {
      util_direct_rule("ipv4 filter $FW_FILTER_FORWARD_INT_INLINE 0 --match mark --mark 0x$IPTABLES_MARK_UNREG -m set --match-set pfsession_passthrough dst,dst --jump ACCEPT", $action );
      util_direct_rule("ipv4 filter $FW_FILTER_FORWARD_INT_INLINE 0 --match mark --mark 0x$IPTABLES_MARK_ISOLATION -m set --match-set pfsession_isol_passthrough dst,dst --jump ACCEPT", $action );
    }
    util_direct_rule("ipv4 filter $FW_FILTER_FORWARD_INT_INLINE 0 --match mark --mark 0x$IPTABLES_MARK_REG --jump ACCEPT", $action );
  } else {
    $logger->info("NO Action taken on DNS DNAT rules for unregistered and isolated inline clients.");
  }
  $logger->info("Inline rules are done.");
}

sub inline_if_src_rules {
  my $table = shift;
  my $action = shift;
  my $logger = get_logger();
  $logger->info("Inline if src rules are starting for $table.");
  if ( is_inline_enforcement_enabled() ) {
    $logger->info("The action $action has been set on inline clients for table $table.");
    # internal interfaces handling
    foreach my $interface (@internal_nets) {
      my $dev = $interface->tag("int");
      my $enforcement_type = $Config{"interface $dev"}{'enforcement'};

      # inline enforcement
      if (is_type_inline($enforcement_type)) {
        # send everything from inline interfaces to the inline chain
        util_direct_rule("ipv4 filter PREROUTING 0 --in-interface $dev --jump $FW_PREROUTING_INT_INLINE", $action );
        util_direct_rule("ipv4 filter POSTROUTING 0 --out-interface $dev --jump $FW_POSTROUTING_INT_INLINE", $action );
      }
    }

    # POSTROUTING
    if ( $table ne "nat" ) {
      my @values = split(',', get_inline_snat_interface());
      foreach my $val (@values) {
        util_direct_rule("ipv4 filter POSTROUTING 0 --out-interface $val --jump $FW_POSTROUTING_INT_INLINE", $action );
      }
    }

    # NAT POSTROUTING
    if ($table eq "nat" ) {
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
              util_direct_rule("ipv4 filter POSTROUTING 0 -s $network/$inline_obj->{BITS} --out-interface $val --match mark --mark 0x$_ --jump $FW_POSTROUTING_INT_INLINE_ROUTED", $action );
            }
          }
          util_direct_rule("ipv4 filter POSTROUTING 0 --out-interface $val --match mark --mark 0x$_ --jump $FW_POSTROUTING_INT_INLINE", $action );
        }
      }
    }
  } else {
    $logger->info("NO Action taken on inline clients for table $table.");
  }
  $logger->info("Inline if src rules are done for $table.");
}

sub mangle_rules {
  my $action = shift;
  my $logger = get_logger();
  $logger->info("Mangle rules are starting.");
  if ( is_inline_enforcement_enabled() ) {
    $logger->info("The action $action has been set on mangle rules.");
    my $mangle_rules = '';
    my @ops = ();

    # pfdhcplistener in most cases will be enforcing access
    # however we insert these marks on startup in case PacketFence is restarted

    # default catch all: mark unreg
    util_direct_rule("ipv4 filter $FW_PREROUTING_INT_INLINE 0 -j MARK --set-mark 0x$IPTABLES_MARK_UNREG", $action );
    foreach my $network ( keys %ConfigNetworks ) {
      next if ( !pf::config::is_network_type_inline($network) );
      foreach my $IPTABLES_MARK ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
        my $rule = "";
        if ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE_L3$/i) {
          $rule = "$FW_PREROUTING_INT_INLINE 0 -m set --match-set pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network src ";
        } else {
          $rule .= "$FW_PREROUTING_INT_INLINE 0 -m set --match-set pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network src,src ";
        }
        $rule .= "-j MARK --set-mark 0x$IPTABLES_MARK";
        util_direct_rule("ipv4 filter $rule", $action );
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
  } else {
    $logger->info("NO Action taken on mangle rules.");
  }
  $logger->info("Mangle rules are done.");
}

sub nat_redirect_rules {
  my $action = shift;
  my $logger = get_logger();
  $logger->info("Nat redirect rules are starting.");
  if ( is_inline_enforcement_enabled() ) {
    $logger->info("The action $action has been set on nat redirect rules.");
    my $rule = '';

    # Exclude the OAuth from the DNAT
    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));

    if ($passthrough_enabled) {
      $rule = "$FW_PREROUTING_INT_INLINE 0 -m set --match-set pfsession_passthrough dst,dst --match mark --mark 0x$IPTABLES_MARK_UNREG --jump ACCEPT";
      util_direct_rule("ipv4 filter $rule", $action );
      $rule = "$FW_PREROUTING_INT_INLINE 0 -m set --match-set pfsession_isol_passthrough dst,dst --match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump ACCEPT";
      util_direct_rule("ipv4 filter $rule", $action );
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
        " $FW_PREROUTING_INT_INLINE 0 --protocol $protocol --destination-port $port -s $network/$ConfigNetworks{$network}{'netmask'} " .
        "--match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump DNAT --to $gateway";
        util_direct_rule("ipv4 nat $rule", $action );
      }
    }
  } else {
    $logger->info("NO Action taken nat redirect rules.");
  }
  $logger->info("Nat redirect rules are done.");
}

# need a function that return information like a wrapper of firewalld-cmd
# need a function that return services from a zone
# need a function that check integrity for zones and services

# need a function that add/remove a service into/from a zone
sub service_to_zone {
  my $zone = shift;
  my $action = shift;
  my $service = shift;

  if ( defined is_service_available($service) && defined is_zone_available( $zone ) ) {
    util_firewalld_job( " --zone=$zone --$action-service=$service --permanent" );
  } else {
    get_logger->error( "Please run generate config to create services and zones" );
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
