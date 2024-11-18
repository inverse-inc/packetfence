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
use File::Slurp qw(read_file);
use List::MoreUtils qw(uniq);
use URI ();
use Readonly;
use NetAddr::IP;
use IO::Interface::Simple;
use Switch;

BEGIN {
  use Exporter ();
  our ( @ISA, @EXPORT );
  @ISA = qw(Exporter);
  @EXPORT = qw(
    fd_configreload
    fd_clean_pfconf_configs
    fd_generate_dynamic_configs
    fd_generate_pfconf_configs
    fd_create_all_zones
    fd_services_rules
    fd_keepalived_rules
    fd_radiusd_lb_rules
    fd_proxysql_rules
    fd_haproxy_admin_rules
    fd_httpd_webservices_rules
    fd_httpd_aaa_rules
    fd_httpd_dispatcher_rules
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
    @vlan_enforcement_nets
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
    $firewalld_input_config_inc_file
    $firewalld_input_management_config_inc_file
    $firewalld6_input_config_inc_file
    $firewalld6_input_management_config_inc_file
);
use pf::log;
use pf::constants;
use pf::config::cluster;
use pf::ipset;
use pf::util;
use pf::security_event qw(security_event_view_open_uniq security_event_count);
use pf::authentication;
use pf::cluster;
use pf::ConfigStore::Provisioning;
use pf::ConfigStore::Domain;
use pf::node qw(nodes_registered_not_violators node_view node_deregister $STATUS_REGISTERED);

use pf::Firewalld::util;
use pf::Firewalld::config qw ( generate_firewalld_file_config );
use pf::Firewalld::lockdown_whitelist qw ( generate_lockdown_whitelist_config );
use pf::Firewalld::helpers qw ( generate_helpers_config );
use pf::Firewalld::icmptypes qw ( generate_icmptypes_config );
use pf::Firewalld::ipsets qw ( generate_ipsets_config );
use pf::Firewalld::services qw ( generate_services_config );
use pf::Firewalld::zones qw ( generate_zones_config );
use pf::Firewalld::policies qw ( generate_policies_config );

tie our %NetworkConfig, 'pfconfig::cached_hash', "resource::network_config($host_id)";
tie our %ConfigKafka, 'pfconfig::cached_hash', "config::Kafka";

=item fd_configreload

Reload the config

=cut

sub fd_configreload {
  my ($force) = @_;
  my $logger = get_logger();
  $logger->info( "Start config reload" );
  if ($force eq 1) {
    fd_clean_pfconf_configs();
    fd_generate_pfconf_configs();
  }
  fd_generate_dynamic_configs();
}

=item fd_clean_pfconf_configs

Remove firewalld configuration from /usr/local/pf/var/conf/firewalld/

=cut

sub fd_clean_pfconf_configs {
  my $logger = get_logger();
  $logger->info( "Remove config from /usr/local/pf/var/conf/firewalld/" );
  rmtree $firewalld_config_path_generated;
  fd_clean_all_previous_rules();
}

=item fd_generate_dynamic_configs

Generate dynamically firewalld all configurations, ipset and add rules according services

=cut

sub fd_generate_dynamic_configs {
  my $logger = get_logger();
  if (ref($management_network) && exists $management_network->{Tint} ) {
    $logger->info( "Start generate dynamic config" );
    fd_add_default_direct_rules();
    fd_create_all_zones();
    pf::ipset->new()->iptables_generate();
    fd_services_rules("add");
    fd_add_extra_direct_rules();
    fd_fix_dir_permissions();
  } else {
    $logger->info( "No management defined" );
  }
}

=item fd_generate_pfconf_configs

Generate firewalld configuration from config files under /usr/local/pf/conf/firewalld/
Then a complete firewalld config is set under /usr/local/pf/var/conf/firewalld/

=cut

sub fd_generate_pfconf_configs {
  my $logger = get_logger();
  if (ref($management_network) && exists $management_network->{Tint} ) {
    $logger->info( "Start generate config" );
    generate_firewalld_file_config();
    generate_lockdown_whitelist_config();
    generate_helpers_config();
    generate_icmptypes_config();
    generate_ipsets_config();
    generate_services_config();
    generate_zones_config();
    generate_policies_config();
    fd_fix_dir_permissions();
  } else {
    $logger->info( "No management defined" );
  }
}

=item fd_clean_all_previous_rules

Iptables clean all previous rules from service/manager/firewalld reload or docker minimal rules.

=cut

sub fd_clean_all_previous_rules {
  my $logger = get_logger();
  $logger->info( "Remove all previous rules" );
  pf_run("sudo iptables -F");
  pf_run("sudo iptables -X");
  pf_run("sudo iptables -t nat -F");
  pf_run("sudo iptables -t nat -X");
  pf_run("sudo iptables -t mangle -F");
  pf_run("sudo iptables -t mangle -X");
}

=item fd_add_default_rules

Firewalld Add default rules set in service/manager/firewalld reload or docker minimal rules in direct rules to be able to order them

=cut

sub fd_add_default_direct_rules {
  my $logger = get_logger();
  $logger->info( "Add direct rules." );
  util_direct_rule("ipv4 filter INPUT -1003 -i lo -j ACCEPT", "add" );
  util_direct_rule("ipv4 filter INPUT -1002 -i docker0 -j ACCEPT", "add" );
  util_direct_rule("ipv4 filter INPUT -1001 -m state --state ESTABLISHED,RELATED -j ACCEPT", "add" );
  util_direct_rule("ipv4 filter INPUT -1000 -p icmp --icmp-type echo-request -j ACCEPT", "add" );
}

=item fd_create_all_zones

Firewalld set a zone for each interfaces listened by PF
Then an interface = a firewalld zone

=cut

sub fd_create_all_zones {
  my $name_files = util_get_name_files_from_dir("zones");
  my $logger = get_logger();
  $logger->info( "Create all zones." );
  foreach my $tint ( @listen_ints ) {
    if ( defined $name_files && exists $name_files->{$tint} ) {
      $logger->error( "Network Interface $tint  is handle by configuration files" );
    } else {
      util_firewalld_job( " --permanent --delete-zone=$tint" );
      util_firewalld_job( " --permanent --new-zone=$tint" );
      util_firewalld_job( " --permanent --zone=$tint --set-target=DROP");
      util_firewalld_job( " --permanent --zone=$tint --change-interface=$tint");
      util_reload_firewalld();
    }
    util_zone_set_forward( $tint , "remove" );
    util_zone_set_masquerade( $tint , "add" );
    util_direct_rule("ipv4 filter INPUT -1000 -i $tint -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT", "add" );
  }
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      util_set_default_zone( $tint );
      util_direct_rule("ipv4 filter INPUT -1000 -i $tint -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT", "add" );
      my $web_admin_port = $Config{'ports'}{'admin'};
      util_direct_rule("ipv4 filter INPUT -1000 -i $tint -p tcp -m tcp --dport $web_admin_port -j ACCEPT", "add" );
      util_zone_set_forward( $tint , "add" );
      util_zone_set_masquerade( $tint, "add" );
    }
  }
}

