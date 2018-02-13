package pf::services::manager::haproxy;
=head1 NAME

pf::services::manager::haproxy add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::haproxy

=cut

use strict;
use warnings;
use Moo;
use IPC::Cmd qw[can_run run];
use List::MoreUtils qw(uniq);
use POSIX;
use pf::config qw(
    %Config
    $OS
    @listen_ints
    @dhcplistener_ints
    $management_network
    @portal_ints
);
use pf::file_paths qw(
    $generated_conf_dir
    $install_dir
    $conf_dir
    $var_dir
    $captiveportal_templates_path
);
use pf::log;
use pf::util;
use pf::cluster;
use Template;
use pf::authentication;
use pf::dal::tenant;

extends 'pf::services::manager';

has '+name' => (default => sub { 'haproxy' } );

sub _cmdLine {
    my $self = shift;
    $self->executable . " -f $generated_conf_dir/haproxy.conf -p $install_dir/var/run/haproxy.pid";
}

has '+shouldCheckup' => ( default => sub { 0 }  );

sub executable {
    my ($self) = @_;
    my $service = ( $Config{'services'}{"haproxy_binary"} || "$install_dir/sbin/haproxy" );
    return $service;
}

sub _number_cpus {
    my ($self) = @_;
    open my $cpuinfo, '<', '/proc/cpuinfo';
    my $cpu_cores = 0;
    foreach my $line (<$cpuinfo>)  {
        if ($line =~ /^cpu\scores\s+:\s+(\d+)/) {
            $cpu_cores = $cpu_cores + $1;
        }
    }
    close $cpuinfo;
    return $cpu_cores;
}

