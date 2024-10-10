package pf::services::manager::haproxy_portal;
=head1 NAME

pf::services::manager::haproxy_portal add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::haproxy_portal

=cut

use strict;
use warnings;
use Moo;
extends 'pf::services::manager::haproxy';

use pf::authentication;
use List::MoreUtils qw(uniq);
use pf::log;
use pf::util;
use pf::cluster;
use pf::config qw(
    %Config
    $OS
    @listen_ints
    @dhcplistener_ints
    $management_network
    @portal_ints
    $CONTAINER_INT
);
use pf::file_paths qw(
    $generated_conf_dir
    $install_dir
    $conf_dir
    $var_dir
    $captiveportal_templates_path
);

has '+name' => (default => sub { 'haproxy-portal' } );

has '+haproxy_config_template' => (default => sub { "$conf_dir/haproxy-portal.conf" });

my $host_id = $pf::config::cluster::host_id;

tie our %NetworkConfig, 'pfconfig::cached_hash', "resource::network_config($host_id)";

sub generateConfig {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    my ($package, $filename, $line) = caller();

    my %tags;
    $tags{'template'} = $self->haproxy_config_template;
    $tags{'http'} = '';
    $tags{'var_dir'} = $var_dir;
    $tags{'conf_dir'} = $var_dir.'/conf';

    my %backend_tags = (
        backend_proxy => "httpd_dispatcher",
        backend_static => "httpd_dispatcher_static",
        backend_pki => "pfpki",
        backend_portal => "httpd_portal",
    );
    while(my ($tag, $conf_key) = each(%backend_tags)) {
        my $u = URI->new($Config{services_url}{$conf_key});
        die "services_url.$conf_key doesn't use the http scheme: $Config{services_url}{$conf_key}" if($u->scheme ne "http");

        $tags{$tag} = $u->host . ":" . $u->port;
    }

    my $cluster_ip;
    my $ip_cluster;
    my @ints = uniq(@listen_ints,@dhcplistener_ints,map { $_->{'Tint'} } @portal_ints);
    my @portal_ip;
    my $rate_limiting = isenabled($Config{captive_portal}{rate_limiting});
    my $rate_limiting_threshold = $Config{captive_portal}{rate_limiting_threshold};

    my $i = 0;
    foreach my $interface ( @ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        last if $i > 0;
        if ($cfg->{'type'} =~ /internal/ || $cfg->{'type'} =~ /portal/) {
            my $cluster_ip = pf::cluster::cluster_ip($interface) || $cfg->{'vip'} || $cfg->{'ip'};
            $ip_cluster = $cluster_ip;
            push @portal_ip, $cluster_ip;
            my @backend_hosts = values %{pf::cluster::members_ips($interface)};
            if (!@backend_hosts) {
                my $portal_backend = URI->new($Config{services_url}{httpd_portal});
                push @backend_hosts, $tags{backend_portal};
            } else {
                @backend_hosts = map {"$_:8080"} @backend_hosts;
                push @portal_ip, @backend_hosts;
            }
            my $backend_hosts_config = '';
            foreach my $back ( @backend_hosts ) {
                # cluster specific
                next if($back eq "$cfg->{ip}:8080" && isdisabled($Config{active_active}{portal_on_management}));

                $backend_hosts_config .= <<"EOT";
        server $back $back check inter 10s fastinter 2s
EOT
            }

            $tags{'http'} .= <<"EOT";
frontend portal-http-$cluster_ip
        bind *:80
        capture request header Host len 40
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
        http-request add-header X-Forwarded-Proto http
        use_backend %[var(req.action)]
        default_backend $cluster_ip-backend

frontend portal-https-$cluster_ip
        bind *:443 ssl no-sslv3 crt /usr/local/pf/conf/ssl/server.pem
        capture request header Host len 40
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
        http-request add-header X-Forwarded-Proto https
        use_backend %[var(req.action)]
        default_backend $cluster_ip-backend


backend $cluster_ip-backend
        balance source
        option httpchk GET /captive-portal HTTP/1.0\\r\\nUser-agent:\\ HAPROXY-load-balancing-check\\r\\nHost:\\ $Config{'general'}{'hostname'}.$Config{'general'}{'domain'}
        default-server inter 5s fall 3 rise 2
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
$backend_hosts_config
EOT

            # IPv6 handling
            my $cluster_ipv6 = pf::cluster::cluster_ipv6($interface) || $cfg->{'ipv6_address'};
            if ( defined($cluster_ipv6) ) {
                push @portal_ip, $cluster_ipv6;
                $tags{'http'} .= <<"EOT";
frontend portal-http-$cluster_ipv6
        bind :::80
        capture request header Host len 40
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
        http-request add-header X-Forwarded-Proto http
        use_backend %[var(req.action)]
        default_backend $cluster_ip-backend

frontend portal-https-$cluster_ipv6
        bind :::443 ssl no-sslv3 crt /usr/local/pf/conf/ssl/server.pem
        capture request header Host len 40
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
        http-request add-header X-Forwarded-Proto https
        use_backend %[var(req.action)]
        default_backend $cluster_ip-backend
EOT
            }

        $i++;
        }
    }

    $tags{captiveportal_templates_path} = $captiveportal_templates_path;
    parse_template( \%tags, $self->haproxy_config_template, "$generated_conf_dir/".$self->name.".conf" );

    my $fqdn = $Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};

    my @portal_hosts = (@portal_ip, $fqdn);

    # Add any activation domain in the authentication sources
    push @portal_hosts, map { $_->{activation_domain} ? $_->{activation_domain} : () } @{getAllAuthenticationSources()};
    push @portal_hosts, @{$Config{captive_portal}->{other_domain_names}};
    push @portal_hosts, map { $NetworkConfig{$_}->{portal_fqdn} ? $NetworkConfig{$_}->{portal_fqdn} : () } keys %NetworkConfig;

    # Escape special chars for lua matches
    @portal_hosts = map { $_ =~ s/([.-])/%$1/g ; $_ } @portal_hosts;
    # Allow wildcards (the string starts with a '*')
    @portal_hosts = map { $_ =~ s/^\*(.*)/.*$1/g ; $_ } @portal_hosts;

    my $vars = {
        portal_host => sub { return @portal_hosts },
        fqdn => $Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'},
    };

    my $config_file = "passthrough.lua";
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process("$conf_dir/$config_file.tt", $vars, "$generated_conf_dir/$config_file") or die $tt->error();

    return 1;
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