=item fd_add_extra_direct_rules

Firewalld apply rules according to extra rules defined in firewalld*.inc files

=cut

sub fd_add_extra_direct_rules {
  my $logger = get_logger();
  $logger->info( "Extra rules starts" );
  my @fd_custom_files = (
    $firewalld_input_config_inc_file,
    $firewalld_input_management_config_inc_file,
    $firewalld6_input_config_inc_file,
    $firewalld6_input_management_config_inc_file
  );
  foreach my $file ( @fd_custom_files ) {
    my $lines = get_lines_from_file_in_array($file);
    foreach my $line ( @{ $lines } ) {
      if ( $line =~ m/^#/ ) {
        $logger->warn( "Firewalld extra line $line will not be used" );
      } else {
        util_direct_rule( $line, "add" );
      }
    }
  }
  $logger->info( "Firewalld extra rules ends" );
}

=item fd_services_rules

Firewalld apply rules according to running services
need to get services that are running and use the dedicated function to restart accordingly

=cut

sub fd_services_rules {
  my $logger = get_logger();
  my $action = shift;
  my $services = [qw(
      docker.service
      packetfence-api-frontend.service
      packetfence-fingerbank-collector.service
      packetfence-galera-autofix.service
      packetfence-haproxy-admin.service
      packetfence-haproxy-db.service
      packetfence-haproxy-portal.service
      packetfence-httpd.aaa.service
      packetfence-httpd.dispatcher.service
      packetfence-httpd.portal.service
      packetfence-httpd.webservices.service
      packetfence-kafka.service
      packetfence-keepalived.service
      packetfence-mariadb.service
      packetfence-mysql-probe.service
      packetfence-netdata.service
      packetfence-pfacct.service
      packetfence-pfconnector-server.service
      packetfence-pfdhcp.service
      packetfence-pfdns.service
      packetfence-pfipset.service
      packetfence-proxysql.service
      packetfence-radiusd-acct.service
      packetfence-radiusd-auth.service
      packetfence-radiusd-cli.service
      packetfence-radiusd-eduroam.service
      packetfence-radiusd-load_balancer.service
      packetfence-snmptrapd.service
    )];
  my $states = util_getServiveState($services,[qw(Id ActiveState)]);
  foreach my $state ( @{ $states } ) {
    if ( $state->{"ActiveState"} eq "active" ) {
      $logger->info("$state->{'Id'} is active");
      switch( $state->{'Id'} ) {
        case "docker.service"    { fd_docker_dnat_rules($action);}
        case "packetfence-api-frontend.service"     { fd_api_frontend_rules($action); }
        case "packetfence-fingerbank-collector.service" { fd_fingerbank_collector_rules($action);}
        case "packetfence-galera-autofix.service" { fd_galera_autofix_rules($action);}
        case "packetfence-haproxy-admin.service"    { fd_haproxy_admin_rules($action); }
        case "packetfence-haproxy-db.service" {fd_haproxy_db_rules($action);}
        case "packetfence-haproxy-portal.service"   { fd_haproxy_portal_rules($action); }
        case "packetfence-httpd.aaa.service"        { fd_httpd_aaa_rules($action);}
        case "packetfence-httpd.dispatcher.service"        { fd_httpd_dispatcher_rules($action);}
        case "packetfence-httpd.portal.service"     { fd_httpd_portal_rules($action);}
        case "packetfence-httpd.webservices.service" { fd_httpd_webservices_rules($action);}
        case "packetfence-kafka.service"       { fd_kafka_rules($action);}
        case "packetfence-keepalived.service"       { fd_keepalived_rules($action); }
        case "packetfence-mariadb.service"     { fd_mariadb_rules($action);}
        case "packetfence-mysql-probe.service" { fd_mysql_prob_rules($action);}
        case "packetfence-netdata.service" { fd_netdata_rules($action);}
        case "packetfence-pfacct.service"       { fd_pfacct_rules($action);}
        case "packetfence-pfconnector-server.service" { fd_pfconnector_server_rules($action);}
        case "packetfence-pfdhcp.service"  { fd_pfdhcp_rules($action);}
        case "packetfence-pfdns.service"   { fd_pfdns_rules($action);}
        case "packetfence-pfipset.service" { fd_pfipset_rules($action);}
        case "packetfence-proxysql.service"     { fd_proxysql_rules($action); }
        case "packetfence-radiusd-acct.service" { fd_radiusd_acct_rules($action);}
        case "packetfence-radiusd-auth.service" { fd_radiusd_auth_rules($action);}
        case "packetfence-radiusd-cli.service"  { fd_radiusd_cli_rules($action);}
        case "packetfence-radiusd-eduroam.service" { fd_radiusd_eduroam_rules($action);}
        case "packetfence-radiusd-load_balancer.service" { fd_radiusd_lb_rules($action); }
        case "packetfence-snmptrapd.service"    { fd_snmptrapd_rules($action);}
        else { $logger->info( "The service $state->{'Id'} is not using Firewalld for its configuration" ) }
      }
    }
  }
}

=item fd_keepalived_rules

Firewalld rules for keepalived service

=cut

