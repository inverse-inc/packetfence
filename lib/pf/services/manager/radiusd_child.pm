package pf::services::manager::radiusd_child;

=head1 NAME

pf::services::manager::radiusd_child

=cut

=head1 DESCRIPTION

pf::services::manager::radiusd_child

Used to create the childs of the submanager radiusd
The first manager will create the config for all radiusd processes through the global variable.

=cut

use strict;
use warnings;

use List::MoreUtils qw(any);
use Moo;
use NetAddr::IP;
use Template;

use pfconfig::cached_array;
use pf::authentication;
use pf::cluster;
use pf::util;

use IPC::Cmd qw[can_run];
use pf::file_paths qw(
    $conf_dir
    $install_dir
    $var_dir
);

use pf::config qw(
    %Config
    $management_network
    %ConfigDomain
    $local_secret
    @listen_ints
    %ConfigNetworks
    @dhcplistener_ints
);

tie my @cli_switches, 'pfconfig::cached_array', 'resource::cli_switches';

use NetAddr::IP;
use pf::cluster;
use pf::dhcpd qw (freeradius_populate_dhcpd_config);

extends 'pf::services::manager';

has options => (is => 'rw');

our $CONFIG_GENERATED = 0;

=head2 generateConfig

Generate the configuration for ALL radiusd childs
Executed once for ALL processes

=cut

sub generateConfig {
    my ($self, $quick) = @_;

    unless($CONFIG_GENERATED){
        $self->_generateConfig();

        $CONFIG_GENERATED = 1;
    }
}

=head2 _generateConfig

Generate the configuration files for radiusd processes

=cut

sub _generateConfig {
    my ($self,$quick) = @_;
    my $tt = Template->new(ABSOLUTE => 1);
    $self->generate_radiusd_mainconf();
    $self->generate_radiusd_authconf();
    $self->generate_radiusd_acctconf();
    $self->generate_radiusd_eapconf($tt);
    $self->generate_radiusd_restconf();
    $self->generate_radiusd_sqlconf();
    $self->generate_radiusd_sitesconf();
    $self->generate_radiusd_proxy();
    $self->generate_radiusd_cluster();
    $self->generate_radiusd_cliconf();
    $self->generate_radiusd_eduroamconf();
    $self->generate_radiusd_dhcpd();
}


=head2 generate_radiusd_sitesconf
Generates the packetfence and packetfence-tunnel configuration file
=cut

sub generate_radiusd_sitesconf {
    my %tags;

    if(isenabled($Config{advanced}{record_accounting_in_sql})){
        $tags{'accounting_sql'} = "sql";
    }
    else {
        $tags{'accounting_sql'} = "# sql not activated because explicitly disabled in pf.conf";
    }

    $tags{'template'}    = "$conf_dir/raddb/sites-enabled/packetfence";
    parse_template( \%tags, "$conf_dir/radiusd/packetfence", "$install_dir/raddb/sites-enabled/packetfence" );

    %tags = ();

    if(isenabled($Config{advanced}{disable_pf_domain_auth})){
        $tags{'multi_domain'} = '# packetfence-multi-domain not activated because explicitly disabled in pf.conf';
    }
    elsif(keys %ConfigDomain){
        $tags{'multi_domain'} = 'packetfence-multi-domain';
    }
    else {
        $tags{'multi_domain'} = '# packetfence-multi-domain not activated because no domains configured';
    }

    if(isenabled($Config{advanced}{ntlm_redis_cache})) {
        my $username_prefix = "NTHASH:%{%{PacketFence-Domain}:-''}";
        $tags{'redis_ntlm_cache_fetch'} = <<EOT
if(User-Name =~ /^host\\//) {
    update {
        &control:NT-Password := "%{redis_ntlm:GET $username_prefix:%{tolower:%{%{mschap:User-Name}:-None}}}"
    }
}
else {
    update {
        &control:NT-Password := "%{redis_ntlm:GET $username_prefix:%{tolower:%{%{Stripped-User-Name}:-%{%{User-Name}:-None}}}}"
    }
}
EOT
    }
    else {
        $tags{'redis_ntlm_cache_fetch'} = "# redis-ntlm-cache disabled in configuration"
    }

    $tags{'template'}    = "$conf_dir/raddb/sites-enabled/packetfence-tunnel";
    parse_template( \%tags, "$conf_dir/radiusd/packetfence-tunnel", "$install_dir/raddb/sites-enabled/packetfence-tunnel" );

    # Eduroam configuration
    %tags = ();
    if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
        $tags{'template'} = "$conf_dir/raddb/sites-available/eduroam";
        parse_template( \%tags, "$conf_dir/radiusd/eduroam", "$install_dir/raddb/sites-available/eduroam" );
        symlink("$install_dir/raddb/sites-available/eduroam", "$install_dir/raddb/sites-enabled/eduroam")
    } else {
        unlink("$install_dir/raddb/sites-enabled/eduroam");
        unlink("$install_dir/raddb/sites-available/eduroam");
    }

    %tags = ();
    $tags{'template'}    = "$conf_dir/raddb/sites-enabled/packetfence-cli";
    parse_template( \%tags, "$conf_dir/radiusd/packetfence-cli", "$install_dir/raddb/sites-enabled/packetfence-cli" );

}


