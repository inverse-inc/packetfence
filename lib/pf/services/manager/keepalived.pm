package pf::services::manager::keepalived;

=head1 NAME

pf::services::manager::keepalived add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::keepalived

=cut

use strict;
use warnings;
use Moo;
use IPC::Cmd qw[can_run run];
use List::MoreUtils qw(uniq);
use POSIX;
use pf::config qw(
    %Config
    @portal_ints
    @listen_ints
    @dhcplistener_ints
    @radius_ints
    %ConfigNetworks
);
use pf::file_paths qw(
    $generated_conf_dir
    $install_dir
    $var_dir
    $conf_dir
);
use pf::log;
use pf::util;
use pf::constants qw($SPACE $SPACE_NUMBERS);
use pf::cluster;
use pf::nodecategory qw(nodecategory_view_all);

my $host_id = $pf::config::cluster::host_id;

tie our %NetworkConfig, 'pfconfig::cached_hash', "resource::network_config($host_id)";

extends 'pf::services::manager';

has '+name' => (default => sub { 'keepalived' } );

sub _cmdLine {
    my $self = shift;
    $self->executable . " -f $generated_conf_dir/keepalived.conf --pid=" . $self->pidFile;
}

sub executable {
    my ($self) = @_;
    my $service = ( $Config{'services'}{"keepalived_binary"} || "$install_dir/sbin/keepalived" );
    return $service;
}