sub fd_keepalived_rules {
  my $action = shift;
  foreach my $tint ( @listen_ints ){
    # Never remove, used several time
    util_direct_rule("ipv4 filter INPUT -500 -i $tint -d 224.0.0.0/8 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT -500 -i $tint -p vrrp -j ACCEPT", $action ) if ($cluster_enabled);
  }
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      util_direct_rule("ipv4 filter INPUT -500 -i $tint -d 224.0.0.0/8 -j ACCEPT", $action );
      util_direct_rule("ipv4 filter INPUT -500 -i $tint -p vrrp -j ACCEPT", $action ) if ($cluster_enabled);
    }
  }
}

=item fd_radiusd_lb_rules

Firewalld rules for radius lb service

=cut

sub fd_radiusd_lb_rules {
  my $action = shift;
  foreach my $network ( @radius_ints ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 1814 -j ACCEPT", $action );
  }
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 1814 -j ACCEPT", $action );
    }
  }
}

=item fd_proxysql_rules

Firewalld rules for proxysql service

=cut

sub fd_proxysql_rules {
  # Proxysql
  my $action = shift;
  my $logger = get_logger();
  if ( util_reload_firewalld() ) {
    my $tint = $management_network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 6033 -j ACCEPT", $action );
  } else {
    $logger->warn("Firewalld is not started yet");
  }
}

=item fd_haproxy_admin_rules

Firewalld rules for haproxy admin service

=cut

sub fd_haproxy_admin_rules {
  # Web Admin
  my $action = shift;
  my $logger = get_logger();
  if ( util_reload_firewalld() ) {
    if (ref($management_network) && exists $management_network->{Tint} ) {
      my $tint = $management_network->{Tint};
      if ( $tint ne "" ) {
        my $web_admin_port = $Config{'ports'}{'admin'};
        util_direct_rule("ipv4 filter INPUT -1000 -i $tint -p tcp -m tcp --dport $web_admin_port -j ACCEPT", $action );
      }
    }
  } else {
    $logger->warn("Firewalld is not started yet");
  }
}

=item fd_httpd_webservices_rules

Firewalld rules for httpd webservices service

=cut

sub fd_httpd_webservices_rules {
  # Webservices
  my $action = shift;
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      my $webservices_port = $Config{'ports'}{'soap'};
      util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport $webservices_port -j ACCEPT", $action );
    }
  }
}

=item fd_snmptrapd_rules

Firewalld rules for snmptrapd service

=cut

sub fd_snmptrapd_rules {
  my $action = shift;
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 162 -j ACCEPT", $action );
    }
  }
}

=item fd_httpd_aaa_rules

Firewalld rules for httpd aaa service

=cut

sub fd_httpd_aaa_rules {
  # AAA
  my $action = shift;
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      my $aaa_port = $Config{'ports'}{'aaa'};
      util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport $aaa_port -j ACCEPT", $action );
    }
  }
}

=item fd_httpd_dispatcher_rules

Firewalld rules for httpd dispatcher service
HTTP (parking portal)

=cut

sub fd_httpd_dispatcher_rules {
  #  HTTP (parking portal)
  my $action = shift;
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 5252 -j ACCEPT", $action );
    }
  }
  foreach my $network ( @vlan_enforcement_nets ) {
    my $tint =  $network->{Tint};
    util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 5252 -j ACCEPT", $action );
  }
}

=item fd_api_frontend_rules

Firewalld rules for api frontend service

=cut

sub fd_api_frontend_rules {
  # Unified API
  my $action = shift;
  my $logger = get_logger();
  if ( util_reload_firewalld() ) {
    my $tint = $management_network->{Tint};
    my $unifiedapi_port = $Config{'ports'}{'unifiedapi'};
    util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport $unifiedapi_port -j ACCEPT", $action );
  } else {
    $logger->warn("Firewalld is not started yet");
  }
}

=item fd_httpd_portal_rules

Firewalld rules for httpd portal service

=cut

sub fd_httpd_portal_rules {
  # httpd.portal modstatus
  my $action = shift;
  my $mgnt_zone = $management_network->{Tint};
  my $httpd_portal_modstatus = $Config{'ports'}{'httpd_portal_modstatus'};
  util_direct_rule( "ipv4 filter INPUT 0 -i $mgnt_zone -p tcp -m tcp --dport $httpd_portal_modstatus -j ACCEPT", $action );
  foreach my $network ( @portal_ints ) {
    my $tint =  $network->{Tint};
    util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 8080 -j ACCEPT", $action );
  }
}

=item fd_haproxy_db_rules

Firewalld rules for haproxy db service

=cut

sub fd_haproxy_db_rules {
  my $action = shift;
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 1025 -j ACCEPT", $action );
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 3306 -j ACCEPT", $action );
    }
  }
}

=item fd_haproxy_portal_rules

Firewalld rules for haproxy portal service

=cut

sub fd_haproxy_portal_rules {
  my $action = shift;
  foreach my $tint (@ha_ints){
    my $web_admin_port = $Config{'ports'}{'admin'};
    util_direct_rule("ipv4 filter INPUT -1000 -i $tint -p tcp -m tcp --dport $web_admin_port -j ACCEPT", $action );
  }
  foreach my $network ( @portal_ints ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 80 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 443 -j ACCEPT", $action );
  }
  foreach my $network ( @inline_enforcement_nets ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 80 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 443 -j ACCEPT", $action );
  }
  foreach my $network ( @vlan_enforcement_nets ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 80 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 443 -j ACCEPT", $action );
  }
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 80 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 443 -j ACCEPT", $action );
    }
  }
}

=item fd_radiusd_acct_rules

Firewalld rules for radiusd acct service

=cut

sub fd_radiusd_acct_rules {
  my $action = shift;
  foreach my $network ( @radius_ints ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 1813 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 1823 -j ACCEPT", $action ) if ($cluster_enabled);
  }
}

=item fd_pfacct_rules

Firewalld rules for pfacct service

=cut

sub fd_pfacct_rules {
  my $action = shift;
  foreach my $network ( @radius_ints ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 1813 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 1823 -j ACCEPT", $action ) if ($cluster_enabled);
  }
}

=item fd_radiusd_auth_rules

Firewalld rules for radiusd auth service

=cut

