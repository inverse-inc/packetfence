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
use pf::config;
use pf::log;
use pf::util;
use pf::cluster;

extends 'pf::services::manager';

has '+name' => (default => sub { 'keepalived' } );

has '+launcher' => (default => sub { "sudo %1\$s -f $generated_conf_dir/keepalived.conf --pid $var_dir/run/keepalived.pid" } );

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

    my %tags;
    $tags{'template'} = "$conf_dir/keepalived.conf";
    $tags{'emailaddr'} = $Config{'alerting'}{'emailaddr'};
    $tags{'fromaddr'} = $Config{'alerting'}{'fromaddr'} || 'root@localhost';
    $tags{'smtpserver'} = $Config{'alerting'}{'smtpserver'};

    $tags{'vrrp'} = '';
    $tags{'mysql_backend'} = '';
    my @ints = uniq(@listen_ints,@dhcplistener_ints);
    foreach my $interface ( @ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        my $priority = 100 - pf::cluster::cluster_index();
        my $cluster_ip = pf::cluster::cluster_ip($interface);
        $tags{'vrrp'} .= <<"EOT";
vrrp_instance $cfg->{'ip'} {
  virtual_router_id $Config{'active_active'}{'virtual_router_id'}
  advert_int 1
  priority $priority
  state MASTER
  interface $interface
  virtual_ipaddress {
    $cluster_ip dev $interface
  }
EOT
        if(defined($cfg->{type}) && $cfg->{type} =~ /management/){
            $tags{'vrrp'} .= "  notify \"$install_dir/bin/cluster/management_update\"\n";
        }

        $tags{'vrrp'} .= <<"EOT";
  track_script {
    haproxy
  }
  authentication {
    auth_type PASS
    auth_pass $Config{'active_active'}{'password'}
  }
  smtp_alert
}
EOT

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
    return $cluster_enabled; 
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>



=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