=head2 generate_radiusd_mainconf
Generates the radiusd.conf configuration file
=cut

sub generate_radiusd_mainconf {
    my ($self) = @_;
    my %tags;

    $tags{'template'}    = "$conf_dir/radiusd/radiusd.conf";
    $tags{'install_dir'} = $install_dir;
    $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    $tags{'arch'} = `uname -m` eq "x86_64" ? "64" : "";
    $tags{'rpc_pass'} = $Config{webservices}{pass} || "''";
    $tags{'rpc_user'} = $Config{webservices}{user} || "''";
    $tags{'rpc_port'} = $Config{webservices}{aaa_port} || "7070";
    $tags{'rpc_host'} = $Config{webservices}{host} || "127.0.0.1";
    $tags{'rpc_proto'} = $Config{webservices}{proto} || "http";

    parse_template( \%tags, "$conf_dir/radiusd/radiusd.conf", "$install_dir/raddb/radiusd.conf" );
}

sub generate_radiusd_restconf {
    my ($self) = @_;
    my %tags;

    $tags{'template'}    = "$conf_dir/radiusd/rest.conf";
    $tags{'install_dir'} = $install_dir;
    $tags{'rpc_pass'} = $Config{webservices}{pass} || "''";
    $tags{'rpc_user'} = $Config{webservices}{user} || "''";
    $tags{'rpc_port'} = $Config{webservices}{aaa_port} || "7070";
    $tags{'rpc_host'} = $Config{webservices}{host} || "127.0.0.1";
    $tags{'rpc_proto'} = $Config{webservices}{proto} || "http";

    parse_template( \%tags, "$conf_dir/radiusd/rest.conf", "$install_dir/raddb/mods-enabled/rest" );
}

sub generate_radiusd_authconf {
    my ($self) = @_;
    my %tags;
    $tags{'template'}    = "$conf_dir/radiusd/auth.conf";
    $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    $tags{'pid_file'} = "$var_dir/run/radiusd.pid";
    $tags{'socket_file'} = "$var_dir/run/radiusd.sock";
    parse_template( \%tags, $tags{template}, "$install_dir/raddb/auth.conf" );
}

sub generate_radiusd_acctconf {
    my ($self) = @_;
    my %tags;
    $tags{'template'}    = "$conf_dir/radiusd/acct.conf";
    $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    $tags{'pid_file'} = "$var_dir/run/radiusd-acct.pid";
    $tags{'socket_file'} = "$var_dir/run/radiusd-acct.sock";
    parse_template( \%tags, $tags{template}, "$install_dir/raddb/acct.conf" );
}

sub generate_radiusd_eduroamconf {
    my ($self) = @_;

    if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
        my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
        my %tags;
        $tags{'template'}    = "$conf_dir/radiusd/eduroam.conf";
        $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
        $tags{'eduroam_auth_listening_port'} = $eduroam_authentication_source[0]{'auth_listening_port'};    # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        $tags{'pid_file'} = "$var_dir/run/radiusd-eduroam.pid";
        $tags{'socket_file'} = "$var_dir/run/radiusd-eduroam.sock";
        parse_template( \%tags, $tags{template}, "$install_dir/raddb/eduroam.conf" );
    } else {
        unlink("$install_dir/raddb/eduroam.conf");
    }
}