sub fd_radiusd_auth_rules {
  my $action = shift;
  foreach my $network ( @radius_ints ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 1812 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 2083 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 2093 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 1822 -j ACCEPT", $action ) if ($cluster_enabled);
  }
}

=item fd_radiusd_cli_rules

Firewalld rules for radiusd cli service

=cut

sub fd_radiusd_cli_rules {
  my $action = shift;
  foreach my $network ( @radius_ints ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 1815 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 1825 -j ACCEPT", $action ) if ($cluster_enabled);
  }
}

=item fd_pfdns_rules

Firewalld rules for pfdns service

=cut

sub fd_pfdns_rules {
  my $action = shift;
  foreach my $tint ( @dns_ints ) {
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 53 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 53 -j ACCEPT", $action );
  }
  foreach my $network ( @inline_enforcement_nets ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 53 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 53 -j ACCEPT", $action );
  }
  foreach my $network ( @vlan_enforcement_nets ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 53 -j ACCEPT", $action );
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 53 -j ACCEPT", $action );
  }
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 53 -j ACCEPT", $action );
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 53 -j ACCEPT", $action );
    }
  }
  # OAuth
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
  #NAT Intercept Proxy
  dns_interception_rules($action);
  dns_oauth_passthrough_rules($action);
  util_reload_firewalld();
}

sub dns_interception_rules {
  my $action = shift;
  my $logger = get_logger();

  $logger->info("Interception rules are starting.");
  # internal interfaces handling
  foreach my $interface (@internal_nets) {
    my $tint = $interface->tag("int");
    my $enforcement_type = $Config{"interface $tint"}{'enforcement'};
    my $net_addr = NetAddr::IP->new($Config{"interface $tint"}{'ip'},$Config{"interface $tint"}{'mask'});
    $logger->info($enforcement_type);
    # vlan enforcement
    if ($enforcement_type eq $IF_ENFORCEMENT_VLAN) {
      # send everything from vlan interfaces to the vlan chain
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
          my $destination = $Config{"interface $tint"}{'vip'} || $Config{"interface $tint"}{'ip'};
          if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
            foreach my $intercept_port ( split( ',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
              my $rule = "-p tcp --destination-port $intercept_port -s $network/$ConfigNetworks{$network}{'netmask'}";
              util_direct_rule("ipv4 nat PREROUTING -50 -i $tint $rule -j DNAT --to $destination", $action );
            }
          }
          my $rule = "-p udp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
          util_direct_rule("ipv4 nat PREROUTING -50 -i $tint $rule -j DNAT --to $destination", $action );
          $rule = "-p tcp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
          util_direct_rule("ipv4 nat PREROUTING -50 -i $tint $rule -j DNAT --to $destination", $action );
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
          my $rule = "-p tcp --destination-port $intercept_port";
          util_direct_rule( "ipv4 filter INPUT 0 -i $tint -d $internal_portal_ip $rule -j ACCEPT", $action );
        }
      }
    }
  }
  $logger->info("Interception rules are done.");
}

sub dns_oauth_passthrough_rules {
  my $action = shift;
  my $logger = get_logger();
  # OAuth
  my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
  my $isolation_passthrough_enabled = isenabled($Config{'fencing'}{'isolation_passthrough'});
  my ($SNAT_ip, $mgmt_int);
  if ($passthrough_enabled) {
    $logger->info("Adding Forward rules to allow connections to the OAuth2 Providers and passthrough.");
    foreach my $interface (@internal_nets) {
      my $tint = $interface->tag("int");
      my $ip = $interface->tag("vip") || $interface->tag("ip");
      my $enforcement_type = $Config{"interface $tint"}{'enforcement'};
      # VLAN enforcement
      if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
        if ($tint =~ m/(\w+):\d+/) {
            $tint = $1;
        }
        my ($type,$chain) = get_network_type_and_chain($ip);
        if ($passthrough_enabled && ($type eq $pf::config::NET_TYPE_VLAN_REG)) {
          util_direct_rule("ipv4 filter FORWARD -10 -i $tint -m set --match-set pfsession_passthrough dst,dst -j ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD -10 -i $tint -m set --match-set pfsession_passthrough src,src -j ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD -9 -o $tint -m set --match-set pfsession_passthrough dst,dst -j ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD -9 -o $tint -m set --match-set pfsession_passthrough src,src -j ACCEPT", $action );
        }
        if ($isolation_passthrough_enabled && ($type eq $pf::config::NET_TYPE_VLAN_ISOL)) {
          util_direct_rule("ipv4 filter FORWARD -8 -i $tint -m set --match-set pfsession_isol_passthrough dst,dst -j ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD -8 -i $tint -m set --match-set pfsession_isol_passthrough src,src -j ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD -7 -o $tint -m set --match-set pfsession_isol_passthrough dst,dst -j ACCEPT", $action );
          util_direct_rule("ipv4 filter FORWARD -7 -o $tint -m set --match-set pfsession_isol_passthrough src,src -j ACCEPT", $action );
        }
      }
    }
    $mgmt_int = $management_network->tag("int");
    if (defined($management_network->{'Tip'}) && $management_network->{'Tip'} ne '') {
      if (defined($management_network->{'Tvip'}) && $management_network->{'Tvip'} ne '') {
        $SNAT_ip = $management_network->{'Tvip'};
      } else {
        $SNAT_ip = $management_network->{'Tip'};
      }
    }
    if ($SNAT_ip) {
      foreach my $network ( keys %ConfigNetworks ) {
        my $network_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
        if ( pf::config::is_network_type_inline($network) ) {
          my $nat = $ConfigNetworks{$network}{'nat_enabled'};
          if (defined ($nat) && (isenabled($nat))) {
            util_direct_rule("ipv4 nat POSTROUTING 0 -s $network/$network_obj->{BITS} -o $mgmt_int -j SNAT --to $SNAT_ip", $action );
          }
        } else {
          util_direct_rule("ipv4 nat POSTROUTING 0 -s $network/$network_obj->{BITS} -o $mgmt_int -j SNAT --to $SNAT_ip", $action );
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
            util_direct_rule("ipv4 nat POSTROUTING 0 -s $network/$network_obj->{BITS} -o $int -j SNAT --to ".$if->address, $action );
          }
        } else {
          util_direct_rule("ipv4 nat POSTROUTING 0 -s $network/$network_obj->{BITS} -o $int -j SNAT --to ".$if->address, $action );
        }
      }
    }
  }
}