sub generateConfig {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    my ($package, $filename, $line) = caller();

    my %tags;
    $tags{'template'} = "$conf_dir/haproxy.conf";
    $tags{'http'} = '';
    $tags{'mysql_backend'} = '';
    $tags{'var_dir'} = $var_dir;
    $tags{'conf_dir'} = $var_dir.'/conf';
    $tags{'cpu'} = '';
    $tags{'bind-process'} = '';
    my $bind_process = '';
    if ($self->_number_cpus > 1) {
        $tags{'cpu'} .= <<"EOT";
        nbproc 2
        cpu-map 1 1
        cpu-map 2 2
EOT
        $tags{'bind-process'} = 'bind-process 1';
        $bind_process = 'bind-process 2';
    }

    if ($OS eq 'debian') {
        $tags{'os_path'} = '/etc/haproxy/errors/';
    } else {
         $tags{'os_path'} = '/usr/share/haproxy/';
    }
    my @ints = uniq(@listen_ints,@dhcplistener_ints,map { $_->{'Tint'} } @portal_ints);
    my @portal_ip;
    foreach my $interface ( @ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        my $i = 0;
        if ($interface eq $management_network->tag('int')) {
            $tags{'active_active_ip'} = pf::cluster::management_cluster_ip() || $cfg->{'vip'} || $cfg->{'ip'};
            my @mysql_backend = map { $_->{management_ip} } pf::cluster::mysql_servers();
            push @mysql_backend, $cfg->{'ip'} if !@mysql_backend;
            foreach my $mysql_back (@mysql_backend) {
                # the second server (the one without the VIP) will be the prefered MySQL server
                if ($i == 0) {
                $tags{'mysql_backend'} .= <<"EOT";
    server MySQL$i $mysql_back:3306 check
EOT
                } else {
                $tags{'mysql_backend'} .= <<"EOT";
    server MySQL$i $mysql_back:3306 check backup
EOT
                }
            $i++;
            }
            my $cluster_ip = pf::cluster::cluster_ip($interface) || $cfg->{'vip'} || $cfg->{'ip'};
            my @backend_ip = values %{pf::cluster::members_ips($interface)};
            push @backend_ip, '127.0.0.1' if !@backend_ip;
            my $backend_ip_config = '';
            foreach my $back_ip ( @backend_ip ) {

                $backend_ip_config .= <<"EOT";
        server $back_ip $back_ip:80 check
EOT
            }

        }
        if ($cfg->{'type'} =~ /internal/ || $cfg->{'type'} =~ /portal/) {
            my $cluster_ip = pf::cluster::cluster_ip($interface) || $cfg->{'vip'} || $cfg->{'ip'};
            push @portal_ip, $cluster_ip;
            my @backend_ip = values %{pf::cluster::members_ips($interface)};
            push @backend_ip, '127.0.0.1' if !@backend_ip;
            my $backend_ip_config = '';
            foreach my $back_ip ( @backend_ip ) {

                $backend_ip_config .= <<"EOT";
        server $back_ip $back_ip:80 check
EOT
            }

            my $rate_limiting = isenabled($Config{captive_portal}{rate_limiting});
            my $rate_limiting_threshold = $Config{captive_portal}{rate_limiting_threshold};

            $tags{'http'} .= <<"EOT";
frontend portal-http-$cluster_ip
        bind $cluster_ip:80
        stick-table type ip size 1m expire 10s store gpc0,http_req_rate(10s)
        tcp-request connection track-sc1 src
        http-request lua.change_host
        acl host_exist var(req.host) -m found
        http-request set-header Host %[var(req.host)] if host_exist
        http-request lua.select
        acl action var(req.action) -m found
EOT
            if($rate_limiting) {
            $tags{'http'} .= <<"EOT";
        acl unflag_abuser src_clr_gpc0 --
        http-request allow if action unflag_abuser
        http-request deny if { src_get_gpc0 gt 0 }
EOT
            }
            $tags{'http'} .= <<"EOT";
        reqadd X-Forwarded-Proto:\\ http
        use_backend %[var(req.action)]
        default_backend $cluster_ip-backend
        $bind_process

frontend portal-https-$cluster_ip
        bind $cluster_ip:443 ssl no-sslv3 crt /usr/local/pf/conf/ssl/server.pem
        stick-table type ip size 1m expire 10s store gpc0,http_req_rate(10s)
        tcp-request connection track-sc1 src
        http-request lua.change_host
        acl host_exist var(req.host) -m found
        http-request set-header Host %[var(req.host)] if host_exist
        http-request lua.select
        acl action var(req.action) -m found
EOT
            if($rate_limiting) {
            $tags{'http'} .= <<"EOT";
        acl unflag_abuser src_clr_gpc0 --
        http-request allow if action unflag_abuser
        http-request deny if { src_get_gpc0 gt 0 }
EOT
            }
            $tags{'http'} .= <<"EOT";
        reqadd X-Forwarded-Proto:\\ https
        use_backend %[var(req.action)]
        default_backend $cluster_ip-backend
        $bind_process

backend $cluster_ip-backend
        balance source
        option httpclose
        option forwardfor
EOT
            if($rate_limiting) {
            $tags{'http'} .= <<"EOT";
        acl status_501 status 501
        acl abuse  src_http_req_rate(portal-http-$cluster_ip) ge $rate_limiting_threshold
        acl flag_abuser src_inc_gpc0(portal-http-$cluster_ip) --
        acl abuse  src_http_req_rate(portal-https-$cluster_ip) ge $rate_limiting_threshold
        acl flag_abuser src_inc_gpc0(portal-https-$cluster_ip) --
        http-response deny if abuse status_501 flag_abuser
EOT
            }
            $tags{'http'} .= <<"EOT";
$backend_ip_config
EOT

            # IPv6 handling
            my $cluster_ipv6 = pf::cluster::cluster_ipv6($interface) || $cfg->{'ipv6_address'};
            if ( defined($cluster_ipv6) ) {
                push @portal_ip, $cluster_ipv6;
                $tags{'http'} .= <<"EOT";
frontend portal-http-$cluster_ipv6
        bind $cluster_ipv6:80
        stick-table type ipv6 size 1m expire 10s store gpc0,http_req_rate(10s)
        tcp-request connection track-sc1 src
        http-request lua.change_host
        acl host_exist var(req.host) -m found
        http-request set-header Host %[var(req.host)] if host_exist
        http-request lua.select
        acl action var(req.action) -m found
        acl unflag_abuser src_clr_gpc0 --
        http-request allow if action unflag_abuser
        http-request deny if { src_get_gpc0 gt 0 }
        reqadd X-Forwarded-Proto:\\ http
        use_backend %[var(req.action)]
        default_backend $cluster_ip-backend
        $bind_process

frontend portal-https-$cluster_ipv6
        bind $cluster_ipv6:443 ssl no-sslv3 crt /usr/local/pf/conf/ssl/server.pem
        stick-table type ipv6 size 1m expire 10s store gpc0,http_req_rate(10s)
        tcp-request connection track-sc1 src
        http-request lua.change_host
        acl host_exist var(req.host) -m found
        http-request set-header Host %[var(req.host)] if host_exist
        http-request lua.select
        acl action var(req.action) -m found
        acl unflag_abuser src_clr_gpc0 --
        http-request allow if action unflag_abuser
        http-request deny if { src_get_gpc0 gt 0 }
        reqadd X-Forwarded-Proto:\\ https
        use_backend %[var(req.action)]
        default_backend $cluster_ip-backend
        $bind_process
EOT
            }

        }
    }
    $tags{'management_ip'}
        = defined( $management_network->tag('vip') )
        ? $management_network->tag('vip')
        : $management_network->tag('ip');


    $tags{captiveportal_templates_path} = $captiveportal_templates_path;
    parse_template( \%tags, "$conf_dir/haproxy.conf", "$generated_conf_dir/haproxy.conf" );

    my $fqdn = $Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};

    my @portal_hosts = (@portal_ip, $fqdn);

    # Add any activation domain in the authentication sources
    push @portal_hosts, map { $_->{activation_domain} ? $_->{activation_domain} : () } @{getAllAuthenticationSources()};
    push @portal_hosts, @{$Config{captive_portal}->{other_domain_names}};
    push @portal_hosts, map {$_->portal_domain_name ? $_->portal_domain_name : ()} @{pf::dal::tenant->search->all};


    # Escape special chars for lua matches
    @portal_hosts = map { $_ =~ s/([.-])/%$1/g ; $_ } @portal_hosts;
    # Allow wildcards (the string starts with a '*')
    @portal_hosts = map { $_ =~ s/^\*/.*$1/g ; $_ } @portal_hosts;

    my $vars = {
        portal_host => sub { return @portal_hosts },
        fqdn => $Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'},
    };

    my $config_file = "passthrough.lua";
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process("$conf_dir/$config_file.tt", $vars, "$generated_conf_dir/$config_file") or die $tt->error();

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

Copyright (C) 2005-2018 Inverse inc.

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
