package pf::iptables;

=head1 NAME

pf::iptables - module for iptables rules management.

=cut

=head1 DESCRIPTION

pf::iptables contains the functions necessary to manipulate the
iptables rules used when using PacketFence in ARP or DHCP mode.

=head1 CONFIGURATION AND ENVIRONMENT

F<pf.conf> configuration file and iptables template F<iptables.conf>.

=cut

use strict;
use warnings;

use IO::Interface::Simple;
use Readonly;
use NetAddr::IP;
use List::MoreUtils qw(uniq);
use URI ();
use Sys::Hostname;
use Template;
use JSON;
use File::Slurp;
use Try::Tiny;
use Switch;
use Symbol qw(gensym);
use File::Path qw(make_path);
use IPC::Open3 qw(open3);
use File::Basename;
use Scalar::Util 'reftype';
use Data::Dumper;

BEGIN {
  use Exporter ();
  our ( @ISA, @EXPORT );
  @ISA = qw(Exporter);
  @EXPORT = qw(
    iptables_api_frontend_rules
    iptables_configreload
    iptables_docker_dnat_rules
    iptables_fingerbank_collector_rules
    iptables_flush_to_default
    iptables_galera_autofix_rules
    iptables_generate_config
    iptables_haproxy_admin_rules
    iptables_haproxy_db_rules
    iptables_haproxy_portal_rules
    iptables_httpd_aaa_rules
    iptables_httpd_dispatcher_rules
    iptables_httpd_portal_rules
    iptables_httpd_webservices_rules
    iptables_kafka_rules
    iptables_keepalived_rules
    iptables_mariadb_rules
    iptables_mysql_prob_rules
    iptables_netdata_rules
    iptables_pfacct_rules
    iptables_pfconnector_server_rules
    iptables_pfdhcp_rules
    iptables_pfdns_rules
    iptables_pfipset_rules
    iptables_proxysql_rules
    iptables_radiusd_acct_rules
    iptables_radiusd_auth_rules
    iptables_radiusd_cli_rules
    iptables_radiusd_eduroam_rules
    iptables_radiusd_lb_rules
    iptables_restore
    iptables_restore_noflush
    iptables_save
    iptables_services_rules
    iptables_snmptrapd_rules
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
    @portal_ints
    @radius_ints
    @dhcp_ints
    @dhcplistener_ints
    @dns_ints
    $NET_TYPE_INLINE_L3
    %mark_type_to_str
);

use pf::log;
use pf::constants;
use pf::config::cluster;
use pf::file_paths qw(
    $generated_conf_dir
    $conf_dir
    $generated_iptables_conf_dir
    $iptable_custom_config_file
);
use pf::util;
use pf::security_event qw(security_event_view_open_uniq security_event_count);
use pf::authentication;
use pf::cluster;
use pf::ConfigStore::Provisioning;
use pf::ConfigStore::Domain;
use pf::node qw(nodes_registered_not_violators node_view node_deregister $STATUS_REGISTERED);
use pf::nodecategory;
use pf::ip4log;
use pf::authentication;
use pf::api::unifiedapiclient;
use pf::constants;
use pf::config::cluster;

tie our %NetworkConfig, 'pfconfig::cached_hash', "resource::network_config($host_id)";
tie our %ConfigKafka, 'pfconfig::cached_hash', "config::Kafka";

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut

=item new

Constructor

=cut

sub new {
   my $logger = get_logger();
   $logger->debug("instantiating new pf::iptables object");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item iptables_configreload

Reload the config

=cut

sub iptables_configreload {
    my ($force) = @_;
    my $logger = get_logger();
    $logger->info( "Start config reload" );
    if ($force eq 1) {
        iptables_flush_to_default();
        iptables_services_rules("REMOVE");
    }
    iptables_services_rules("ADD");
    iptables_generate_config();
}

sub iptables_flush_to_default {
    my $logger = get_logger();
    safe_pf_run(qw(sudo iptables -F));
    safe_pf_run(qw(sudo iptables -X));
    safe_pf_run(qw(sudo iptables -t nat -F));
    safe_pf_run(qw(sudo iptables -t nat -X));
    safe_pf_run(qw(sudo iptables -t mangle -F));
    safe_pf_run(qw(sudo iptables -t mangle -X));
    safe_pf_run(qw(sudo iptables -P INPUT ACCEPT));
    safe_pf_run(qw(sudo iptables -P FORWARD ACCEPT));
    safe_pf_run(qw(sudo iptables -P OUTPUT ACCEPT));
    safe_pf_run(qw(sudo iptables -t nat -N DOCKER));
    safe_pf_run(qw(sudo iptables -t nat -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER));
    safe_pf_run(qw(sudo iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER));
    safe_pf_run(qw(sudo iptables -t nat -A POSTROUTING -s 100.64.0.0/10 ! -o docker0 -j MASQUERADE));
    safe_pf_run(qw(sudo iptables -t nat -A DOCKER -i docker0 -j RETURN));
    $logger->info( "Iptables have been flush to default" );
    return 1;
}


=item iptables_save

Save iptables nat, mangle and filter.

=cut

sub iptables_save {
    my ($self, $save_file) = @_;
    my $logger = get_logger();
    $logger->info( "saving existing iptables to " . $save_file );
    safe_pf_run("/usr/sbin/iptables-save", '-t', 'nat', { stdout => $save_file });
    safe_pf_run("/usr/sbin/iptables-save", '-t', 'mangle', { stdout => $save_file, stdout_append => 1 });
    safe_pf_run("/usr/sbin/iptables-save", '-t', 'filter', { stdout => $save_file, stdout_append => 1 });
}

=item iptables_generate_config

Generate the iptable config from iptables service config.

=cut

sub iptables_generate_config {
    my ($self) = @_;
    my $logger = get_logger();

    if ( ! util_management_network_is_set("generate_config") ) {
        return 0;
    }

    # Check for and load content from custom specific file if it exists
    my $custom = util_add_custom_config_from_file( $iptable_custom_config_file );
    if ($custom) {
        $logger->info( "Successfully loaded custom configuration from $iptable_custom_config_file" );
    } else {
        $logger->info( "No custom configuration file ($iptable_custom_config_file) found" );
    }

    util_generated_iptables_fix_dir_permissions();
    my %configs;
    # Get content from service generated json config files
    my @config_files = read_dir_recursive($generated_iptables_conf_dir);
    if (@config_files) {
        foreach my $conf ( @config_files ) {
            my $json_text = read_file($generated_iptables_conf_dir."/".$conf);
            my $data = decode_json($json_text);
            my $conf_name = $data->{name};
            $configs{$conf_name} = $data;
        }
    }

    # Merge configurations
    my %merged = (
        filter => { INPUT => [], FORWARD => [], OUTPUT => [] },
        mangle => { PREROUTING => [], INPUT => [], FORWARD => [], OUTPUT => [], POSTROUTING => [] },
        nat => { PREROUTING => [], OUTPUT => [], POSTROUTING => [] }
    );

    my $tint = $management_network->{Tint};
    push @{$merged{filter}{INPUT}}, "-i $tint -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT";

    foreach my $name (sort keys %configs) {
        my $fw = $configs{$name};
        # Merge filter rules if they exist
        if ($fw->{filter}) {
            foreach my $chain (keys %{$merged{filter}}) {
                push @{$merged{filter}{$chain}}, @{$fw->{filter}{$chain}} if $fw->{filter}{$chain};
            }
        }
        # Merge mangle rules if they exist
        if ($fw->{mangle}) {
            foreach my $chain (keys %{$merged{mangle}}) {
                push @{$merged{mangle}{$chain}}, @{$fw->{mangle}{$chain}} if $fw->{mangle}{$chain};
            }
        }
        # Merge nat rules if they exist
        if ($fw->{nat}) {
            foreach my $chain (keys %{$merged{nat}}) {
                push @{$merged{nat}{$chain}}, @{$fw->{nat}{$chain}} if $fw->{nat}{$chain};
            }
        }
    }

    # Remove duplicates while preserving order
    foreach my $table (keys %merged) {
        foreach my $chain (keys %{$merged{$table}}) {
            my @unique_rules;
            my %seen;
            foreach my $rule (@{$merged{$table}{$chain}}) {
                push @unique_rules, $rule unless $seen{$rule}++;
            }
            $merged{$table}{$chain} = \@unique_rules;
        }
    }

    # Process template
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process(
        "$conf_dir/iptables.conf.tt",
        {
            configs => \%configs,
            custom  => $custom,
            merged  => \%merged
        },
        "$generated_conf_dir/iptables_generated_rules.conf"
    ) or die $tt->error();

    iptables_restore("$generated_conf_dir/iptables_generated_rules.conf");
}

sub iptables_restore {
    my ($restore_file) = @_;
    my $logger = get_logger();
    if ( -r $restore_file ) {
        $logger->info( "restoring iptables from " . $restore_file );
        safe_pf_run("/sbin/iptables-restore", {stdin => $restore_file});
    } else {
        printf "\n\nFAILED TO RESTORE\n\n";
        $logger->warm( "Failed to restore IPTABLES from " . $restore_file );
    }
}

sub iptables_restore_noflush {
    my ($self, $restore_file) = @_;
    my $logger = get_logger();
    if ( -r $restore_file ) {
        $logger->info( "restoring iptables (no flush) from " . $restore_file );
        safe_pf_run("/sbin/iptables-restore", '-n', {stdin => $restore_file});
    }
}

=item iptables_services_rules

Firewalld apply rules according to running services
need to get services that are running and use the dedicated function to restart accordingly

=cut

sub iptables_services_rules {
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
      packetfenca-httpd.portal.service
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
        case "docker.service"                            { iptables_docker_dnat_rules($action); }
        case "packetfence-api-frontend.service"          { iptables_api_frontend_rules($action); }
        case "packetfence-fingerbank-collector.service"  { iptables_fingerbank_collector_rules($action); }
        case "packetfence-galera-autofix.service"        { iptables_galera_autofix_rules($action); }
        case "packetfence-haproxy-admin.service"         { iptables_haproxy_admin_rules($action); }
        case "packetfence-haproxy-db.service"            { iptables_haproxy_db_rules($action); }
        case "packetfence-haproxy-portal.service"        { iptables_haproxy_portal_rules($action); }
        case "packetfence-httpd.aaa.service"             { iptables_httpd_aaa_rules($action); }
        case "packetfence-httpd.dispatcher.service"      { iptables_httpd_dispatcher_rules($action); }
        case "packetfence-httpd.portal.service"          { iptables_httpd_portal_rules($action); }
        case "packetfence-httpd.webservices.service"     { iptables_httpd_webservices_rules($action); }
        case "packetfence-kafka.service"                 { iptables_kafka_rules($action); }
        case "packetfence-keepalived.service"            { iptables_keepalived_rules($action); }
        case "packetfence-mariadb.service"               { iptables_mariadb_rules($action); }
        case "packetfence-mysql-probe.service"           { iptables_mysql_prob_rules($action); }
        case "packetfence-netdata.service"               { iptables_netdata_rules($action); }
        case "packetfence-pfacct.service"                { iptables_pfacct_rules($action); }
        case "packetfence-pfconnector-server.service"    { iptables_pfconnector_server_rules($action); }
        case "packetfence-pfdhcp.service"                { iptables_pfdhcp_rules($action); }
        case "packetfence-pfdns.service"                 { iptables_pfdns_rules($action); }
        case "packetfence-pfipset.service"               { iptables_pfipset_rules($action); }
        case "packetfence-proxysql.service"              { iptables_proxysql_rules($action); }
        case "packetfence-radiusd-acct.service"          { iptables_radiusd_acct_rules($action); }
        case "packetfence-radiusd-auth.service"          { iptables_radiusd_auth_rules($action); }
        case "packetfence-radiusd-cli.service"           { iptables_radiusd_cli_rules($action); }
        case "packetfence-radiusd-eduroam.service"       { iptables_radiusd_eduroam_rules($action); }
        case "packetfence-radiusd-load_balancer.service" { iptables_radiusd_lb_rules($action); }
        case "packetfence-snmptrapd.service"             { iptables_snmptrapd_rules($action); }
        else { $logger->info( "The service $state->{'Id'} is not using Firewalld for its configuration" ) }
      }
    }
  }
}