sub get_network_snat_interface {
  my ($self) = @_;
  my $logger = get_logger();
  if (defined ($Config{'network'}{'interfaceSNAT'}) && $Config{'network'}{'interfaceSNAT'} ne '') {
    return $Config{'network'}{'interfaceSNAT'};
  }
}

=item fd_pfdhcp_rules

Firewalld rules for pfdhcp service

=cut

sub fd_pfdhcp_rules {
  my $action = shift;
  my $logger = get_logger();
  foreach my $tint ( @dhcp_ints ) {
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 67 -j ACCEPT", $action );
  }
  foreach my $tint ( @dhcplistener_ints ) {
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 67 -j ACCEPT", $action );
  }
  foreach my $network ( @inline_enforcement_nets ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 67 -j ACCEPT", $action );
  }
  foreach my $network ( @vlan_enforcement_nets ) {
    my $tint =  $network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 67 -j ACCEPT", $action );
  }
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 67 -j ACCEPT", $action );
    }
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
        util_direct_rule( "ipv4 filter INPUT -30 -i $tint -d $internal_portal_ip -p tcp -m tcp --dport 67 -j ACCEPT", $action );
        util_direct_rule( "ipv4 filter INPUT -29 -i $tint -d $internal_portal_ip -p udp -m udp --dport 67 -j ACCEPT", $action );
        util_direct_rule( "ipv4 filter INPUT -30 -i $tint -d $cluster_ip -p tcp -m tcp --dport 67 -j ACCEPT", $action ) if ($cluster_enabled);
        util_direct_rule( "ipv4 filter INPUT -29 -i $tint -d $cluster_ip -p udp -m udp --dport 67 -j ACCEPT", $action ) if ($cluster_enabled);
        util_direct_rule( "ipv4 filter INPUT -28 -i $tint -d $interface->tag('vip') -p tcp -m tcp --dport 67 -j ACCEPT", $action ) if $interface->tag("vip");
        util_direct_rule( "ipv4 filter INPUT -27 -i $tint -d $interface->tag('vip') -p udp -m udp --dport 67 -j ACCEPT", $action ) if $interface->tag("vip");
        util_direct_rule( "ipv4 filter INPUT -26 -i $tint -d $interface->tag('ip') -p tcp -m tcp --dport 67 -j ACCEPT", $action );
        util_direct_rule( "ipv4 filter INPUT -25 -i $tint -d $interface->tag('ip') -p udp -m udp --dport 67 -j ACCEPT", $action );
        util_direct_rule( "ipv4 filter INPUT -24 -i $tint -d 255.255.255.255 -p tcp -m tcp --dport 67 -j ACCEPT", $action );
        util_direct_rule( "ipv4 filter INPUT -23 -i $tint -d 255.255.255.255 -p udp -m udp --dport 67 -j ACCEPT", $action );
      }
    } elsif (is_type_inline($enforcement_type)) {
      if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
        $logger->info("Adding Proxy interception rules");
        foreach my $intercept_port ( split(',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
          util_direct_rule( "ipv4 filter INPUT -22 -i $tint -d $cluster_ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT -21 -i $tint -d $cluster_ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT -20 -i $tint -d $cluster_ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_REG   -j DROP", $action );
          util_direct_rule( "ipv4 filter INPUT -19 -i $tint -d $ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT -18 -i $tint -d $ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT -17 -i $tint -d $ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_REG   -j DROP", $action );
          util_direct_rule( "ipv4 filter INPUT -16 -i $tint -d 255.255.255.255 -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT -15 -i $tint -d 255.255.255.255 -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter INPUT -14 -i $tint -d 255.255.255.255 -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_REG   -j DROP", $action );
        }
      }
    }
  }
}

=item fd_netdata_rules

Firewalld rules for netdata service

=cut

sub fd_netdata_rules {
  my $action = shift;
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    util_direct_rule("ipv4 filter INPUT -50 -i $tint -p tcp -m tcp -s 127.0.0.1 --dport 19999 -j ACCEPT", $action );
    if ($cluster_enabled) {
      push my @mgmt_backend, map { $_->{management_ip} } pf::cluster::config_enabled_servers();
      foreach my $mgmt_back (uniq(@mgmt_backend)) {
        util_direct_rule("ipv4 filter INPUT -50 -i $tint -p tcp -m tcp -s $mgmt_back --dport 19999 -j ACCEPT", $action );
      }
    }
    util_direct_rule("ipv4 filter INPUT -49 -i $tint -p tcp -m tcp --dport 19999 -j DROP", $action );
  }
}

=item fd_pfconnector_server_rules

Firewalld rules for pfconnector server service

=cut

sub fd_pfconnector_server_rules {
  my $action = shift;
  if (ref($management_network) && exists $management_network->{Tint} ) {
    # The dynamic range used to access the fingerbank collector that are connected via a remote connector
    my $tint = $management_network->{Tint};
    my @pfconnector_ips = ("127.0.0.1");
    push @pfconnector_ips, (map { $_->{management_ip} } pf::cluster::config_enabled_servers()) if ($cluster_enabled);
    push @pfconnector_ips, $management_network->{Tip};
    @pfconnector_ips = uniq sort @pfconnector_ips;
    for my $ip (@pfconnector_ips) {
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m multiport -s $ip --dports 23001:23256 -j ACCEPT", $action );
    }
  }
}

=item fd_galera_autofix_rules

Firewalld rules for galera autofix server service

=cut

sub fd_galera_autofix_rules {
  my $action = shift;
  my $logger = get_logger();
  if ( util_reload_firewalld() ) {
    foreach my $network ( @ha_ints ) {
      my $tint =  $network->{Tint};
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 4253 -j ACCEPT", $action );
    }
    foreach my $tint ( @dhcplistener_ints ) {
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport 4253 -j ACCEPT", $action );
    }
  } else {
    $logger->warn("Firewalld is not started yet");
  }
}

=item fd_mariadb_rules

Firewalld rules for mariadb server service

