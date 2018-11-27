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

use List::MoreUtils qw(any uniq);
use Moo;
use NetAddr::IP;
use Template;

use pfconfig::cached_array;
use pfconfig::cached_hash;

use pf::authentication;
use pf::cluster;
use pf::util;
use Socket;

use pf::constants qw($TRUE $FALSE);

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
    @radius_ints
    %ConfigAuthenticationLdap
);

tie my @cli_switches, 'pfconfig::cached_array', 'resource::cli_switches';

extends 'pf::services::manager';

has options => (is => 'rw');

sub _build_executable {
    my ($self) = @_;
    require pf::config;
    return $pf::config::Config{'services'}{"radiusd_binary"};
}


sub _cmdLine { 
    my $self = shift;
    $self->executable . " -d $install_dir/raddb";
}

sub _cmdLineArgs {
    my $self = shift;
    return " -n " . $self->options . " -fm ";
}

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
    my $tt = Template->new(
        ABSOLUTE => 1,
        FILTERS  => { escape_string => \&escape_freeradius_string },
    );
    $self->generate_radiusd_mainconf();
    $self->generate_radiusd_authconf($tt);
    $self->generate_radiusd_acctconf($tt);
    $self->generate_radiusd_eapconf($tt);
    $self->generate_radiusd_restconf();
    $self->generate_radiusd_sqlconf();
    $self->generate_radiusd_sitesconf();
    $self->generate_radiusd_proxy();
    $self->generate_radiusd_cluster($tt);
    $self->generate_radiusd_cliconf($tt);
    $self->generate_radiusd_eduroamconf($tt);
    $self->generate_radiusd_ldap($tt);
}


=head2 generate_radiusd_sitesconf
Generates the packetfence and packetfence-tunnel configuration file
=cut