sub generateConfig {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    my ($package, $filename, $line) = caller();
    $logger->info("$package, $filename, $line");

    my $internal_portal_ip = $Config{captive_portal}{ip_address};

    my %tags;
    $tags{'template'} = "$conf_dir/keepalived.conf";
    
    # split email addresses then rejoin them with line feed and indent
    $tags{'emailaddr'} = join("\n" . ($SPACE x $SPACE_NUMBERS), split( /\s*,\s*/, $Config{'alerting'}{'emailaddr'}));
    
    $tags{'fromaddr'} = $Config{'alerting'}{'fromaddr'} || "keepalived\@$host_id";
    $tags{'smtpserver'} = $Config{'alerting'}{'smtpserver'};
    $tags{'router_id'} = "PacketFence-$host_id";

    $tags{'vrrp'} = '';
    $tags{'lvs'} = '';

    my ($routes,$ips) = $self->generateRoutes();
    $tags{'vrrp'} .= <<"EOT";

static_ipaddress {
    $internal_portal_ip dev lo scope link
    $ips
}

static_routes {

#Static from packetfence config
EOT
    foreach my $route (@{$Config{'network'}{'staticroutes'}}) {
        $tags{'vrrp'} .= <<"EOT";
$route
EOT
    }
    $tags{'vrrp'} .= <<"EOT";
#PacketFence managed networks
$routes
}

EOT

    if ( $pf::cluster::cluster_enabled ) {
        my @ints = uniq(@listen_ints,@dhcplistener_ints, (map { $_->{'Tint'} } @portal_ints, @radius_ints));
        foreach my $interface ( @ints ) {
            my $cfg = $Config{"interface $interface"};
            next unless $cfg;
            my $priority = 100 - pf::cluster::cluster_index();
            if(isdisabled($Config{active_active}{centralize_vips})) {
                $priority = 100 - pf::cluster::reg_cluster_index();
            }
            my $process_tracking = "haproxy_portal";
            my $cluster_ip = pf::cluster::cluster_ip($interface);
            if ($Config{"interface $interface"}{'type'} =~ /management/i) {
                # Defined list of ports we have to listen
                foreach my $port ( 2055,6343 ) {
                    $tags{'lvs'} .= <<"EOT";
virtual_server $cluster_ip $port {
  delay_loop 2
  lvs_sched fo
  lvs_method NAT
  protocol UDP
  retry 10
  delay_before_retry 5
EOT
                    my @active_members;
                    foreach my $member (values %{pf::cluster::members_ips($interface)}) {
                        $tags{'lvs'} .= <<"EOT";
  real_server $member $port {
    SSL_GET {
      connect_ip $member
      connect_port 4723
      url {
        path "/"
        status_code 404
      }
      connect_timeout 10
    }
  }
EOT
                    }
$tags{'lvs'} .= <<"EOT";
}

EOT
                }
            }
            if ($Config{"interface $interface"}{'type'} =~ /management/i || $Config{"interface $interface"}{'type'} =~ /radius/i) {
                $process_tracking = "radius_load_balancer";
                if(isdisabled($Config{active_active}{centralize_vips})) {
                    $priority = 100 - pf::cluster::cluster_index();
                }
            }
            $tags{'vrrp'} .= <<"EOT";
vrrp_instance $cfg->{'ip'} {
  virtual_router_id $Config{'active_active'}{'virtual_router_id'}
  advert_int 5
  priority $priority
  state MASTER
  interface $interface
  preempt_delay 30
  virtual_ipaddress {
    $cluster_ip dev $interface
  }
EOT
            if (isenabled($Config{'active_active'}{'vrrp_unicast'})) {
                my $active_members = join("\n", grep( {$_ ne $cfg->{'ip'}} values %{pf::cluster::members_ips($interface)}));
                $tags{'vrrp'} .= << "EOT";
unicast_src_ip $cfg->{'ip'}
unicast_peer {
$active_members
}
EOT
            }
            $tags{'vrrp'} .= "  notify_master \"$install_dir/bin/cluster/pfupdate --mode=master --vip=$cluster_ip\"\n";
            $tags{'vrrp'} .= "  notify_backup \"$install_dir/bin/cluster/pfupdate --mode=slave --vip=$cluster_ip\"\n";
            $tags{'vrrp'} .= "  notify_fault \"$install_dir/bin/cluster/pfupdate --mode=slave --vip=$cluster_ip\"\n";

            $tags{'vrrp'} .= <<"EOT";
  track_script {
    $process_tracking
  }
  authentication {
    auth_type PASS
    auth_pass $Config{'active_active'}{'password'}
  }
  smtp_alert
}
EOT
        }
    }
    parse_template( \%tags, "$conf_dir/keepalived.conf", "$generated_conf_dir/keepalived.conf" );
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

sub isManaged {
    my ($self) = @_;
    my $name = $self->name;
    return 1;
}

sub generateRoutes {
    my ($self) = @_;
    my $logger = get_logger();
    my $routes = '';
    my $ips = '';
    foreach my $network ( keys %NetworkConfig ) {
        my %net = %{$NetworkConfig{$network}};
        my $current_network = NetAddr::IP->new( $network, $net{'netmask'} );
        my $dev = $NetworkConfig{$network}{'interface'}{'int'};
        if ( defined($net{'next_hop'}) && ($net{'next_hop'} =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) && defined($dev) ) {
            $routes .= "$current_network via $net{'next_hop'} dev $dev\n"
        } else {
            if ( isenabled($NetworkConfig{$network}{'dhcpd'}) ) {
                if (isenabled($NetworkConfig{$network}{'split_network'})) {
                    my @categories = nodecategory_view_all();
                    my $count = @categories;
                    $count++;
                    push @categories, {'name' => 'registration'};
                    my $len = $current_network->masklen;
                    my $cidr = (ceil(log($count)/log(2)) + $len);
                    if ($cidr > 30) {
                        $logger->error("Can't split network");
                        next;
                    }
                    if ($NetworkConfig{$network}{'reg_network'}) {
                        $ips .= "$NetworkConfig{$network}{'reg_network'} dev $dev\n";
                    }
                    my @sub_net = $current_network->split($cidr);
                    foreach my $net (@sub_net) {
                        my $role = pop @categories;
                        next unless $role->{'name'};
                        my $pf_ip = $net + 1;
                        $ips .= "$pf_ip dev $dev\n";
                        my $first = $net + 2;
                    }
                }
            }
        }
    }
    return $routes, $ips;
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