sub generate_radiusd_cliconf {
    my ($self) = @_;
    my %tags;
    if (@cli_switches > 0) {
        $tags{'template'}    = "$conf_dir/radiusd/cli.conf";
        $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
        $tags{'pid_file'} = "$var_dir/run/radiusd-cli.pid";
        $tags{'socket_file'} = "$var_dir/run/radiusd-cli.sock";
        parse_template( \%tags, $tags{template}, "$install_dir/raddb/cli.conf" );
    } else {
        my $file = $install_dir."/raddb/cli.conf";
        unlink($file);
    }
}

=head2 generate_radiusd_eapconf
Generates the eap.conf configuration file
=cut

sub generate_radiusd_eapconf {
    my ($self, $tt) = @_;
    my $radius_authentication_methods = $Config{radius_authentication_methods};
    my %vars = (
        install_dir => $install_dir,
        eap_fast_opaque_key => $radius_authentication_methods->{eap_fast_opaque_key},
        eap_fast_authority_identity => $radius_authentication_methods->{eap_fast_authority_identity},
        (map { $_ => 1 } (split ( /\s*,\s*/, $radius_authentication_methods->{eap_authentication_types} // ''))),
    );

    $tt->process("$conf_dir/radiusd/eap.conf", \%vars, "$install_dir/raddb/mods-enabled/eap") or die $tt->error();
}

=head2 generate_radiusd_sqlconf
Generates the sql.conf configuration file
=cut

sub generate_radiusd_sqlconf {
   my %tags;

   $tags{'template'}    = "$conf_dir/radiusd/sql.conf";
   $tags{'install_dir'} = $install_dir;
   $tags{'db_host'} = $Config{'database'}{'host'};
   $tags{'db_port'} = $Config{'database'}{'port'};
   $tags{'db_database'} = $Config{'database'}{'db'};
   $tags{'db_username'} = $Config{'database'}{'user'};
   $tags{'db_password'} = $Config{'database'}{'pass'};
   $tags{'hash_passwords'} = $Config{'advanced'}{'hash_passwords'} eq 'ntlm' ? 'NT-Password' : 'Cleartext-Password';

   parse_template( \%tags, "$conf_dir/radiusd/sql.conf", "$install_dir/raddb/mods-enabled/sql" );
}

=head2 generate_radiusd_proxy
Generates the proxy.conf.inc configuration file
=cut

sub generate_radiusd_proxy {
    my %tags;

    $tags{'template'} = "$conf_dir/radiusd/proxy.conf.inc";
    $tags{'install_dir'} = $install_dir;
    $tags{'config'} = '';

    foreach my $realm ( sort keys %pf::config::ConfigRealm ) {
        my $options = $pf::config::ConfigRealm{$realm}->{'options'} || '';
        $tags{'config'} .= <<"EOT";
realm $realm {
$options
}
EOT
    }

    # Eduroam configuration
    if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
        my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
        my $server1_address = $eduroam_authentication_source[0]{'server1_address'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        my $server2_address = $eduroam_authentication_source[0]{'server2_address'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        my $radius_secret = $eduroam_authentication_source[0]{'radius_secret'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)

        $tags{'eduroam'} = <<"EOT";
# Eduroam integration

realm eduroam {
    auth_pool = eduroam_auth_pool
    nostrip
}
home_server_pool eduroam_auth_pool {
    home_server = eduroam_server1
    home_server = eduroam_server2
}
home_server eduroam_server1 {
    type = auth
    ipaddr = $server1_address
    port = 1812
    secret = '$radius_secret'
}
home_server eduroam_server2 {
    type = auth
    ipaddr = $server2_address
    port = 1812
    secret = '$radius_secret'
}
EOT
    } else {
        $tags{'eduroam'} = "# Eduroam integration is not configured";
    }

    parse_template( \%tags, "$conf_dir/radiusd/proxy.conf.inc", "$install_dir/raddb/proxy.conf.inc" );
}

=head2 generate_radiusd_cluster

Generates the load balancer configuration

=cut

sub generate_radiusd_cluster {
    my ($self) = @_;
    my %tags;

    my $int = $management_network->{'Tint'};
    my $cfg = $Config{"interface $int"};

    $tags{'members'} = '';
    $tags{'config'} ='';
    $tags{'home_server'} ='';

    if ($cluster_enabled) {
        my $cluster_ip = pf::cluster::management_cluster_ip();
        my @radius_backend = values %{pf::cluster::members_ips($int)};

        # RADIUS PacketFence cluster virtual server configuration
        # raddb/sites-available/packetfence-cluster
        $tags{'template'}    = "$conf_dir/radiusd/packetfence-cluster";
        $tags{'virt_ip'} = $cluster_ip;
        my $i = 0;
        foreach my $radius_back (@radius_backend) {
            next if($radius_back eq $management_network->{Tip} && isdisabled($Config{active_active}{auth_on_management}));
            $tags{'members'} .= <<"EOT";
home_server pf$i.cluster {
        type = auth+acct
        ipaddr = $radius_back
        src_ipaddr = $cluster_ip
        port = 1812
        secret = $local_secret
        response_window = 6
        status_check = status-server
        revive_interval = 120
        check_interval = 30
        num_answers_to_alive = 3
}
home_server pf$i.cli.cluster {
        type = auth
        ipaddr = $radius_back
        src_ipaddr = $cluster_ip
        port = 1815
        secret = $local_secret
        response_window = 6
        status_check = status-server
        revive_interval = 120
        check_interval = 30
        num_answers_to_alive = 3
}
EOT
            $tags{'home_server'} .= <<"EOT";
        home_server =  pf$i.cluster
EOT
            $tags{'home_server_cli'} .= <<"EOT";
        home_server =  pf$i.cli.cluster
EOT
            $i++;
        }
        parse_template( \%tags, "$conf_dir/radiusd/packetfence-cluster", "$install_dir/raddb/sites-enabled/packetfence-cluster" );


        # RADIUS eduroam cluster virtual server configuration
        # raddb/sites-available/eduroam-cluster
        if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
            my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
            %tags = ();
            $tags{'template'}    = "$conf_dir/radiusd/eduroam-cluster";
            $tags{'virt_ip'} = $cluster_ip;
            my $listening_port = $eduroam_authentication_source[0]{'auth_listening_port'};
            my $i = 0;
            foreach my $radius_back (@radius_backend) {
                next if($radius_back eq $management_network->{Tip} && isdisabled($Config{active_active}{auth_on_management}));
                $tags{'members'} .= <<"EOT";
home_server eduroam$i.cluster {
        type = auth
        ipaddr = $radius_back
        src_ipaddr = $cluster_ip
        port = $listening_port
        secret = $local_secret
        response_window = 6
        status_check = status-server
        revive_interval = 120
        check_interval = 30
        num_answers_to_alive = 3
}
EOT
                $tags{'home_server'} .= <<"EOT";
        home_server =  eduroam$i.cluster
EOT
                $i++;
            }
            parse_template( \%tags, "$conf_dir/radiusd/eduroam-cluster", "$install_dir/raddb/sites-enabled/eduroam-cluster" );
        } else {
            unlink($install_dir."/raddb/sites-enabled/eduroam-cluster");
        }


        # RADIUS load_balancer instance configuration
        # raddb/load_balancer.conf
        %tags = ();
        $tags{'template'} = "$conf_dir/radiusd/load_balancer.conf";
        $tags{'virt_ip'} = pf::cluster::management_cluster_ip();
        $tags{'pid_file'} = "$var_dir/run/radiusd-load_balancer.pid";
        $tags{'socket_file'} = "$var_dir/run/radiusd-load_balancer.sock";

        # Eduroam integration
        if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
            my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
            my $ipaddr = $tags{'virt_ip'};
            my $listening_port = $eduroam_authentication_source[0]{'auth_listening_port'};
            $tags{'eduroam'} = <<"EOT";
# Eduroam integration

listen {
        ipaddr = $ipaddr
        port = $listening_port
        type = auth
        virtual_server = eduroam.cluster
}
EOT
        } else {
            $tags{'eduroam'} = "# Eduroam integration is not configured";
        }

        parse_template( \%tags, $tags{'template'}, "$install_dir/raddb/load_balancer.conf");

        
        push @radius_backend, $cluster_ip;
        foreach my $radius_back (@radius_backend) {
            $tags{'config'} .= <<"EOT";
client $radius_back {
        secret = $local_secret
        shortname = pf
}
EOT
        }

    } else {
        my $file = $install_dir."/raddb/sites-enabled/packetfence-cluster";
        unlink($file);
    }
    # Ensure raddb/clients.conf.inc exists. radiusd won't start otherwise.
    $tags{'template'} = "$conf_dir/radiusd/clients.conf.inc";
    parse_template( \%tags, "$conf_dir/radiusd/clients.conf.inc", "$install_dir/raddb/clients.conf.inc" );
}

sub generate_radiusd_dhcpd {
    my %tags;
    my %direct_subnets;

    freeradius_populate_dhcpd_config();
    $tags{'template'}    = "$conf_dir/radiusd/dhcpd.conf";
    $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    $tags{'pid_file'} = "$var_dir/run/radiusd-dhcpd.pid";
    $tags{'socket_file'} = "$var_dir/run/radiusd-dhcpd.sock";

    foreach my $interface ( @listen_ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        my $enforcement = $cfg->{'enforcement'};
        my $current_network = NetAddr::IP->new( $cfg->{'ip'}, $cfg->{'mask'} );
            $tags{'listen'} .= <<"EOT";

listen {
	type = dhcp
	ipaddr = 0.0.0.0
	src_ipaddr = $cfg->{'ip'}
	port = 67
	interface = $interface
	broadcast = yes
	virtual_server = dhcp\.$interface
}

EOT

        $tags{'config'} .= <<"EOT";

server dhcp\.$interface {
dhcp DHCP-Discover {
	convert_to_int
	update control {
		Cache-Status-Only = 'yes'
	}
	cache_index
	if (notfound) {
		update {
			&request:Tmp-Integer-2 := "%{%{sql: SELECT idx FROM dhcpd WHERE ip = \'$cfg->{'ip'}\' AND interface = \'$interface\'}:-0}"
			&request:Tmp-Integer-3 := "%{sql: SELECT count(*) FROM dhcpd WHERE interface = \'$interface\'}"
		}
	}
	cache_index
	if ( ( &request:Tmp-Integer-3 == 0 ) || ("%{expr: %{Tmp-Integer-1} %% %{Tmp-Integer-3}}" == "%{Tmp-Integer-2}") || (&request:DHCP-Gateway-IP-Address != 0.0.0.0) ) {
		update reply {
			DHCP-Message-Type = DHCP-Offer
		}

EOT

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};
        if ( $net{'dhcpd'} eq 'enabled' ) {
            my $ip = NetAddr::IP::Lite->new(clean_ip($net{'gateway'}));
            my $current_network2 = NetAddr::IP->new( $net{'gateway'}, $net{'netmask'} );
            if (defined($net{'next_hop'})) {
                $ip = NetAddr::IP::Lite->new(clean_ip($net{'next_hop'}));
             }

             if ($current_network->contains($ip)) {
                 my $network = $current_network2->network();
                 my $prefix = $current_network2->network()->nprefix();
                 my $mask = $current_network2->masklen();
                 $prefix =~ s/\.$//;
                 if (defined($net{'next_hop'})) {
                     $tags{'config'} .= <<"EOT";
		if ( ( (&request:DHCP-Gateway-IP-Address != 0.0.0.0) && (&request:DHCP-Gateway-IP-Address < $prefix/$mask) ) || (&request:DHCP-Client-IP-Address < $prefix/$mask) ) {
EOT
                 } else {
                     $tags{'config'} .= <<"EOT";
		if ( (&request:DHCP-Gateway-IP-Address == 0.0.0.0)  || (&request:DHCP-Client-IP-Address < $prefix/$mask) ) {

EOT
                 }
                 $tags{'config'} .= <<"EOT";


			update {
				&reply:DHCP-Domain-Name-Server = $net{'dns'}
				&reply:DHCP-Subnet-Mask = $net{'netmask'}
				&reply:DHCP-Router-Address = $net{'gateway'}
				&reply:DHCP-IP-Address-Lease-Time = "%{%{sql: SELECT lease_time FROM radippool WHERE callingstationid = '%{request:DHCP-Client-Hardware-Address}'}:-$net{'dhcp_default_lease_time'}}"
				&reply:DHCP-DHCP-Server-Identifier = $cfg->{'ip'}
				&reply:DHCP-Domain-Name = $net{'domain-name'}
				&control:Pool-Name := "$network"
				&request:DHCP-Domain-Name-Server = $net{'dns'}
				&request:DHCP-Subnet-Mask = $net{'netmask'}
				&request:DHCP-Router-Address = $net{'gateway'}
				&request:DHCP-IP-Address-Lease-Time = "%{%{sql: SELECT lease_time FROM radippool WHERE callingstationid = '%{request:DHCP-Client-Hardware-Address}'}:-$net{'dhcp_default_lease_time'}}"
				&request:DHCP-DHCP-Server-Identifier = $cfg->{'ip'}
				&request:DHCP-Domain-Name = $net{'domain-name'}
				&request:DHCP-Site-specific-0 = $enforcement
			}
		}
EOT
            }
        }
    }

 $tags{'config'} .= <<"EOT";
	dhcp_sqlippool
	rest-dhcp
	ok
	}
	else {
		update reply {
			&DHCP-Message-Type = DHCP-Do-Not-Respond
		}
		reject
	}
}

dhcp DHCP-Request {
	convert_to_int
	update control {
		Cache-Status-Only = 'yes'
	}
	cache_index
	if (notfound) {
		update {
			&request:Tmp-Integer-2 := "%{%{sql: SELECT idx FROM dhcpd WHERE ip = \'$cfg->{'ip'}\' AND interface = \'$interface\'}:-0}"
			&request:Tmp-Integer-3 := "%{sql: SELECT count(*) FROM dhcpd WHERE interface = \'$interface\'}"
		}
	}
	cache_index
	if ( ( &request:Tmp-Integer-3 == 0 ) || ("%{expr: %{Tmp-Integer-1} %% %{Tmp-Integer-3}}" == "%{Tmp-Integer-2}") || (&request:DHCP-Gateway-IP-Address != 0.0.0.0) ) {
		update reply {
			&DHCP-Message-Type = DHCP-Ack
		}

EOT

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};
        if ( $net{'dhcpd'} eq 'enabled' ) {
            my $ip = NetAddr::IP::Lite->new(clean_ip($net{'gateway'}));
            my $current_network2 = NetAddr::IP->new( $net{'gateway'}, $net{'netmask'} );
            if (defined($net{'next_hop'})) {
                $ip = NetAddr::IP::Lite->new(clean_ip($net{'next_hop'}));
             }

             if ($current_network->contains($ip)) {
                 my $network = $current_network2->network();
                 my $prefix = $current_network2->network()->nprefix();
                 my $mask = $current_network2->masklen();
                 $prefix =~ s/\.$//;
                 if (defined($net{'next_hop'})) {
                     $tags{'config'} .= <<"EOT";

	if (  ( (&request:DHCP-Gateway-IP-Address != 0.0.0.0) && (&request:DHCP-Gateway-IP-Address < $prefix/$mask) ) || (&request:DHCP-Client-IP-Address < $prefix/$mask) ) {
EOT
                 } else {
                     $tags{'config'} .= <<"EOT";
	if (  (&request:DHCP-Gateway-IP-Address == 0.0.0.0)  || (&request:DHCP-Client-IP-Address < $prefix/$mask) ) {

EOT
                 }
                $tags{'config'} .= <<"EOT";

		update {
			&reply:DHCP-Domain-Name-Server = $net{'dns'}
			&reply:DHCP-Subnet-Mask = $net{'netmask'}
			&reply:DHCP-Router-Address = $net{'gateway'}
			&reply:DHCP-IP-Address-Lease-Time = "%{%{sql: SELECT lease_time FROM radippool WHERE callingstationid = '%{request:DHCP-Client-Hardware-Address}'}:-$net{'dhcp_default_lease_time'}}"
			&reply:DHCP-DHCP-Server-Identifier = $cfg->{'ip'}
			&reply:DHCP-Domain-Name = $net{'domain-name'}
			&control:Pool-Name := "$network"
			&request:DHCP-Domain-Name-Server = $net{'dns'}
			&request:DHCP-Subnet-Mask = $net{'netmask'}
			&request:DHCP-Router-Address = $net{'gateway'}
			&request:DHCP-IP-Address-Lease-Time = "%{%{sql: SELECT lease_time FROM radippool WHERE callingstationid = '%{request:DHCP-Client-Hardware-Address}'}:-$net{'dhcp_default_lease_time'}}"
			&request:DHCP-DHCP-Server-Identifier = $cfg->{'ip'}
			&request:DHCP-Domain-Name = $net{'domain-name'}
			&request:DHCP-Site-specific-0 = $enforcement
		}
	}

EOT
            }
        }
    }

 $tags{'config'} .= <<"EOT";
	dhcp_sqlippool
	rest-dhcp
	ok
	}
	else {
		update reply {
			&DHCP-Message-Type = DHCP-Do-Not-Respond
		}
		reject
	}
}


dhcp DHCP-Decline {
	update reply {
		&DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	reject
}

dhcp DHCP-Inform {
	update reply {
		&DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	reject
}

#
#  For Windows 7 boxes
#
dhcp DHCP-Inform {
	update reply {
		Packet-Dst-Port = 67
		DHCP-Message-Type = DHCP-ACK
		DHCP-DHCP-Server-Identifier = "%{Packet-Dst-IP-Address}"
		DHCP-Site-specific-28 = 0x0a00
	}
	ok
}

dhcp DHCP-Release {

        update reply {
                &DHCP-Message-Type = DHCP-Do-Not-Respond
                &Tmp-Integer-3  = "%{sql: UPDATE radippool SET nasipaddress = '', pool_key = 0, callingstationid = '', username = '', expiry_time = NOW(), lease_time = NULL  WHERE framedipaddress = '%{DHCP-Client-IP-Address}' and callingstationid = '%{DHCP-Client-Hardware-Address}'}"

        }
        reject
}

dhcp DHCP-Lease-Query {
	update {
		&request:Tmp-Cast-Ethernet := "%{%{sql: SELECT interface FROM dhcpd WHERE ip = 'password'}:-0}"
	}


	if (&DHCP-Client-Hardware-Address == &request:Tmp-Cast-Ethernet) {
		update reply {
			&DHCP-Message-Type = DHCP-Lease-Active
			&DHCP-Client-IP-Address = "%{Packet-Src-IP-Address}"
		}
	}
	else {
		update reply {
			&DHCP-Message-Type = DHCP-Do-Not-Respond
		}
		reject
	}

}

}

EOT
        }

# Listener interface to replace pfdhcplistener for ipv4

    foreach my $interface ( @dhcplistener_ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
            $tags{'listen'} .= <<"EOT";

listen {
	type = dhcp
	ipaddr = 0.0.0.0
	src_ipaddr = $cfg->{'ip'}
	port = 67
	interface = $interface
	broadcast = yes
	virtual_server = dhcp\.$interface
}

EOT

        $tags{'config'} .= <<"EOT";

server dhcp\.$interface {
dhcp DHCP-Discover {
	update reply {
		&DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	reject
}

dhcp DHCP-Request {
	update reply {
		&DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	rest-dhcp
}


dhcp DHCP-Decline {
	update reply {
		&DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	reject
}

dhcp DHCP-Inform {
	update reply {
		&DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	reject
}

dhcp DHCP-Release {
	update reply {
		&DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	reject
}

dhcp DHCP-Ack {
	update reply {
		&DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	rest-dhcp
	reject
}

dhcp DHCP-Lease-Query {

	update reply {
		&DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	rest-dhcp
	reject
}

}
EOT
}


    parse_template( \%tags, "$conf_dir/radiusd/packetfence-dhcp", "$install_dir/raddb/sites-enabled/packetfence-dhcp" );
    parse_template( \%tags, $tags{template}, "$install_dir/raddb/dhcpd.conf" );
    return 1;
}


sub preStartSetup {
    my ($self,$quick) = @_;
    $self->SUPER::preStartSetup($quick);
    return 1;
}

sub stop {
    my ($self,$quick) = @_;
    my $result = $self->SUPER::stop($quick);
    return $result;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

