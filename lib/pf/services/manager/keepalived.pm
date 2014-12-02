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

extends 'pf::services::manager';
with 'pf::services::manager::roles::is_managed_vlan_inline_enforcement';

has '+name' => (default => sub { 'keepalived' } );

has '+launcher' => (default => sub { "sudo %1\$s -f $generated_conf_dir/keepalived.conf --pid $var_dir/run/keepalived.pid" } );

has '+shouldCheckup' => ( default => sub { 0 }  );

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
    $tags{'fromaddr'} = $Config{'alerting'}{'fromaddr'};
    $tags{'smtpserver'} = $Config{'alerting'}{'smtpserver'};

    $tags{'vrrp'} = '';
    $tags{'mysql_backend'} = '';
    my @ints = uniq(@listen_ints,@dhcplistener_ints);
    foreach my $interface ( @ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        next if (!isenabled($cfg->{'active_active_enabled'}));
        $tags{'vrrp'} .= <<"EOT";
vrrp_instance $cfg->{'ip'} {
  virtual_router_id 50
  advert_int 1
  priority $cfg->{'active_active_priority'}      # 150 on master less on backup
  state MASTER
  interface $interface
  virtual_ipaddress {
    $cfg->{'active_active_ip'} dev $interface
  }
#  notify_master /etc/keepalived/reload_conf.sh
#  notify_backup /etc/keepalived/reload_conf.sh
  track_script {
    haproxy
  }
  authentication {
    auth_type PASS
    auth_pass 1234
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
    my @ints = uniq(@listen_ints,@dhcplistener_ints);
    foreach my $interface ( @ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        if (isenabled($cfg->{'active_active_enabled'})) {
            return 1;
        }
    }
    return 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>



=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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