=item iptables_haproxy_portal_rules

Iptable rules for haproxy portal service

=cut

sub iptables_haproxy_portal_rules {
    my $service_name = "haproxy_portal_rules";
    my $action = shift;

    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }

    my $logger = get_logger();
    my $chains = util_create_chains();

    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        $chains->{'name'} = $service_name;
        util_safe_push( "-i $tint -p tcp -m tcp --dport 80 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p tcp -m tcp --dport 443 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p tcp -m tcp -s 127.0.0.1 --dport 1025 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        if ($cluster_enabled) {
            push my @mgmt_backend, map { $_->{management_ip} } pf::cluster::config_enabled_servers();
            foreach my $mgmt_back (uniq(@mgmt_backend)) {
                util_safe_push( "-i $tint -p tcp -m tcp -s $mgmt_back --dport 1025 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            }
        }
        util_safe_push( "-i $tint -p tcp -m tcp --dport 1025 -j DROP", $chains->{'filter'}{'INPUT'} );
    }

    if ( @portal_ints ) {
        # 'portal' interfaces handling
        $chains->{'name'} = $service_name;
        foreach my $portal_interface ( @portal_ints ) {
            my $tint = $portal_interface->tag("int");
            util_safe_push( "-i $tint -p tcp -m tcp --dport 80 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 443 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: Portal Ints are not set.");
    }

    if ( @inline_enforcement_nets ) {
        # 'portal' interfaces handling
        $chains->{'name'} = $service_name;
        foreach my $network ( @inline_enforcement_nets ) {
            my $tint =  $network->{Tint};
            util_safe_push( "-i $tint -p tcp -m tcp --dport 80 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 443 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: Inline Enforcement Nets are not set.");
    }

    if ( @vlan_enforcement_nets ) {
        # 'portal' interfaces handling
        $chains->{'name'} = $service_name;
        foreach my $network ( @vlan_enforcement_nets ) {
            my $tint =  $network->{Tint};
            util_safe_push( "-i $tint -p tcp -m tcp --dport 80 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 443 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: Vlan Enforcement Nets are not set.");
    }

    if ($chains->{'name'} ne "") {
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_radiusd_lb_rules

iptables rules for radius lb service

=cut

sub iptables_radiusd_lb_rules {
    my $service_name = "radiusd_lb_rules";
    my $action = shift;

    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }

    my $logger = get_logger();
    my $chains = util_create_chains();

    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        $chains->{'name'} = $service_name;
        util_safe_push( "-i $tint -p udp -m udp --dport 1814 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
    }

    if ( @radius_ints ) {
        # 'radius' interfaces handling
        $chains->{'name'} = $service_name;
        foreach my $network ( @radius_ints ) {
            my $tint =  $network->{Tint};
            util_safe_push( "-i $tint -p udp -m udp --dport 1814 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: Radius Ints are not set.");
    }

    if ($chains->{'name'} ne "") {
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_keepalived_rules

Iptable rules for keepalived service

=cut

sub iptables_keepalived_rules {
    my $service_name = "keepalived_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    my $chains = util_create_chains();

    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        $chains->{'name'} = $service_name;
        util_safe_push( "-i $tint -d 224.0.0.0/8 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p vrrp -j ACCEPT", $chains->{'filter'}{'INPUT'} ) if ($cluster_enabled);
    }

    if ( @internal_nets ) {
        # internal interfaces handling
        foreach my $interface (@internal_nets) {
            my $tint = $interface->tag("int");
            my $enforcement_type = $Config{"interface $tint"}{'enforcement'};
            # VLAN enforcement
            if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
                if ($tint =~ m/(\w+):\d+/) {
                    $tint = $1;
                }
                $chains->{name} = $service_name;
                util_safe_push( "-i $tint -d 224.0.0.0/8 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                util_safe_push( "-i $tint -p vrrp -j ACCEPT", $chains->{'filter'}{'INPUT'} ) if ($cluster_enabled);
            # inline enforcement
            } elsif (is_type_inline($enforcement_type)) {
                $chains->{name} = $service_name;
                util_safe_push( "-i $tint -d 224.0.0.0/8 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                util_safe_push( "-i $tint -p vrrp -j ACCEPT", $chains->{'filter'}{'INPUT'} ) if ($cluster_enabled);
            }
        }
    } else {
        $logger->warn("Service $service_name: No Internal Nets is not set.");
    }

    if ( @portal_ints ) {
        # 'portal' interfaces handling
        $chains->{'name'} = $service_name;
        foreach my $portal_interface ( @portal_ints ) {
            my $tint = $portal_interface->tag("int");
            util_safe_push( "-i $tint -d 224.0.0.0/8 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p vrrp -j ACCEPT", $chains->{'filter'}{'INPUT'} ) if ($cluster_enabled);
        }
    } else {
        $logger->warn("Service $service_name: Portal Ints are not set.");
    }

    if ( @radius_ints ) {
        # 'radius' interfaces handling
        $chains->{'name'} = $service_name;
        foreach my $radius_interface ( @radius_ints ) {
            my $tint = $radius_interface->tag("int");
            util_safe_push( "-i $tint -d 224.0.0.0/8 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p vrrp -j ACCEPT", $chains->{'filter'}{'INPUT'} ) if ($cluster_enabled);
        }
    } else {
        $logger->warn("Service $service_name: Radius Ints are not set.");
    }

    if ($chains->{'name'} ne "") {
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_proxysql_rules

Iptable rules for proxysql service

=cut

sub iptables_proxysql_rules {
    my $service_name = "proxysql_rules";
    my $action = shift;

    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }

    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $chains = util_create_chains();
        $chains->{'name'} = $service_name;
        my $tint = $management_network->{Tint};
        util_safe_push( "-i $tint -p tcp -m tcp --dport 6033 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_haproxy_admin_rules

Iptable rules for haproxy admin service

=cut

sub iptables_haproxy_admin_rules {
    my $service_name = "haproxy_admin_rules";
    my $action = shift;

    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }

    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $chains = util_create_chains();
        $chains->{'name'} = $service_name;
        my $web_admin_port = $Config{'ports'}{'admin'};
        util_safe_push( "-i $tint -p tcp -m tcp --dport $web_admin_port -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p tcp -m tcp -s 127.0.0.1 --dport 1027 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        if ($cluster_enabled) {
            push my @mgmt_backend, map { $_->{management_ip} } pf::cluster::config_enabled_servers();
            foreach my $mgmt_back (uniq(@mgmt_backend)) {
                util_safe_push( "-i $tint -p tcp -m tcp -s $mgmt_back --dport 1027 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            }
        }
        util_safe_push( "-i $tint -p tcp -m tcp --dport 1027 -j DROP", $chains->{'filter'}{'INPUT'} );
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_httpd_webservices_rules

Iptable rules for httpd webservices service

=cut

sub iptables_httpd_webservices_rules {
    my $service_name = "httpd_webservices_rules";
    my $action = shift;

    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }

    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $chains = util_create_chains();
        $chains->{'name'} = $service_name;
        my $webservices_port = $Config{'ports'}{'soap'};
        util_safe_push( "-i $tint -p tcp -m tcp --dport $webservices_port -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_snmptrapd_rules

Iptable rules for snmptrapd service

=cut

sub iptables_snmptrapd_rules {
    my $service_name = "snmptrapd_rules";
    my $action = shift;

    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }

    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        util_safe_push( "-i $tint -p udp -m udp --dport 162 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_httpd_aaa_rules

Iptable rules for httpd aaa service

=cut

sub iptables_httpd_aaa_rules {
    my $service_name = "snmptrapd_rules";
    my $action = shift;

    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }

    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        my $aaa_port = $Config{'ports'}{'aaa'};
        util_safe_push( "-i $tint -p tcp -m tcp --dport $aaa_port -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_httpd_dispatcher_rules

Iptable rules for httpd dispatcher service
HTTP (parking portal)

=cut

sub iptables_httpd_dispatcher_rules {
    my $service_name = "httpd_dispatcher_rules";
    my $action = shift;

    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    my $chains = util_create_chains();

    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        $chains->{name} = $service_name;
        util_safe_push( "-i $tint -p tcp -m tcp --dport 5252 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
    }

    if ( @vlan_enforcement_nets ) {
        foreach my $network ( @vlan_enforcement_nets ) {
            my $tint =  $network->{Tint};
            $chains->{name} = $service_name;
            util_safe_push( "-i $tint -p tcp -m tcp --dport 5252 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: No Vlan Enforcement Nets is not set.");
    }

    if ($chains->{name} ne "") {
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_api_frontend_rules

Iptable rules for api frontend service

=cut

sub iptables_api_frontend_rules {
    my $service_name = "api_frontend_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        my $unifiedapi_port = $Config{'ports'}{'unifiedapi'};
        util_safe_push( "-i $tint -p tcp -m tcp --dport $unifiedapi_port -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_httpd_portal_rules

Iptable rules for httpd portal service

=cut

sub iptables_httpd_portal_rules {
    my $service_name = "httpd_portal_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    my $chains = util_create_chains();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        $chains->{name} = $service_name;
        my $httpd_portal_modstatus = $Config{'ports'}{'httpd_portal_modstatus'};
        util_safe_push( "-i $tint -p tcp -m tcp --dport $httpd_portal_modstatus -j ACCEPT", $chains->{'filter'}{'INPUT'} );
    }

    if ( @portal_ints ) {
        $chains->{name} = $service_name;
        foreach my $network ( @portal_ints ) {
            my $tint =  $network->{Tint};
            util_safe_push( "-i $tint -p tcp -m tcp --dport 8080 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: No Portal Ints are not set.");
    }
    if ($chains->{name} ne "") {
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_haproxy_db_rules

Iptable rules for haproxy db service

=cut

sub iptables_haproxy_db_rules {
    my $service_name = "haproxy_db_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        util_safe_push( "-i $tint -p tcp -m tcp -s 127.0.0.1 --dport 1026 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        if ($cluster_enabled) {
            push my @mgmt_backend, map { $_->{management_ip} } pf::cluster::config_enabled_servers();
            foreach my $mgmt_back (uniq(@mgmt_backend)) {
                util_safe_push( "-i $tint -p tcp -m tcp -s $mgmt_back --dport 1026 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            }
        }
        util_safe_push( "-i $tint -p tcp -m tcp --dport 1026 -j DROP", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p tcp -m tcp --dport 3306 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_radiusd_acct_rules

Iptable rules for radiusd acct service

=cut

sub iptables_radiusd_acct_rules {
    my $service_name = "haproxy_db_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( @radius_ints ) {
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        foreach my $radius_interface ( @radius_ints ) {
            my $tint = $radius_interface->tag("int");
            util_safe_push( "-i $tint -p udp -m udp --dport 1813 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p udp -m udp --dport 1823 -j ACCEPT", $chains->{'filter'}{'INPUT'} ) if ($cluster_enabled);
        }
        util_create_service_rules($chains);
    } else {
        $logger->warn("Service $service_name: Radius Ints are not set.");
    }
}

=item iptables_pfacct_rules

Iptable rules for pfacct service

=cut

sub iptables_pfacct_rules {
    my $service_name = "pfacct_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( @radius_ints ) {
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        foreach my $radius_interface ( @radius_ints ) {
            my $tint = $radius_interface->tag("int");
            util_safe_push( "-i $tint -p udp -m udp --dport 1813 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p udp -m udp --dport 1823 -j ACCEPT", $chains->{'filter'}{'INPUT'} ) if ($cluster_enabled);
        }
        util_create_service_rules($chains);
    } else {
        $logger->warn("Service $service_name: Radius Ints are not set.");
    }
}

=item iptables_radiusd_auth_rules

Iptable rules for radiusd auth service

=cut

sub iptables_radiusd_auth_rules {
    my $service_name = "radiusd_auth_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( @radius_ints ) {
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        foreach my $network ( @radius_ints ) {
            my $tint =  $network->{Tint};
            util_safe_push( "-i $tint -p udp -m udp --dport 1812 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 2083 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 2093 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p udp -m udp --dport 1822 -j ACCEPT", $chains->{'filter'}{'INPUT'} ) if ($cluster_enabled);
        }
        util_create_service_rules($chains);
    } else {
        $logger->warn("Service $service_name: Radius Ints are not set.");
    }
}

=item iptables_radiusd_cli_rules

Iptable rules for radiusd cli service

=cut

sub iptables_radiusd_cli_rules {
    my $service_name = "radiusd_cli_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( @radius_ints ) {
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        foreach my $network ( @radius_ints ) {
            my $tint =  $network->{Tint};
            util_safe_push( "-i $tint -p udp -m udp --dport 1815 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p udp -m udp --dport 1825 -j ACCEPT", $chains->{'filter'}{'INPUT'} ) if ($cluster_enabled);
        }
        util_create_service_rules($chains);
    } else {
        $logger->warn("Service $service_name: Radius Ints are not set.");
    }
}

=item iptables_pfdns_rules

Iptable rules for pfdns service

=cut

sub iptables_pfdns_rules {
    my $service_name = "pfdns_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    my $chains = util_create_chains();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        $chains->{name} = $service_name;
        util_safe_push( "-i $tint -p udp -m udp --dport 53 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p tcp -m tcp --dport 53 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
    }
    if ( @dns_ints ) {
        $chains->{name} = $service_name;
        foreach my $network ( @dns_ints ) {
            my $tint =  $network->{Tint};
            util_safe_push( "-i $tint -p udp -m udp --dport 53 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 53 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: DNS Ints are not set.");
    }
    if ( @inline_enforcement_nets ) {
        $chains->{name} = $service_name;
        foreach my $network ( @inline_enforcement_nets ) {
            my $tint =  $network->{Tint};
            util_safe_push( "-i $tint -p udp -m udp --dport 53 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 53 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: Inline Enforcement Nets are not set.");
    }
    if ( @vlan_enforcement_nets ) {
        $chains->{name} = $service_name;
        foreach my $network ( @vlan_enforcement_nets ) {
            my $tint =  $network->{Tint};
            util_safe_push( "-i $tint -p udp -m udp --dport 53 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 53 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: Inline Enforcement Nets are not set.");
    }
    if ( @vlan_enforcement_nets ) {
        $chains->{name} = $service_name;
        # OAuth
        my $internal_portal_ip = $Config{captive_portal}{ip_address};
        foreach my $interface (@internal_nets) {
            my $tint = $interface->tag("int");
            my $enforcement_type = $Config{"interface $tint"}{'enforcement'};
            if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
                if ($tint =~ m/(\w+):\d+/) {
                    $tint = $1;
                }
                util_safe_push( "-i $tint -d $internal_portal_ip -p tcp -m tcp --dport 53 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                util_safe_push( "-i $tint -d $internal_portal_ip -p udp -m udp --dport 53 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            }
        }
    } else {
        $logger->warn("Service $service_name: Vlan Enforcement Nets are not set.");
    }
    #NAT Intercept Proxy
    if ( @internal_nets ) {
        $chains->{name} = $service_name;
        dns_interception_rules($chains);
        dns_oauth_passthrough_rules($chains);
    } else {
        $logger->warn("Service $service_name: No Internal Nets defined.");
    }

    if ($chains->{name} ne "") {
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

sub dns_interception_rules {
    my $chains = shift;
    my $logger = get_logger();
  
    $logger->info("Service $chains->name: Interception rules are starting.");
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
                            my $rule = "-p tcp --dport $intercept_port -s $network/$ConfigNetworks{$network}{'netmask'}";
                            util_safe_push( "-i $tint $rule -j DNAT --to $destination", $chains->{'nat'}{'PREROUTING'} );
                        }
                    }
                    my $rule = "-p udp --dport 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
                    util_safe_push( "-i $tint $rule -j DNAT --to $destination", $chains->{'nat'}{'PREROUTING'} );
                    $rule    = "-p tcp --dport 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
                    util_safe_push( "-i $tint $rule -j DNAT --to $destination", $chains->{'nat'}{'PREROUTING'} );
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
                    my $rule = "-p tcp --dport $intercept_port";
                    util_safe_push( "-i $tint -d $internal_portal_ip $rule -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                }
            }
        }
    }
    $logger->info("Service $chains->{name}: Interception rules are done.");
}

sub dns_oauth_passthrough_rules {
    my $chains = shift;
    my $logger = get_logger();

    # OAuth
    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
    my $isolation_passthrough_enabled = isenabled($Config{'fencing'}{'isolation_passthrough'});
    my ($SNAT_ip, $mgmt_int);
    if ($passthrough_enabled) {
        $logger->info("Service $chains->{name}: DNS oauth rules are starting.");
        $logger->info("Service $chains->{name}: Adding Forward rules to allow connections to the OAuth2 Providers and passthrough.");
        foreach my $interface (@internal_nets) {
            my $tint = $interface->tag("int");
            my $ip   = $interface->tag("vip") || $interface->tag("ip");
            my $enforcement_type = $Config{"interface $tint"}{'enforcement'};
            # VLAN enforcement
            if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
                if ($tint =~ m/(\w+):\d+/) {
                    $tint = $1;
                }
                my ($type,$chain) = get_network_type_and_chain($ip);
                if ($passthrough_enabled && ($type eq $pf::config::NET_TYPE_VLAN_REG)) {
                    util_safe_push( "-i $tint -m set --match-set pfsession_passthrough dst,dst -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                    util_safe_push( "-i $tint -m set --match-set pfsession_passthrough src,src -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                    util_safe_push( "-o $tint -m set --match-set pfsession_passthrough dst,dst -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                    util_safe_push( "-o $tint -m set --match-set pfsession_passthrough src,src -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                }
                if ($isolation_passthrough_enabled && ($type eq $pf::config::NET_TYPE_VLAN_ISOL)) {
                    util_safe_push( "-i $tint -m set --match-set pfsession_isol_passthrough dst,dst -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                    util_safe_push( "-i $tint -m set --match-set pfsession_isol_passthrough src,src -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                    util_safe_push( "-o $tint -m set --match-set pfsession_isol_passthrough dst,dst -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                    util_safe_push( "-o $tint -m set --match-set pfsession_isol_passthrough src,src -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
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
                        util_safe_push( "-s $network/$network_obj->{BITS} -o $mgmt_int -j SNAT --to $SNAT_ip", $chains->{'nat'}{'POSTROUTING'} );
                    }
                } else {
                   util_safe_push( "-s $network/$network_obj->{BITS} -o $mgmt_int -j SNAT --to $SNAT_ip", $chains->{'nat'}{'POSTROUTING'} );
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
                        util_safe_push( "-s $network/$network_obj->{BITS} -o $int -j SNAT --to ".$if->address , $chains->{'nat'}{'POSTROUTING'} );
                    }
                } else {
                    util_safe_push( "-s $network/$network_obj->{BITS} -o $int -j SNAT --to ".$if->address , $chains->{'nat'}{'POSTROUTING'} );
                }
            }
        }
        $logger->info("Service $chains->{name}: DNS oauth rules are done.");
    }
}

=item iptables_pfdhcp_rules

Iptable rules for pfdhcp service

=cut

sub iptables_pfdhcp_rules {
    my $service_name = "pfdhcp_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    my $chains = util_create_chains();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        $chains->{name} = $service_name;
        util_safe_push( "-i $tint -p udp -m udp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
    }

    if ( @dhcp_ints ) {
        $chains->{name} = $service_name;
        foreach my $tint ( @dhcp_ints ) {
            util_safe_push( "-i $tint -p udp -m udp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: DHCP Ints are not set.");
    }

    if ( @dhcplistener_ints ) {
        $chains->{name} = $service_name;
        foreach my $tint ( @dhcplistener_ints ) {
            util_safe_push( "-i $tint -p udp -m udp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: DHCP Listener Ints are not set.");
    }

    if ( @inline_enforcement_nets ) {
        $chains->{name} = $service_name;
        foreach my $network ( @inline_enforcement_nets ) {
            my $tint =  $network->{Tint};
            util_safe_push( "-i $tint -p udp -m udp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: Inline Enforcement Nets are not set.");
    }

    if ( @vlan_enforcement_nets ) {
        $chains->{name} = $service_name;
        foreach my $network ( @vlan_enforcement_nets ) {
            my $tint =  $network->{Tint};
            util_safe_push( "-i $tint -p udp -m udp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: Vlan Enforcement Nets are not set.");
    }

    if ( @internal_nets ) {
        $chains->{name} = $service_name;
        my $internal_portal_ip = $Config{captive_portal}{ip_address};
        foreach my $interface ( @internal_nets ) {
            my $tint = $interface->tag("int");
            my $ip = $interface->tag("vip") || $interface->tag("ip");
            my $enforcement_type = $Config{"interface $tint"}{'enforcement'};

            if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
                if ($tint =~ m/(\w+):\d+/) {
                    $tint = $1;
                }
                my ($type,$chain) = get_network_type_and_chain($ip);
                if ( $type eq $pf::config::NET_TYPE_VLAN_REG && $chain eq "input-internal-isol_vlan-if" ) {
                    if ( $interface->tag("vip") ){
                        my $vip = $interface->tag("vip");
                        util_safe_push( "-i $tint -d $vip -p tcp -m tcp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                        util_safe_push( "-i $tint -d $vip -p udp -m udp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                    }
                    if ( $interface->tag('ip') ){
                        my $tip = $interface->tag('ip');
                        util_safe_push( "-i $tint -d $tip -p tcp -m tcp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                        util_safe_push( "-i $tint -d $tip -p udp -m udp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                    }
                    util_safe_push( "-i $tint -d $internal_portal_ip -p tcp -m tcp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                    util_safe_push( "-i $tint -d $internal_portal_ip -p udp -m udp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                    if ($cluster_enabled) {
                        my $cluster_ip = $ConfigCluster{$CLUSTER}->{"interface $tint"}->{ip};
                        util_safe_push( "-i $tint -d $cluster_ip -p tcp -m tcp --dport 647 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                        util_safe_push( "-i $tint -d $cluster_ip -p udp -m udp --dport 647 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                    }
                    util_safe_push( "-i $tint -d 255.255.255.255 -p tcp -m tcp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                    util_safe_push( "-i $tint -d 255.255.255.255 -p udp -m udp --dport 67 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                }
            } elsif (is_type_inline($enforcement_type)) {
                if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
                    $logger->info("Adding Proxy interception rules");
                    my $cluster_ip = $ConfigCluster{$CLUSTER}->{"interface $tint"}->{ip};
                    foreach my $intercept_port ( split(',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
                        util_safe_push( "-i $tint -d $cluster_ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                        util_safe_push( "-i $tint -d $cluster_ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                        util_safe_push( "-i $tint -d $cluster_ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_REG   -j DROP", $chains->{'filter'}{'INPUT'} );
                        util_safe_push( "-i $tint -d $ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                        util_safe_push( "-i $tint -d $ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                        util_safe_push( "-i $tint -d $ip -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_REG   -j DROP", $chains->{'filter'}{'INPUT'} );
                        util_safe_push( "-i $tint -d 255.255.255.255 -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                        util_safe_push( "-i $tint -d 255.255.255.255 -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_UNREG -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                        util_safe_push( "-i $tint -d 255.255.255.255 -p tcp -m tcp --dport $intercept_port -m mark -m 0x$IPTABLES_MARK_REG   -j DROP", $chains->{'filter'}{'INPUT'} );
                    }
                }
            }
        }
    }
    if ($chains->{name} ne "") {
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_netdata_rules

Iptable rules for netdata service

=cut

sub iptables_netdata_rules {
    my $service_name = "netdata_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        util_safe_push( "-i $tint -p tcp -m tcp -s 127.0.0.1 --dport 19999 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        if ($cluster_enabled) {
            push my @mgmt_backend, map { $_->{management_ip} } pf::cluster::config_enabled_servers();
            foreach my $mgmt_back (uniq(@mgmt_backend)) {
                util_safe_push( "-i $tint -p tcp -m tcp -s $mgmt_back --dport 19999 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            }
        }
        util_safe_push( "-i $tint -p tcp -m tcp --dport 19999 -j DROP", $chains->{'filter'}{'INPUT'} );
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_pfconnector_server_rules

Iptable rules for pfconnector server service

=cut

sub iptables_pfconnector_server_rules {
    my $service_name = "pfconnector_server_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        my @pfconnector_ips = ("127.0.0.1");
        push @pfconnector_ips, (map { $_->{management_ip} } pf::cluster::config_enabled_servers()) if ($cluster_enabled);
        push @pfconnector_ips, $management_network->{Tip};
        @pfconnector_ips = uniq sort @pfconnector_ips;
        for my $ip (@pfconnector_ips) {
            util_safe_push( "-i $tint -p tcp -m multiport -s $ip --dports 23001:23256 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_galera_autofix_rules

Iptable rules for galera autofix server service

=cut

sub iptables_galera_autofix_rules {
    my $service_name = "galera_autofix_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $chains = util_create_chains();
        if ($cluster_enabled) {
            $chains->{name} = $service_name;
            util_safe_push( "-i $tint -p udp -m udp --dport 4253 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        } else {
            $logger->warn("Service $service_name: Cluster is not enable.");
        }
        if ( @dhcplistener_ints ) {
            $chains->{name} = $service_name;
            foreach my $tint ( @dhcplistener_ints ) {
                util_safe_push( "-i $tint -p udp -m udp --dport 4253 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            }
        } else {
            $logger->warn("Service $service_name: Dhcplistener Ints is not set.");
        }
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_mariadb_rules

Iptable rules for mariadb server service

=cut

sub iptables_mariadb_rules {
    my $service_name = "mariadb_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        util_safe_push( "-i $tint -p tcp -m tcp --dport 3306 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        if ($cluster_enabled) {
            util_safe_push( "-i $tint -p tcp -m tcp --dport 4444 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 4567 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 4568 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        } else {
            $logger->warn("Service $service_name: Cluster is not enable.");
        }
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_mysql_prob_rules

Iptable rules for mysql prob service

=cut

sub iptables_mysql_prob_rules {
    my $service_name = "mysql_prob_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        util_safe_push( "-i $tint -p tcp -m tcp --dport 3307 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_kafka_rules

Iptables rules for kafka service

=cut

sub iptables_kafka_rules {
    my $service_name = "kafka_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();

    if ( util_management_network_is_set($service_name) ){
        my $tint = $management_network->{Tint};
        my $mgmt_ip = $management_network->tag('vip') // $management_network->tag('ip');
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        util_safe_push( "-i $tint -p tcp -m tcp --dport 9092 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p tcp -m tcp --dport 9093 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p tcp -m tcp --dport 29092 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
        if ( @{$ConfigKafka{iptables}{clients}} ) {
            for my $client (@{$ConfigKafka{iptables}{clients}}) {
                $client =~ s/%mgmtip%/$mgmt_ip/g if $mgmt_ip;
                util_safe_push( "-i $tint -p tcp -m tcp -s $client --dport 9092 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            }
        } else {
            $logger->warn("Service $service_name: No ConfigKafka iptables clients is available.");
        }
        if ( @{$ConfigKafka{iptables}{cluster_ips}} ) {
            for my $ip (@{$ConfigKafka{iptables}{cluster_ips}}) {
                $ip =~ s/%mgmtip%/$mgmt_ip/g if $mgmt_ip;
                util_safe_push( "-i $tint -p tcp -m tcp -s $ip --dport 29092 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                util_safe_push( "-i $tint -p tcp -m tcp -s $ip --dport 9092 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                util_safe_push( "-i $tint -p tcp -m tcp -s $ip --dport 9093 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            }
        } else {
            $logger->warn("Service $service_name: No ConfigKafka iptables cluster_ips is available.");
        }
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

=item iptables_docker_dnat_rules

Iptables rules for docker service

=cut

sub iptables_docker_dnat_rules {
    my $service_name = "docker_dnat_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
       # 100.64.0.0/10 is docker ip range.
       my $mgmt_ip = (defined($management_network->tag('vip'))) ? $management_network->tag('vip') : $management_network->tag('ip');
       my $chains = util_create_chains();
       $chains->{name} = $service_name;
       util_safe_push( "-p udp -s 100.64.0.0/10 -d $mgmt_ip -j DNAT --to 100.64.0.1", $chains->{'nat'}{'PREROUTING'} );
       # Convert to JSON and save to file
       util_create_service_rules($chains);
       $logger->warn("Service $service_name: Management Interface is not set.");
    }
}

=item iptables_fingerbank_collector_rules

Iptable rules for fingerbank collector service

=cut

sub iptables_fingerbank_collector_rules {
    my $service_name = "fingerbank_collector_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    if ( util_management_network_is_set($service_name) ){
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        if (netflow_enabled()) {
            util_safe_push( "-j NETFLOW", $chains->{'filter'}{'FORWARD'} );
        }
        my $tint = $management_network->{Tint};
        util_safe_push( "-i $tint -p udp -m udp --dport 1192 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p udp -m udp --dport 2055 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p tcp -m tcp --dport 4723 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p udp -m udp --dport 6343 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $tint -p udp -m udp --dport 4739 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
        # Add rules for interfaces with radius additional daemon
        foreach my $network ( @radius_ints ) {
            my $tint = $network->{Tint};
            util_safe_push( "-i $tint -p udp -m udp --dport 1192 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p udp -m udp --dport 2055 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 4723 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p udp -m udp --dport 6343 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p udp -m udp --dport 4739 --jump ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    } else {
        $logger->warn("Service $service_name: Management Interface is not set.");
    }
}

=item iptables_radiusd_eduroam_rules

Iptable rules for radiusd eduroam service

=cut

sub iptables_radiusd_eduroam_rules {
    my $service_name = "radiusd_eduroam_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    # eduroam RADIUS virtual-server
    if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
        my $chains = util_create_chains();
        $chains->{name} = $service_name;
        my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
        my $eduroam_listening_port = $eduroam_authentication_source[0]{'auth_listening_port'};    # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        my $eduroam_listening_port_backend = $eduroam_listening_port + 10;
        my $mgnt_zone = $management_network->{Tint};
        util_safe_push( "-i $mgnt_zone -p tcp -m tcp --dport $eduroam_listening_port -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        util_safe_push( "-i $mgnt_zone -p udp -m udp --dport $eduroam_listening_port -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        if ($cluster_enabled) {
            util_safe_push( "-i $mgnt_zone -p tcp -m tcp --dport $eduroam_listening_port_backend -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $mgnt_zone -p udp -m udp --dport $eduroam_listening_port_backend -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
        foreach my $network ( @radius_ints ) {
            my $tint = $network->{Tint};
            util_safe_push( "-i $tint -p tcp -m tcp --dport $eduroam_listening_port -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p udp -m udp --dport $eduroam_listening_port -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            if ($cluster_enabled) {
                util_safe_push( "-i $tint -p tcp -m tcp --dport $eduroam_listening_port_backend -j ACCEPT", $chains->{'filter'}{'INPUT'} );
                util_safe_push( "-i $tint -p udp -m udp --dport $eduroam_listening_port_backend -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            }
        }
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    } else {
        $logger->info( "Service $service_name: Eduroam integration is not configured" );
    }
}

=item iptables_pfipset_rules

Iptable rules for pfipset service
Since this service is a requirement for inline, this part also include inline rules
So related to lib/pf/ipset.pm

=cut

sub iptables_pfipset_rules {
    my $service_name = "pfipset_rules";
    my $action = shift;
    if ( $action eq "REMOVE" ) {
       return util_remove_service_rules($service_name);
    }
    my $logger = get_logger();
    pf::ipset->new()->iptables_generate();
    my $chains = util_create_chains();
    # eduroam RADIUS virtual-server
    if ( @internal_nets ) {
        $chains->{name} = $service_name;
        my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
        my $isolation_passthrough_enabled = isenabled($Config{'fencing'}{'isolation_passthrough'});
        foreach my $interface (@internal_nets) {
            my $tint = $interface->tag("int");
            my $ip = $interface->tag("vip") || $interface->tag("ip");
            my $enforcement_type = $Config{"interface $tint"}{'enforcement'};

            if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
                if ($tint =~ m/(\w+):\d+/) {
                    $tint = $1;
                }
                my ($type,$chain) = get_network_type_and_chain($ip);
                if ( $type eq $pf::config::NET_TYPE_VLAN_REG) {
                    if ( $passthrough_enabled && ( $type eq $pf::config::NET_TYPE_VLAN_REG ) ) {
                        util_safe_push( "-i $tint -m set --match-set pfsession_passthrough dst,dst -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                        util_safe_push( "-o $tint -m set --match-set pfsession_passthrough dst,dst -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                        util_safe_push( "-i $tint -m set --match-set pfsession_passthrough src,src -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                        util_safe_push( "-o $tint -m set --match-set pfsession_passthrough src,src -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                    }
                    if ( $isolation_passthrough_enabled && ( $type eq $pf::config::NET_TYPE_VLAN_ISOL ) ) {
                        util_safe_push( "-i $tint -m set --match-set pfsession_isol_passthrough dst,dst -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                        util_safe_push( "-o $tint -m set --match-set pfsession_isol_passthrough dst,dst -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                        util_safe_push( "-i $tint -m set --match-set pfsession_isol_passthrough src,src -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                        util_safe_push( "-o $tint -m set --match-set pfsession_isol_passthrough src,src -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                    }
                }
            }
        }
    }
    pfipset_provisioning_passthroughs();
    pfipset_inline_rules($service_name, $chains);
    if ($chains->{name} ne "") {
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

sub add_to_pfsession_passthrough {
    my ($host, $port) = @_;
    safe_pf_run(qw(sudo ipset --add pfsession_passthrough), "$host,$port");
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
            add_to_pfsession_passthrough( $enroll_host , $enroll_port );
        }

        foreach my $config (tied(%ConfigProvisioning)->search(type => 'mobileiron')) {
            $logger->info("Adding passthrough for MobileIron");
            # Allow the host for the onboarding of devices
            add_to_pfsession_passthrough( $config->{boarding_host} , $config->{boarding_port} );
            # Allow http communication with the MobileIron server
            add_to_pfsession_passthrough( $config->{boarding_host} , $HTTP_PORT );
            # Allow https communication with the MobileIron server
            add_to_pfsession_passthrough( $config->{boarding_host} , $HTTPS_PORT );
        }

        foreach my $config (tied(%ConfigProvisioning)->search(type => 'opswat')) {
            $logger->info("Adding passthrough for OPSWAT");
            # Allow http communication with the OSPWAT server
            add_to_pfsession_passthrough( $config->{host} , $HTTP_PORT );
            # Allow https communication with the OPSWAT server
            add_to_pfsession_passthrough( $config->{host} , $HTTPS_PORT );
        }

        foreach my $config (tied(%ConfigProvisioning)->search(type => 'sentinelone')) {
            $logger->info("Adding passthrough for SentinelOne");
            # Allow http communication with the SentinelOne server
            add_to_pfsession_passthrough( $config->{host} , $HTTP_PORT );
            # Allow https communication with the SentinelOne server
            add_to_pfsession_passthrough( $config->{host} , $HTTPS_PORT );
        }
        $logger->info("Adding IP based passthrough for connectivitycheck.gstatic.com");
        # Allow the host for the onboarding of devices
        add_to_pfsession_passthrough( "172.217.13.99", $HTTP_PORT);
        add_to_pfsession_passthrough( "172.217.13.99", $HTTPS_PORT);
    }
}

sub pfipset_inline_rules {
    my ($service_name, $chains) = @_;
    inline_nat_back_rules($service_name, $chains);
    # Note: I'm giving references to this guy here so he can directly mess with the tables
    inline_generate_rules($service_name, $chains);
    # NAT
    inline_nat_if_src_rules($service_name, $chains);
    inline_nat_redirect_rules($service_name, $chains);
    # Mangle
    inline_mangle_rules($service_name, $chains);
}

sub inline_nat_back_rules {
    my ($service_name, $chains) = @_;
    my $logger = get_logger();

    # Allow the NAT back inside through the forwarding table if inline is enabled
    if ( is_inline_enforcement_enabled() ) {
        $logger->info("Nat back inline rules to forward is starting.");
        $chains->{name} = $service_name;
        my @values = split( ',' , get_inline_snat_interface() );
        foreach my $tint (@values) {
            foreach my $network ( keys %ConfigNetworks ) {
                next if ( !pf::config::is_network_type_inline($network) );
                my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
                my $nat = $ConfigNetworks{$network}{'nat_enabled'};
                if ( defined ( $nat ) && ( isdisabled($nat) ) ) {
                  util_safe_push( "-d $network/$inline_obj->{BITS} -i $tint -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                }
            }
            util_safe_push( "-i $tint -m state --state ESTABLISHED,RELATED -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
        }
        if($management_network) {
            my $mgmt_int = $management_network->tag("int");
            util_safe_push( "-i $mgmt_int -m state --state ESTABLISHED,RELATED -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
        } else {
            $logger->info("NO Action taken on nat back inline rules to forwaard for management network.");
        }
        $logger->info("Nat back inline rules to forward are done.");
    } else {
        $logger->info("NO Action taken on nat back inline rules to forward.");
    }
}

sub inline_generate_rules {
    my ($service_name, $chains) = @_;
    my $logger = get_logger();

    if ( is_inline_enforcement_enabled() ) {
        $logger->info("Inline rules are starting.");
        $chains->{name} = $service_name;
        foreach my $network ( keys %ConfigNetworks ) {
            # We skip non-inline networks/interfaces
            next if ( !pf::config::is_network_type_inline($network) );
            # Set the correct gateway if it is an inline Layer 3 network
            my $tint = $NetworkConfig{$network}{'interface'}{'int'};
            my $gateway = $Config{"interface $tint"}{'ip'};

            my $rule = "-p udp --dport 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
            util_safe_push( "-i $tint $rule -m mark --mark 0x$IPTABLES_MARK_UNREG -j DNAT --to $gateway", $chains->{'nat'}{'PREROUTING'} );
            util_safe_push( "-i $tint $rule -m mark --mark 0x$IPTABLES_MARK_ISOLATION -j DNAT --to $gateway", $chains->{'nat'}{'PREROUTING'} );

            if (isenabled($ConfigNetworks{$network}{'split_network'}) && defined($ConfigNetworks{$network}{'reg_network'}) && $ConfigNetworks{$network}{'reg_network'} ne '') {
                $rule = "-p udp --dport 53 -s $ConfigNetworks{$network}{'reg_network'}";
                util_safe_push( "-i $tint $rule -m mark --mark 0x$IPTABLES_MARK_UNREG -j DNAT --to $gateway", $chains->{'nat'}{'PREROUTING'} );
                util_safe_push( "-i $tint $rule -m mark --mark 0x$IPTABLES_MARK_ISOLATION -j DNAT --to $gateway", $chains->{'nat'}{'PREROUTING'} );
            }

            if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
                $logger->info("Adding Proxy interception rules");
                foreach my $intercept_port ( split(',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
                    my $rule = "-p tcp --dport $intercept_port -s $network/$ConfigNetworks{$network}{'netmask'}";
                    util_safe_push( "-i $tint $rule -m mark --mark 0x$IPTABLES_MARK_UNREG -j DNAT --to $gateway", $chains->{'nat'}{'PREROUTING'} );
                    util_safe_push( "-i $tint $rule -m mark --mark 0x$IPTABLES_MARK_ISOLATION -j DNAT --to $gateway", $chains->{'nat'}{'PREROUTING'} );
                }
            }
        }

        $logger->info("building firewall to accept registered users through inline interface");
        my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
        foreach my $network ( keys %ConfigNetworks ) {
            # We skip non-inline networks/interfaces
            next if ( !pf::config::is_network_type_inline($network) );
            # Set the correct gateway if it is an inline Layer 3 network
            my $tint = $NetworkConfig{$network}{'interface'}{'int'};
            if ($passthrough_enabled) {
                util_safe_push( "-i $tint -m mark --mark 0x$IPTABLES_MARK_UNREG -m set --match-set pfsession_passthrough dst,dst -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
                util_safe_push( "-i $tint -m mark --mark 0x$IPTABLES_MARK_ISOLATION -m set --match-set pfsession_isol_passthrough dst,dst -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
            }
            util_safe_push( "-i $tint -m mark --mark 0x$IPTABLES_MARK_REG -j ACCEPT", $chains->{'filter'}{'FORWARD'} );
        }
        $logger->info("Inline rules are done.");
    } else {
        $logger->info("NO Action taken on DNS DNAT rules for unregistered and isolated inline clients.");
    }
}

sub inline_nat_if_src_rules {
    my ($service_name, $chains) = @_;
    my $logger = get_logger();

    if ( is_inline_enforcement_enabled() ) {
        $logger->info("Inline if src rules are starting for NAT.");
        $chains->{name} = $service_name;
        # internal interfaces handling
        foreach my $interface (@internal_nets) {
            my $tint = $interface->tag("int");
            my $enforcement_type = $Config{"interface $tint"}{'enforcement'};

            # inline enforcement
            if (is_type_inline($enforcement_type)) {
                # send everything from inline interfaces to the inline chain
                util_safe_push( "-o $tint -j MASQUERADE", $chains->{'nat'}{'POSTROUTING'} );
            }
        }

        # NAT POSTROUTING
        # Every marked packet should be NATed
        # Note that here we don't wonder if they should be allowed or not. This is a filtering step done in FORWARD.
        foreach ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
            my @values = split(',', get_inline_snat_interface());
            foreach my $tint (@values) {
                foreach my $network ( keys %ConfigNetworks ) {
                    next if ( !pf::config::is_network_type_inline($network) );
                    my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
                    my $nat = $ConfigNetworks{$network}{'nat_enabled'};
                    if (defined ($nat) && (isdisabled($nat))) {
                        util_safe_push( "-s $network/$inline_obj->{BITS} -o $tint -m mark --mark 0x$_ -j ACCEPT", $chains->{'nat'}{'POSTROUTING'} );
                    }
                }
                util_safe_push( "-o $tint -m mark --mark 0x$_ -j MASQUERADE", $chains->{'nat'}{'POSTROUTING'} );
            }
            my $mgmt_int = $management_network->tag("int");
            util_safe_push( "-o $mgmt_int -m mark --mark 0x$_ -j MASQUERADE", $chains->{'nat'}{'POSTROUTING'} );
        }
        $logger->info("Inline if src rules are done for NAT.");
    } else {
        $logger->info("NO Action taken on inline clients for table NAT.");
    }
}

sub inline_mangle_rules {
    my ($service_name, $chains) = @_;
    my $logger = get_logger();

    if ( is_inline_enforcement_enabled() ) {
        $logger->info("Mangle rules are starting.");
        $chains->{name} = $service_name;
        # pfdhcplistener in most cases will be enforcing access
        # however we insert these marks on startup in case PacketFence is restarted
        # default catch all: mark unreg
        foreach my $network ( keys %ConfigNetworks ) {
            next if ( !pf::config::is_network_type_inline($network) );
            my $tint = $NetworkConfig{$network}{'interface'}{'int'};
            util_safe_push( "-i $tint -j MARK --set-mark 0x$IPTABLES_MARK_UNREG", $chains->{'mangle'}{'PREROUTING'} );
            foreach my $IPTABLES_MARK ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
                my $rule = "";
                if ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE_L3$/i) {
                    $rule = " -m set --match-set pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network src ";
                } else {
                    $rule .= " -m set --match-set pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network src,src ";
                }
                $rule .= "-j MARK --set-mark 0x$IPTABLES_MARK";
                util_safe_push( "-i $tint $rule", $chains->{'mangle'}{'PREROUTING'} );
            }
            util_safe_push( "-o $tint -j ACCEPT", $chains->{'mangle'}{'POSTROUTING'} );
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
        $logger->info("Mangle rules are done.");
    } else {
        $logger->info("NO Inline Action taken on mangle rules.");
    }

    my @values = split(',', get_inline_snat_interface());
    if ( @values ) {
        $logger->info("Mangle rules inline snat interface starts.");
        $chains->{name} = $service_name;
        foreach my $tint (@values) {
            util_safe_push( "-o $tint -j ACCEPT", $chains->{'mangle'}{'POSTROUTING'} );
        }
        $logger->info("Mangle rules inline snat interface are done.");
    }
}

sub inline_nat_redirect_rules {
    my ($service_name, $chains) = @_;
    my $logger = get_logger();
    if ( is_inline_enforcement_enabled() ) {
        $logger->info("Nat redirect rules are starting.");
        $chains->{name} = $service_name;
        my $rule = '';

        # Exclude the OAuth from the DNAT
        my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
        foreach my $network ( keys %ConfigNetworks ) {
            next if ( !pf::config::is_network_type_inline($network) );
            my $tint = $NetworkConfig{$network}{'interface'}{'int'};
            if ($passthrough_enabled) {
                $rule = " -m set --match-set pfsession_passthrough dst,dst -m mark --mark 0x$IPTABLES_MARK_UNREG -j ACCEPT";
                util_safe_push( "-i $tint $rule", $chains->{'nat'}{'PREROUTING'} );
                $rule = " -m set --match-set pfsession_isol_passthrough dst,dst -m mark --mark 0x$IPTABLES_MARK_ISOLATION -j ACCEPT";
                util_safe_push( "-i $tint $rule", $chains->{'nat'}{'PREROUTING'} );
            }
        }
        # Now, do your magic
        foreach my $redirectport ( split( /\s*,\s*/, $Config{'inline'}{'ports_redirect'} ) ) {
            my ( $port, $protocol ) = split( "/", $redirectport );
            foreach my $network ( keys %ConfigNetworks ) {
                # We skip non-inline networks/interfaces
                next if ( !pf::config::is_network_type_inline($network) );
                # Set the correct gateway if it is an inline Layer 3 network
                my $tint = $NetworkConfig{$network}{'interface'}{'int'};
                my $gateway = $Config{"interface $tint"}{'ip'};

                # Destination NAT to the portal on the ISOLATION mark
                $rule =
                " -p $protocol --dport $port -s $network/$ConfigNetworks{$network}{'netmask'} " .
                " -m mark --mark 0x$IPTABLES_MARK_ISOLATION -j DNAT --to $gateway";
                util_safe_push( "-i $tint $rule", $chains->{'nat'}{'PREROUTING'} );
            }
        }
        $logger->info("Nat redirect rules are done.");
    } else {
        $logger->info("NO Action taken nat redirect rules.");
    }
}

=item get_inline_snat_interface

Return the list of network interface to enable SNAT.

=cut

sub get_inline_snat_interface {
    my ($self) = @_;
    my $logger = get_logger();
    if (defined ($Config{'inline'}{'interfaceSNAT'}) && $Config{'inline'}{'interfaceSNAT'} ne '') {
        return $Config{'inline'}{'interfaceSNAT'};
    } else {
        return $management_network->tag("int");
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
    } else {
        $logger->warn("Nothing in config for network interfaceSNAT");
    }
}

=item get_network_type_and_chain

iptables return vlan type and related chain according to node ip

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

###################
# UTILS
###################

=item util_getServiveState

Get state of services

=cut

sub util_getServiveState {
    my ($services, $props) = @_;
    return [] if @$services == 0;
    my @args = ((map { ('-p' => $_) } @$props), @$services);
    my $pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym, 'sudo', 'systemctl', 'show', @args);
    waitpid( $pid, 0 );
    my $child_exit_status = $? >> 8;
    my $out = do {
        local $/ = undef;
        <$chld_out>
    };
    close($chld_in);
    close($chld_out);
    close($chld_err);

    my @states;
    my $state = {};
    for my $line (split '\n', $out) {
        if ($line eq '') {
            push @states, $state;
            $state = {};
            next;
        }

        my ($k, $v) = split('=', $line, 2);
        $state->{$k} = $v;
    }

    push @states, $state;
    return \@states;
}

=item util_create_chains

Create default iptables chain

=cut

sub util_create_chains {
    my %chains = (
        'name'   => "",
        'filter' => { 'INPUT' => [], 'FORWARD' => [], 'OUTPUT' => [] },
        'mangle' => { 'PREROUTING'=> [], 'INPUT' => [], 'FORWARD' => [], 'OUTPUT' => [], 'POSTROUTING' => [] },
        'nat'    => { 'PREROUTING' => [], 'OUTPUT' => [], 'POSTROUTING' => [] }
    );
    return \%chains;
}

=item util_safe_push

Add value only if not other equal value are in array

=cut

sub util_safe_push {
    my ($value, $array_ref) = @_;
    my $logger = get_logger();

    if (defined $array_ref && reftype($array_ref) eq 'ARRAY') {
        my $normalized_value = _normalize_rule($value);

        foreach my $item (@$array_ref) {
            return if _normalize_rule($item) eq $normalized_value;
        }
        push @$array_ref, $value;
    } else {
        $logger->warn("Debug \$array_ref: \n" . Dumper($array_ref) . "\n\nand the value is \n". Dumper($value));
    }
}

sub _normalize_rule {
    my $rule = shift;
    $rule =~ s/\s*,\s*/,/g;
    $rule =~ s/\s+/ /g;
    $rule =~ s/^\s+|\s+$//g;
    return $rule;
}

=item util_create_service_rules

Save Chains Hash to JSON file

=cut

# Function definition
sub util_create_service_rules {
    my $chains_ref = shift;
    my $logger = get_logger();

    # Convert to JSON with pretty formatting
    my $json = JSON->new->pretty->canonical->encode($chains_ref);

    # Add .json extension if not present
    my $filename = $generated_iptables_conf_dir."/".$chains_ref->{'name'}.'.json';

    # Create directory if it doesn't exist
    unless (-d $generated_iptables_conf_dir) {
        make_path($generated_iptables_conf_dir) or die $logger->error("Could not create directory $generated_iptables_conf_dir: $!");
    }

    # Write to file
    open(my $fh, '>', $filename) or die $logger->error("Could not open $filename: $!");
    print $fh $json;
    close($fh);

    # Verify file was created
    unless (-e $filename) {
        die $logger->error("Failed to create JSON file $filename");
    }
    util_generated_iptables_fix_dir_permissions();
    $logger->info("Successfully saved chains to $filename");
}

=item return util_remove_service_rules

Remove service rules JSON file

=cut

sub util_remove_service_rules {
    my $service_name = shift;
    my $logger = get_logger();

    # Add .json extension if not present
    my $filename = $generated_iptables_conf_dir."/".$service_name.'.json';
    if (-e $filename) {
        if (unlink $filename) {
            $logger->info("Successfully removed $filename");
            return 1;
        } else {
            $logger->error("Error removing $filename: $!");
            return 0;
        }
    } else {
        $logger->warn("$filename does not exist");
        return 0;
    }
}

=item util_is_management_network_set

Function to check if management interface is set

=cut

sub util_management_network_is_set {
    my ( $service_name ) = @_ ;
    my $logger = get_logger();
    if (! ref($management_network) || ! exists $management_network->{Tint} || $management_network->{Tint} eq "" ) {
        $logger->warn("Service $service_name: Management Interface is not set.");
        return 0;
    }
    return 1;
}

=item util_add_custom_config_from_file

Function to load and validate custom config from file

=cut

sub util_add_custom_config_from_file {
    my ( $file , $configs_ref ) = @_;
    my $logger = get_logger();

    return 0 unless -e $file;

    my %empty_hash;
    try {
        my $filename = fileparse($file);
        my $json_content = read_file($file);
        my $custom_config = decode_json($json_content);
        
        $custom_config->{'name'}=$filename;

        my %allowed_structure = (
            filter => { INPUT => 1, FORWARD => 1, OUTPUT => 1 },
            mangle => { PREROUTING => 1, INPUT => 1, FORWARD => 1, OUTPUT => 1, POSTROUTING => 1 },
            nat => { PREROUTING => 1, OUTPUT => 1, POSTROUTING => 1 }
        );

        my $has_rules = 0;
        foreach my $table (keys %$custom_config) {
            next if $table eq 'name';
            
            unless (exists $allowed_structure{$table}) {
                printf ("Invalid table '$table' in $filename");
                $logger->warn("Invalid table '$table' in $filename");
                return \%empty_hash;
            }
            
            foreach my $chain (keys %{$custom_config->{$table}}) {
                unless (exists $allowed_structure{$table}{$chain}) {
                    $logger->warn("Invalid chain '$chain' in table '$table' in $filename");
                    return \%empty_hash;
                }
                $has_rules = 1 if @{$custom_config->{$table}{$chain}};
            }
        }
        
        if ($has_rules) {
            $logger->info("Rules available  in $file");
            return $custom_config;
        } else {
            $logger->warn("No rules available in $file");
        }
        
        $logger->warn("Config in $filename contains no rules");
        return \%empty_hash;
    } catch {
        my $error = shift;
        $logger->warn("Failed to process $file: $error");
        return \%empty_hash;
    };
}

=item util_generated_iptables_fix_dir_permissions

Fix generated_iptables_conf_dir permissions

=cut

sub util_generated_iptables_fix_dir_permissions {
    safe_pf_run('sudo', 'chmod', '02770', "$generated_iptables_conf_dir");
    safe_pf_run('sudo', 'chown', 'root:pf', '-R', "$generated_iptables_conf_dir");
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2025 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.

=cut

1;