sub generate_radiusd_sitesconf {
    my %tags;

    if(isenabled($Config{radius_configuration}{record_accounting_in_sql})){
        $tags{'accounting_sql'} = "sql";
    }
    else {
        $tags{'accounting_sql'} = "# sql not activated because explicitly disabled in pf.conf";
    }
    if(isenabled($Config{radius_configuration}{filter_in_packetfence_authorize})){
        $tags{'authorize_filter'} = "rest";
    }
    else {
        $tags{'authorize_filter'} = "# filter not activated because explicitly disabled in pf.conf";
    }
    if(isenabled($Config{radius_configuration}{filter_in_packetfence_pre_proxy})){
        $tags{'pre_proxy_filter'} = "rest";
    }
    else {
        $tags{'pre_proxy_filter'} = "# filter not activated because explicitly disabled in pf.conf";
    }
    if(isenabled($Config{radius_configuration}{filter_in_packetfence_post_proxy})){
        $tags{'post_proxy_filter'} = "rest";
    }
    else {
        $tags{'post_proxy_filter'} = "# filter not activated because explicitly disabled in pf.conf";
    }
    if(isenabled($Config{radius_configuration}{filter_in_packetfence_preacct})){
        $tags{'preacct_filter'} = "rest";
    }
    else {
        $tags{'preacct_filter'} = "# filter not activated because explicitly disabled in pf.conf";
    }

    $tags{'local_realm'} = '';
    my @realms;
    foreach my $realm ( sort keys %pf::config::ConfigRealm ) {
        if (isenabled($pf::config::ConfigRealm{$realm}->{'radius_auth_compute_in_pf'})) {
            push (@realms, "Realm == \"$realm\"");
        }
    }
    if (@realms) {
        $tags{'local_realm'} .= 'if ( ';
        $tags{'local_realm'} .=  join(' || ', @realms);
        $tags{'local_realm'} .= ' ) {'."\n";
        $tags{'local_realm'} .= <<"EOT";
    rest
}
EOT
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
    if(isenabled($Config{radius_configuration}{'filter_in_packetfence-tunnel_authorize'})){
        $tags{'authorize_filter'} = "rest";
    }
    else {
        $tags{'authorize_filter'} = "# filter not activated because explicitly disabled in pf.conf";
    }
    if(isenabled($Config{radius_configuration}{ntlm_redis_cache})) {
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

    $tags{'userPrincipalName'} = '';
    my @realms;
    my $flag = $TRUE;
    foreach my $realm ( sort keys %pf::config::ConfigRealm ) {
        if(isenabled($pf::config::ConfigRealm{$realm}->{'permit_custom_attributes'})) {
            if ($flag) {
                $tags{'userPrincipalName'} .= <<"EOT";
        update control {
            Cache-Status-Only = 'yes'
        }
        userprincipalname
        if (notfound) {
EOT
            }
            $flag = $FALSE;
        $tags{'userPrincipalName'} .= <<"EOT";
        if (Realm == \"$realm\" ) {
            $pf::config::ConfigRealm{$realm}->{ldap_source}
        }
EOT
        }
    }
    if ($flag == $FALSE) {
        $tags{'userPrincipalName'} .= <<"EOT";
        }
        userprincipalname
EOT
    }

    $tags{'template'}    = "$conf_dir/raddb/sites-enabled/packetfence-tunnel";
    parse_template( \%tags, "$conf_dir/radiusd/packetfence-tunnel", "$install_dir/raddb/sites-enabled/packetfence-tunnel" );

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
    parse_template( \%tags, "$conf_dir/radiusd/radiusd_loadbalancer.conf", "$install_dir/raddb/radiusd_loadbalancer.conf" );
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
    my ($self, $tt) = @_;
    my %tags;
    my @listen_ips;
    if ($cluster_enabled) {
        my $ip = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
        push @listen_ips, $ip;

    } else {
        foreach my $interface ( uniq(@radius_ints) ) {
            my $ip = defined($interface->tag('vip')) ? $interface->tag('vip') : $interface->tag('ip');
            push @listen_ips, $ip;
        }
    }

    $tags{'listen_ips'} = [uniq @listen_ips];
    $tags{'pid_file'} = "$var_dir/run/radiusd.pid";
    $tags{'socket_file'} = "$var_dir/run/radiusd.sock";
    $tt->process("$conf_dir/radiusd/auth.conf", \%tags, "$install_dir/raddb/auth.conf") or die $tt->error();
}

sub generate_radiusd_acctconf {
    my ($self, $tt) = @_;
    my %tags;
    my @listen_ips;
    if ($cluster_enabled) {
        my $ip = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
        push @listen_ips, $ip;

    } else {
        foreach my $interface ( uniq(@radius_ints) ) {
            my $ip = defined($interface->tag('vip')) ? $interface->tag('vip') : $interface->tag('ip');
            push @listen_ips, $ip;
        }
    }

    $tags{'listen_ips'} = [uniq @listen_ips];
    $tags{'pid_file'} = "$var_dir/run/radiusd-acct.pid";
    $tags{'socket_file'} = "$var_dir/run/radiusd-acct.sock";
    $tt->process("$conf_dir/radiusd/acct.conf", \%tags, "$install_dir/raddb/acct.conf") or die $tt->error();
}

sub generate_radiusd_eduroamconf {
    my ($self) = @_;
    my %tags;
    if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
        my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
        $tags{'template'}    = "$conf_dir/radiusd/eduroam.conf";
        if ($cluster_enabled) {
            my $ip = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
            $tags{'listen'} .= << "EOT";
listen {
    ipaddr = $ip
    port =  $eduroam_authentication_source[0]{'auth_listening_port'}
    type = auth
    virtual_server = eduroam
}

EOT
        } else {
            foreach my $interface ( uniq(@radius_ints) ) {
                my $ip = defined($interface->tag('vip')) ? $interface->tag('vip') : $interface->tag('ip');
                $tags{'listen'} .= <<"EOT";
listen {
    ipaddr = $ip
    port =  $eduroam_authentication_source[0]{'auth_listening_port'}
    type = auth
    virtual_server = eduroam
}

EOT
            }
        }
        $tags{'pid_file'} = "$var_dir/run/radiusd-eduroam.pid";
        $tags{'socket_file'} = "$var_dir/run/radiusd-eduroam.sock";
        parse_template( \%tags, $tags{template}, "$install_dir/raddb/eduroam.conf" );

        # Eduroam configuration
        %tags = ();
        $tags{'template'} = "$conf_dir/raddb/sites-available/eduroam";
        $tags{'local_realm'} = '';
        my @realms;
        foreach my $realm ( @{$eduroam_authentication_source[0]{'local_realm'}} ) {
             push (@realms, "Realm == \"$realm\"");
        }
        if (@realms) {
            $tags{'local_realm'} .= '            if ( ';
            $tags{'local_realm'} .=  join(' || ', @realms);
            $tags{'local_realm'} .= ' ) {'."\n";
            $tags{'local_realm'} .= <<"EOT";
                update control {
                    Proxy-To-Realm := "packetfence"
                }
            } else {
                update control {
                    Proxy-To-Realm := "eduroam"
                }
            }
EOT
        } else {
        $tags{'local_realm'} = << "EOT";
                update control {
                    Proxy-To-Realm := "eduroam"
                }
EOT
        }
        $tags{'reject_realm'} = '';
        my @reject_realms;
        foreach my $reject_realm ( @{$eduroam_authentication_source[0]{'reject_realm'}} ) {
             push (@reject_realms, "Realm == \"$reject_realm\"");
        }
        if (@reject_realms) {
            $tags{'reject_realm'} .= '            if ( ';
            $tags{'reject_realm'} .=  join(' || ', @reject_realms);
            $tags{'reject_realm'} .= ' ) {'."\n";
            $tags{'reject_realm'} .= <<"EOT";
                reject
            }
EOT
        }
        parse_template( \%tags, "$conf_dir/radiusd/eduroam", "$install_dir/raddb/sites-available/eduroam" );
        symlink("$install_dir/raddb/sites-available/eduroam", "$install_dir/raddb/sites-enabled/eduroam");

        %tags = ();
        my $server1_address = $eduroam_authentication_source[0]{'server1_address'};
        my $server2_address = $eduroam_authentication_source[0]{'server2_address'};
        my $radius_secret = $eduroam_authentication_source[0]{'radius_secret'};
        my $virtual_server = "packetfence";
        if ($cluster_enabled) {
            $virtual_server = "pf.cluster";
        }
            $tags{'config'} .= <<"EOT";