=cut

sub fd_mariadb_rules {
  my $action = shift;
  my $logger = get_logger();
  if ( util_reload_firewalld() ) {
    my $tint = $management_network->{Tint};
    util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 3306 -j ACCEPT", $action );
  } else {
    $logger->warn("Firewalld is not started yet");
  }
}

=item fd_mysql_prob_rules

Firewalld rules for mysql prob service

=cut

sub fd_mysql_prob_rules {
  my $action = shift;
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport 3307 -j ACCEPT", $action );
    }
  }
}

=item fd_kafka_rules

Firewalld rules for kafka service

=cut

sub fd_kafka_rules {
  my $action = shift;
  if (ref($management_network) && exists $management_network->{Tint} ) {
    my $tint = $management_network->{Tint};
    if ( $tint ne "" ) {
      for my $client (@{$ConfigKafka{iptables}{clients}}) {
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp -m tcp -s $client --dport 9092 -j ACCEPT" , $action );
      }
      for my $ip (@{$ConfigKafka{iptables}{cluster_ips}}) {
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp -m tcp -s $ip --dport 29092 -j ACCEPT" , $action );
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp -m tcp -s $ip --dport 9092 -j ACCEPT" , $action );
        util_direct_rule( "ipv4 filter INPUT 0 -i $tint -p tcp -m tcp -s $ip --dport 9093 -j ACCEPT" , $action );
      }
    }
  }
}

=item fd_docker_dnat_rules

Firewalld rules for docker service

=cut

sub fd_docker_dnat_rules {
  my $action = shift;
  #DNAT traffic from docker to mgmt ip
  my $logger = get_logger();
  my $mgmt_ip = (defined($management_network->tag('vip'))) ? $management_network->tag('vip') : $management_network->tag('ip');
  if ( $mgmt_ip ne "" ) {
    util_direct_rule("ipv4 nat PREROUTING  50 -m addrtype --dst-type LOCAL -j PRE_docker0", $action );
    util_direct_rule("ipv4 nat PREROUTING  -50 -p udp -s 100.64.0.0/10 -d $mgmt_ip -j DNAT --to 100.64.0.1", $action );
    util_direct_rule("ipv4 nat OUTPUT      -50  ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j ACCEPT", $action );
    util_direct_rule("ipv4 nat POSTROUTING 100 -s 100.64.0.0/10 ! -o docker0 -j MASQUERADE", $action );
    util_direct_rule("ipv4 nat PRE_docker0 50 -i docker0 -j RETURN", $action );
  }
  util_direct_rule( "ipv4 filter FORWARD -100 -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT", $action );
  util_direct_rule( "ipv4 filter FORWARD -99 -i docker0 ! -o docker0 -j ACCEPT", $action );
  util_direct_rule( "ipv4 filter FORWARD -98 -i docker0 -o docker0 -j ACCEPT", $action );
}

=item fd_fingerbank_collector_rules

Firewalld rules for fingerbank collector service

=cut

sub fd_fingerbank_collector_rules {
  my $action = shift;
  if (netflow_enabled()) {
    util_direct_rule( "ipv4 filter FORWARD -97 -j NETFLOW" , $action );
  }
}

=item fd_radiusd_eduroam_rules

Firewalld rules for radiusd eduroam service

=cut

sub fd_radiusd_eduroam_rules {
  my $action = shift;
  my $logger = get_logger();
  # eduroam RADIUS virtual-server
  if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
    my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
    my $eduroam_listening_port = $eduroam_authentication_source[0]{'auth_listening_port'};    # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
    my $eduroam_listening_port_backend = $eduroam_listening_port + 10;
    my $mgnt_zone = $management_network->{Tint};
    util_direct_rule( "ipv4 filter INPUT 0 -i $mgnt_zone -p tcp -m tcp --dport $eduroam_listening_port -j ACCEPT", $action );
    util_direct_rule( "ipv4 filter INPUT 0 -i $mgnt_zone -p udp -m udp --dport $eduroam_listening_port -j ACCEPT", $action );
    util_direct_rule( "ipv4 filter INPUT 0 -i $mgnt_zone -p tcp -m tcp --dport $eduroam_listening_port_backend -j ACCEPT", $action ) if ($cluster_enabled);
    util_direct_rule( "ipv4 filter INPUT 0 -i $mgnt_zone -p udp -m udp --dport $eduroam_listening_port_backend -j ACCEPT", $action ) if ($cluster_enabled);
    foreach my $network ( @radius_ints ) {
      my $tint = $network->{Tint};
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport $eduroam_listening_port -j ACCEPT", $action );
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport $eduroam_listening_port -j ACCEPT", $action );
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p tcp -m tcp --dport $eduroam_listening_port_backend -j ACCEPT", $action ) if ($cluster_enabled);
      util_direct_rule("ipv4 filter INPUT 0 -i $tint -p udp -m udp --dport $eduroam_listening_port_backend -j ACCEPT", $action ) if ($cluster_enabled);
    }
  }
  else {
    $logger->info( "# eduroam integration is not configured" );
  }
}

=item fd_pfipset_rules

Firewalld rules for pfipset service
Since this service is a requirement for inline, this part also include inline rules
So related to ipset.pm

=cut

sub fd_pfipset_rules {
  my $action = shift;
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
          util_direct_rule( "ipv4 filter FORWARD -49 -i $tint -m set --match-set pfsession_passthrough dst,dst -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD -49 -o $tint -m set --match-set pfsession_passthrough dst,dst -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD -48 -i $tint -m set --match-set pfsession_passthrough src,src -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD -48 -o $tint -m set --match-set pfsession_passthrough src,src -j ACCEPT", $action );
        }
        if ( $isolation_passthrough_enabled && ( $type eq $pf::config::NET_TYPE_VLAN_ISOL ) ) {
          util_direct_rule( "ipv4 filter FORWARD -47 -i $tint -m set --match-set pfsession_isol_passthrough dst,dst -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD -47 -o $tint -m set --match-set pfsession_isol_passthrough dst,dst -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD -46 -i $tint -m set --match-set pfsession_isol_passthrough src,src -j ACCEPT", $action );
          util_direct_rule( "ipv4 filter FORWARD -46 -o $tint -m set --match-set pfsession_isol_passthrough src,src -j ACCEPT", $action );
        }
      }
    }
  }
  pfipset_provisioning_passthroughs();
  pfipset_inline_rules($action);
}

