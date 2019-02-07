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

    my %tags;
    $tags{'template'} = "$conf_dir/keepalived.conf";
    
    # split email addresses then rejoin them with line feed and indent
    $tags{'emailaddr'} = join("\n" . ($SPACE x $SPACE_NUMBERS), split( /\s*,\s*/, $Config{'alerting'}{'emailaddr'}));
    
    $tags{'fromaddr'} = $Config{'alerting'}{'fromaddr'} || "keepalived\@$host_id";
    $tags{'smtpserver'} = $Config{'alerting'}{'smtpserver'};
    $tags{'router_id'} = "PacketFence-$host_id";

    $tags{'vrrp'} = '';
    $tags{'mysql_backend'} = '';
    my @ints = uniq(@listen_ints,@dhcplistener_ints, (map { $_->{'Tint'} } @portal_ints, @radius_ints));
    foreach my $interface ( @ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        my $priority = 100 - pf::cluster::cluster_index();
        my $cluster_ip = pf::cluster::cluster_ip($interface);
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
        $tags{'vrrp'} .= "  notify_master \"$install_dir/bin/cluster/pfupdate --mode=master\"\n";
        $tags{'vrrp'} .= "  notify_backup \"$install_dir/bin/cluster/pfupdate --mode=slave\"\n";
        $tags{'vrrp'} .= "  notify_fault \"$install_dir/bin/cluster/pfupdate --mode=slave\"\n";

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
    my $name = $self->name;
    if (isenabled($pf::config::Config{'services'}{$name})) {
        return $cluster_enabled;
    } else {
        return 0;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>



=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