client eduroam_tlrs_server_1 {
        ipaddr = $server1_address
        secret = $radius_secret
        shortname = eduroam_tlrs1
        virtual_server = $virtual_server
}

client eduroam_tlrs_server_2 {
        ipaddr = $server2_address
        secret = $radius_secret
        shortname = eduroam_tlrs2
        virtual_server = $virtual_server
}

EOT
    } else {
        $tags{'config'} = "# Eduroam integration is not configured";
        unlink("$install_dir/raddb/sites-enabled/eduroam");
        unlink("$install_dir/raddb/sites-available/eduroam");
        unlink("$install_dir/raddb/eduroam.conf");
    }
    # Ensure raddb/clients.eduroam.conf.inc exists. radiusd won't start otherwise.
    $tags{'template'} = "$conf_dir/radiusd/clients.eduroam.conf.inc";
    parse_template( \%tags, "$conf_dir/radiusd/clients.eduroam.conf.inc", "$install_dir/raddb/clients.eduroam.conf.inc" );
}

sub generate_radiusd_cliconf {
    my ($self) = @_;
    my %tags;
    if (@cli_switches > 0) {
        $tags{'template'}    = "$conf_dir/radiusd/cli.conf";
        if ($cluster_enabled) {
            my $ip = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');

$tags{'listen'} .= <<"EOT";
listen {
        ipaddr = $ip
        port = 1815
        type = auth
        virtual_server = packetfence-cli
}

EOT
        } else {
            foreach my $interface ( uniq(@radius_ints) ) {
                my $ip = defined($interface->tag('vip')) ? $interface->tag('vip') : $interface->tag('ip');
                $tags{'listen'} .= <<"EOT";
listen {
        ipaddr = $ip
        port = 1815
        type = auth
        virtual_server = packetfence-cli
}

EOT
            }
        }
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
    my $radius_configuration = $Config{radius_configuration};
    my %vars = (
        install_dir => $install_dir,
        eap_fast_opaque_key => $radius_configuration->{eap_fast_opaque_key},
        eap_fast_authority_identity => $radius_configuration->{eap_fast_authority_identity},
        (map { $_ => 1 } (split ( /\s*,\s*/, $radius_configuration->{eap_authentication_types} // ''))),
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
   for my $k (qw(db_username db_password)) {
      $tags{$k} = escape_freeradius_string($tags{$k});
   }

    parse_template( \%tags, "$conf_dir/radiusd/sql.conf", "$install_dir/raddb/mods-enabled/sql" );
}

=head2 escape_freeradius_string

escape_freeradius_string

=cut

sub escape_freeradius_string {
    my ($s) = @_;
    $s =~ s/"/\\"/g;
    return $s;
}

=head2 generate_radiusd_ldap

Generates the ldap_packetfence configuration file

=cut

sub generate_radiusd_ldap {
    my ($self, $tt) = @_;

    my %tags;
    $tags{'template'}    = "$conf_dir/radiusd/ldap_packetfence.conf";
    $tags{'install_dir'} = $install_dir;
    foreach my $ldap (keys %ConfigAuthenticationLdap) {
        my $searchattributes;
        foreach my $searchattribute (@{$ConfigAuthenticationLdap{$ldap}->{searchattributes}}) {
            $searchattributes .= '('.$searchattribute.'=%{User-Name})';
        }

        $tags{'servers'} .= <<"EOT";

ldap $ldap {
    server          = "$ConfigAuthenticationLdap{$ldap}->{host}"
    port            = "$ConfigAuthenticationLdap{$ldap}->{port}"
    identity        = "$ConfigAuthenticationLdap{$ldap}->{binddn}"
    password        = "$ConfigAuthenticationLdap{$ldap}->{password}"
    base_dn         = "$ConfigAuthenticationLdap{$ldap}->{basedn}"
    filter          = "(userPrincipalName=%{User-Name})"
    scope           = $ConfigAuthenticationLdap{$ldap}->{scope}
    base_filter     = "(objectclass=user)"
    rebind          = yes
    chase_referrals = yes
    update {
        control:AD-Samaccountname := 'sAMAccountName'
    }
    user {
        base_dn = "\${..base_dn}"
        filter = "(|$searchattributes(sAMAccountName=%{%{Stripped-User-Name}:-%{User-Name}}))"
    }
    options {
        chase_referrals = yes
        rebind = yes
    }
EOT
        if ($ConfigAuthenticationLdap{$ldap}->{encryption} eq "ldaps") {
            $tags{'servers'} .= <<"EOT";
    tls {
        start_tls = no
    }
EOT
        } elsif ($ConfigAuthenticationLdap{$ldap}->{encryption} eq "starttls") {
            $tags{'servers'} .= <<"EOT";
    tls {
        start_tls = yes
    }
EOT
        }
            $tags{'servers'} .= <<"EOT";
}

EOT

    }

    parse_template( \%tags, "$conf_dir/radiusd/ldap_packetfence.conf", "$install_dir/raddb/mods-enabled/ldap_packetfence" );
}

=head2 generate_radiusd_proxy

Generates the proxy.conf.inc configuration file

=cut

sub generate_radiusd_proxy {
    my %tags;

    $tags{'template'} = "$conf_dir/radiusd/proxy.conf.inc";
    $tags{'install_dir'} = $install_dir;
    $tags{'config'} = '';
    $tags{'radius_sources'} = '';
    my @radius_sources;

    foreach my $realm ( sort keys %pf::config::ConfigRealm ) {
        my $options = $pf::config::ConfigRealm{$realm}->{'options'} || '';
        $tags{'config'} .= <<"EOT";
realm $realm {
$options
EOT
        if ($pf::config::ConfigRealm{$realm}->{'radius_auth'} ) {
            $tags{'config'} .= <<"EOT";
auth_pool = auth_pool_$realm
EOT
        }
        if ($pf::config::ConfigRealm{$realm}->{'radius_acct'}) {
            $tags{'config'} .= <<"EOT";
acct_pool = acct_pool_$realm
EOT
        }
        if($pf::config::ConfigRealm{$realm}->{'radius_auth'} || $pf::config::ConfigRealm{$realm}->{'radius_acct'}) {
            $tags{'config'} .= <<"EOT";
}
EOT
        }
        if ($pf::config::ConfigRealm{$realm}->{'radius_auth'} ) {
            $tags{'config'} .= <<"EOT";
home_server_pool auth_pool_$realm {
type = $pf::config::ConfigRealm{$realm}->{'radius_auth_proxy_type'}
EOT
            push(@radius_sources, split(',',$pf::config::ConfigRealm{$realm}->{'radius_auth'}));
            foreach my $radius (split(',',$pf::config::ConfigRealm{$realm}->{'radius_auth'})) {

                $tags{'config'} .= <<"EOT";
home_server = $radius
EOT
            }
            $tags{'config'} .= <<"EOT";
}
EOT
        }
        if ($pf::config::ConfigRealm{$realm}->{'radius_acct'}) {
            $tags{'config'} .= <<"EOT";

home_server_pool acct_pool_$realm {
type = $pf::config::ConfigRealm{$realm}->{'radius_acct_proxy_type'}
EOT
            push(@radius_sources,split(',',$pf::config::ConfigRealm{$realm}->{'radius_acct'}));
            foreach my $radius (split(',',$pf::config::ConfigRealm{$realm}->{'radius_acct'})) {

                $tags{'config'} .= <<"EOT";
home_server = $radius
EOT
            }
            $tags{'config'} .= <<"EOT";
}
EOT
        }
         if(!$pf::config::ConfigRealm{$realm}->{'radius_auth'} && !$pf::config::ConfigRealm{$realm}->{'radius_acct'}) {
            $tags{'config'} .= <<"EOT";
}
EOT
        }
    }
    foreach my $radius (uniq @radius_sources) {
        my $source = pf::authentication::getAuthenticationSource($radius);
        my @addresses = gethostbyname($source->{'host'});
        my @ips = map { inet_ntoa($_) } @addresses[4 .. $#addresses];
        my $src_ip = pf::util::find_outgoing_srcip($ips[0]);
        $source->{'options'} =~ s/\$src_ip/$src_ip/;
        $tags{'radius_sources'} .= <<"EOT";

home_server $radius {
ipaddr = $source->{'host'}
port = $source->{'port'}
secret = $source->{'secret'}
$source->{'options'}
}

EOT
    }
    # Eduroam configuration
    if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
        my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
        my $server1_address = $eduroam_authentication_source[0]{'server1_address'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        my $server1_port = $eduroam_authentication_source[0]{'server1_port'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        my $server2_address = $eduroam_authentication_source[0]{'server2_address'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        my $server2_port = $eduroam_authentication_source[0]{'server2_port'};   # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
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
    port = $server1_port
    secret = '$radius_secret'
}
home_server eduroam_server2 {
    type = auth
    ipaddr = $server2_address
    port = $server2_port
    secret = '$radius_secret'
}
EOT
    } else {
        $tags{'eduroam'} = "# Eduroam integration is not configured";
    }

    parse_template( \%tags, "$conf_dir/radiusd/proxy.conf.inc", "$install_dir/raddb/proxy.conf.inc" );

    undef %tags;

    foreach my $realm ( sort keys %pf::config::ConfigRealm ) {
        $tags{'config'} .= <<"EOT";
realm $realm {
nostrip
}
EOT
    }
    parse_template( \%tags, "$conf_dir/radiusd/proxy.conf.loadbalancer", "$install_dir/raddb/proxy.conf.loadbalancer" );
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
            $tags{'local_realm'} = '';
            my @realms;
            foreach my $realm ( @{$eduroam_authentication_source[0]{'local_realm'}} ) {
                 push (@realms, "Realm == \"$realm\"");
            }
            if (@realms) {
                $tags{'local_realm'} .= 'if ( ';
                $tags{'local_realm'} .=  join(' || ', @realms);
                $tags{'local_realm'} .= ' ) {'."\n";
                $tags{'local_realm'} .= <<"EOT";
                update control {
                    Proxy-To-Realm := "packetfence"
                }
            } else {
                update control {
                    Load-Balance-Key := "%{Calling-Station-Id}"
                    Proxy-To-Realm := "eduroam.cluster"
                }
            }
EOT
            } else {
$tags{'local_realm'} = << "EOT";
                    update control {
                        Load-Balance-Key := "%{Calling-Station-Id}"
                        Proxy-To-Realm := "eduroam.cluster"
                    }
EOT
            }
            $tags{'reject_realm'} = '';
            my @reject_realms;
            foreach my $reject_realm ( @{$eduroam_authentication_source[0]{'reject_realm'}} ) {
                 push (@reject_realms, "Realm == \"$reject_realm\"");
            }
            if (@reject_realms) {
                $tags{'reject_realm'} .= 'if ( ';
                $tags{'reject_realm'} .=  join(' || ', @reject_realms);
                $tags{'reject_realm'} .= ' ) {'."\n";
                $tags{'reject_realm'} .= <<"EOT";
                reject
            }
EOT
            }
            parse_template( \%tags, "$conf_dir/radiusd/eduroam-cluster", "$install_dir/raddb/sites-enabled/eduroam-cluster" );
        } else {
            unlink($install_dir."/raddb/sites-enabled/eduroam-cluster");
        }


        # RADIUS load_balancer instance configuration
        # raddb/load_balancer.conf
        %tags = ();
        $tags{'template'} = "$conf_dir/radiusd/load_balancer.conf";
        $tags{'pid_file'} = "$var_dir/run/radiusd-load_balancer.pid";
        $tags{'socket_file'} = "$var_dir/run/radiusd-load_balancer.sock";

        foreach my $interface ( uniq(@radius_ints) ) {

            my $cluster_ip = pf::cluster::cluster_ip($interface->{Tint});
            $tags{'listen'} .= <<"EOT";
listen {
        ipaddr = $cluster_ip
        port = 0
        type = auth
        virtual_server = pf.cluster
}


listen {
        ipaddr = $cluster_ip
        port = 0
        type = acct
        virtual_server = pf.cluster
}

listen {
        ipaddr = $cluster_ip
        port = 1815
        type = auth
        virtual_server = pfcli.cluster
}

EOT
        }

        # Eduroam integration
        if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
            my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
            my $listening_port = $eduroam_authentication_source[0]{'auth_listening_port'};
            $tags{'eduroam'} = <<"EOT";
# Eduroam integration
EOT
            foreach my $interface ( uniq(@radius_ints) ) {
                my $cluster_ip = pf::cluster::cluster_ip($interface->{Tint});
                $tags{'eduroam'} .= <<"EOT";
listen {
        ipaddr = $cluster_ip
        port = $listening_port
        type = auth
        virtual_server = eduroam.cluster
}
EOT
            }
        } else {
            $tags{'eduroam'} = "# Eduroam integration is not configured";
        }

        parse_template( \%tags, $tags{'template'}, "$install_dir/raddb/load_balancer.conf");

        
        push @radius_backend, $cluster_ip;
        foreach my $radius_back (@radius_backend) {
            $tags{'config'} .= <<"EOT";
client $radius_back {
        ipaddr = $radius_back
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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