sub pfipset_provisioning_passthroughs {
  my $logger = get_logger();
  my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
  if ($passthrough_enabled) {
    $logger->debug("Installing passthroughs for provisioning");
    foreach my $config (tied(%ConfigProvisioning)->search(type => 'kandji')) {
      $logger->info("Adding passthrough for Kandji");
      my $enroll_host = $config->{enroll_url} ? URI->new($config->{enroll_url})->host : $config->{host};
      my $enroll_port = $config->{enroll_url} ? URI->new($config->{enroll_url})->port : $config->{port};
      my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough ".$enroll_host.",".$enroll_port." 2>&1");
      pf_run($cmd);
      util_reload_firewalld();
    }

    foreach my $config (tied(%ConfigProvisioning)->search(type => 'mobileiron')) {
      $logger->info("Adding passthrough for MobileIron");
      # Allow the host for the onboarding of devices
      my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$config->{boarding_port} 2>&1");
      my @lines  = pf_run($cmd);
      # Allow http communication with the MobileIron server
      $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$HTTP_PORT 2>&1");
      pf_run($cmd);
      util_reload_firewalld();
      # Allow https communication with the MobileIron server
      $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$HTTPS_PORT 2>&1");
      pf_run($cmd);
      util_reload_firewalld();
    }

    foreach my $config (tied(%ConfigProvisioning)->search(type => 'opswat')) {
      $logger->info("Adding passthrough for OPSWAT");
      # Allow http communication with the OSPWAT server
      my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTP_PORT 2>&1");
      pf_run($cmd);
      util_reload_firewalld();
      # Allow https communication with the OPSWAT server
      $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTPS_PORT 2>&1");
      pf_run($cmd);
      util_reload_firewalld();
    }

    foreach my $config (tied(%ConfigProvisioning)->search(type => 'sentinelone')) {
      $logger->info("Adding passthrough for SentinelOne");
      # Allow http communication with the SentinelOne server
      my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTP_PORT 2>&1");
      pf_run($cmd);
      util_reload_firewalld();
      # Allow https communication with the SentinelOne server
      $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTPS_PORT 2>&1" );
      pf_run($cmd);
      util_reload_firewalld();
    }
    $logger->info("Adding IP based passthrough for connectivitycheck.gstatic.com");
    # Allow the host for the onboarding of devices
    my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough 172.217.13.99,80 2>&1");
    pf_run($cmd);
    util_reload_firewalld();
    $cmd = untaint_chain("sudo ipset --add pfsession_passthrough 172.217.13.99,443 2>&1");
    pf_run($cmd);
    util_reload_firewalld();
  }
}

sub pfipset_inline_rules {
  my $action = shift;
  inline_nat_back_rules($action);
  # Note: I'm giving references to this guy here so he can directly mess with the tables
  inline_generate_rules($action);
  # NAT
  inline_nat_if_src_rules($action);
  inline_nat_redirect_rules($action);
  # Mangle
  inline_mangle_rules($action);
  util_reload_firewalld();
}

sub get_inline_snat_interface {
  my ($self) = @_;
  my $logger = get_logger();
  if (defined ($Config{'inline'}{'interfaceSNAT'}) && $Config{'inline'}{'interfaceSNAT'} ne '') {
    return $Config{'inline'}{'interfaceSNAT'};
  } else {
    return $management_network->tag("int");
  }
}

sub inline_nat_back_rules {
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
      util_direct_rule("ipv4 filter FORWARD 0 -m state --state ESTABLISHED,RELATED -j ACCEPT", $action );
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

sub inline_generate_rules {
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

      my $rule = "-p udp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
      util_direct_rule("ipv4 nat PREROUTING -50 $rule -m mark --mark 0x$IPTABLES_MARK_UNREG -j DNAT --to $gateway", $action );
      util_direct_rule("ipv4 nat PREROUTING -50 $rule -m mark --mark 0x$IPTABLES_MARK_ISOLATION -j DNAT --to $gateway", $action );

      if (isenabled($ConfigNetworks{$network}{'split_network'}) && defined($ConfigNetworks{$network}{'reg_network'}) && $ConfigNetworks{$network}{'reg_network'} ne '') {
        $rule = "-p udp --destination-port 53 -s $ConfigNetworks{$network}{'reg_network'}";
        util_direct_rule("ipv4 nat PREROUTING -50 $rule -m mark --mark 0x$IPTABLES_MARK_UNREG -j DNAT --to $gateway", $action );
        util_direct_rule("ipv4 nat PREROUTING -50 $rule -m mark --mark 0x$IPTABLES_MARK_ISOLATION -j DNAT --to $gateway", $action );
      }

      if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
        $logger->info("Adding Proxy interception rules");
        foreach my $intercept_port ( split(',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
          my $rule = "-p tcp --destination-port $intercept_port -s $network/$ConfigNetworks{$network}{'netmask'}";
          util_direct_rule("ipv4 nat PREROUTING -50 $rule -m mark --mark 0x$IPTABLES_MARK_UNREG -j DNAT --to $gateway", $action );
          util_direct_rule("ipv4 nat PREROUTING -50 $rule -m mark --mark 0x$IPTABLES_MARK_ISOLATION -j DNAT --to $gateway", $action );
        }
      }
    }

    $logger->info("building firewall to accept registered users through inline interface");
    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));

    if ($passthrough_enabled) {
      util_direct_rule("ipv4 filter FORWARD 0 -m mark --mark 0x$IPTABLES_MARK_UNREG -m set --match-set pfsession_passthrough dst,dst -j ACCEPT", $action );
      util_direct_rule("ipv4 filter FORWARD 0 -m mark --mark 0x$IPTABLES_MARK_ISOLATION -m set --match-set pfsession_isol_passthrough dst,dst -j ACCEPT", $action );
    }
    util_direct_rule("ipv4 filter FORWARD 0 -m mark --mark 0x$IPTABLES_MARK_REG -j ACCEPT", $action );
  } else {
    $logger->info("NO Action taken on DNS DNAT rules for unregistered and isolated inline clients.");
  }
  $logger->info("Inline rules are done.");
}

sub inline_nat_if_src_rules {
  my $action = shift;
  my $logger = get_logger();
  $logger->info("Inline if src rules are starting for NAT.");
  if ( is_inline_enforcement_enabled() ) {
    $logger->info("The action $action has been set on inline clients for table NAT.");
    # internal interfaces handling
    foreach my $interface (@internal_nets) {
      my $dev = $interface->tag("int");
      my $enforcement_type = $Config{"interface $dev"}{'enforcement'};

      # inline enforcement
      if (is_type_inline($enforcement_type)) {
         # send everything from inline interfaces to the inline chain
        util_direct_rule("ipv4 nat POSTROUTING 100 -j MASQUERADE", $action );
      }
    }

    # NAT POSTROUTING
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
            util_direct_rule("ipv4 nat POSTROUTING 50 -s $network/$inline_obj->{BITS} -o $val -m mark --mark 0x$_ -j ACCEPT", $action );
          }
        }
        util_direct_rule("ipv4 nat POSTROUTING 100 -m mark --mark 0x$_ -j MASQUERADE", $action );
      }
      my $mgmt_int = $management_network->tag("int");
      util_direct_rule("ipv4 nat POSTROUTING 100 -o $mgmt_int -m mark --mark 0x$_ -j MASQUERADE", $action );
    }
  } else {
    $logger->info("NO Action taken on inline clients for table NAT.");
  }
  $logger->info("Inline if src rules are done for NAT.");
}

sub inline_mangle_rules {
  my $action = shift;
  my $logger = get_logger();
  $logger->info("Mangle rules are starting.");
  if ( is_inline_enforcement_enabled() ) {
    $logger->info("The action $action has been set on mangle rules.");

    # pfdhcplistener in most cases will be enforcing access
    # however we insert these marks on startup in case PacketFence is restarted
    # default catch all: mark unreg
    util_direct_rule("ipv4 mangle PREROUTING 0 -j MARK --set-mark 0x$IPTABLES_MARK_UNREG", $action );
    foreach my $network ( keys %ConfigNetworks ) {
      next if ( !pf::config::is_network_type_inline($network) );
      foreach my $IPTABLES_MARK ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
        my $rule = "";
        if ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE_L3$/i) {
          $rule = " -m set --match-set pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network src ";
        } else {
          $rule .= " -m set --match-set pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network src,src ";
        }
        $rule .= "-j MARK --set-mark 0x$IPTABLES_MARK";
        util_direct_rule("ipv4 mangle PREROUTING 0 $rule", $action );
      }
    }

    # Build lookup table for MAC/IP mapping
    my @iplog_open = pf::ip4log::list_open();
    my %iplog_lookup = map { $_->{'mac'} => $_->{'ip'} } @iplog_open;

    my @ops = ();
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

sub inline_nat_redirect_rules {
  my $action = shift;
  my $logger = get_logger();
  $logger->info("Nat redirect rules are starting.");
  if ( is_inline_enforcement_enabled() ) {
    $logger->info("The action $action has been set on nat redirect rules.");
    my $rule = '';

    # Exclude the OAuth from the DNAT
    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));

    if ($passthrough_enabled) {
      $rule = " -m set --match-set pfsession_passthrough dst,dst -m mark --mark 0x$IPTABLES_MARK_UNREG -j ACCEPT";
      util_direct_rule("ipv4 nat PREROUTING -50 $rule", $action );
      $rule = " -m set --match-set pfsession_isol_passthrough dst,dst -m mark --mark 0x$IPTABLES_MARK_ISOLATION -j ACCEPT";
      util_direct_rule("ipv4 nat PREROUTING -50 $rule", $action );
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
        " -p $protocol --destination-port $port -s $network/$ConfigNetworks{$network}{'netmask'} " .
        " -m mark --mark 0x$IPTABLES_MARK_ISOLATION -j DNAT --to $gateway";
        util_direct_rule("ipv4 nat PREROUTING -50 $rule", $action );
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
=item service_to_zone

Firewalld add a service to a zone and reload the config

=cut

sub service_to_zone {
  my $zone = shift;
  my $action = shift;
  my $service = shift;
  my $logger = get_logger();

  if ( defined is_service_available($service) && defined is_zone_available( $zone ) ) {
    util_firewalld_job( " --zone=$zone --$action-service=$service --permanent" );
    $logger->info( "$action for service $service on zone $zone premanently" );
    util_reload_firewalld();
  } else {
    $logger->error( "Please run generate config to create services and zones" );
  }
}

=item generate_chain

Firewalld generate a chain for iptable

=cut

sub generate_chain {
  my $ipv   = shift;
  my $table = shift;
  my $chain = shift;
  my $action = shift;
  my $logger = get_logger();
  if ( ! defined $ipv || $ipv eq "" ){
    $logger->war( "The generate_chain ipv is not defined or empty. default will be 'ipv4'." );
    $ipv = "ipv4";
  }
  if ( ! defined $table || $table eq "" ){
    $logger->war( "The generate_chain table is not defined or empty. default will be 'filter'." );
    $table = "filter";
  }
  if ( ! defined $action || $action eq "" ){
    $logger->war( "The generate_chain action is not defined or empty. default will be 'add'." );
    $action = "add";
  }
  util_chain( $ipv, $table, $chain, $action );
  $logger->info( "$action for table $table with chain $chain in iptype $ipv" );
}

=item get_network_type_and_chain

Firewalld return vlan type and related chain according to node ip

=cut

sub get_network_type_and_chain {
  my $ip = shift;
  my $type = $pf::config::NET_TYPE_VLAN_REG;
  my $chain = "input-internal-vlan-if";
  foreach my $network ( keys %ConfigNetworks ) {
    # We skip inline networks/interfaces
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

=item get_lines_from_file_in_array

Firewalld return array of lines from file

=cut

sub get_lines_from_file_in_array {
  my $file = shift;
  my @lines;
  if ( -f $file && -s $file ) {
    @lines = read_file($file, chomp => 1);
  }
  return \@lines;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
