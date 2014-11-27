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
use pf::config;
use pf::log;
use pf::util;

extends 'pf::services::manager';
with 'pf::services::manager::roles::is_managed_vlan_inline_enforcement';

has '+name' => (default => sub { 'haproxy' } );

has '+launcher' => (default => sub { "sudo %1\$s -f $generated_conf_dir/haproxy.conf -D -p $var_dir/run/haproxy.pid" } );

has '+shouldCheckup' => ( default => sub { 0 }  );

sub executable {
    my ($self) = @_;
    my $service = ( $Config{'services'}{"haproxy_binary"} || "$install_dir/sbin/haproxy" );
    return $service;
}

sub generateConfig {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    my ($package, $filename, $line) = caller();
    $logger->info("$package, $filename, $line");

    my %tags;
    $tags{'template'} = "$conf_dir/haproxy.conf";
    $tags{'http'} = '';
    $tags{'mysql_backend'} = '';
    my @ints = uniq(@listen_ints,@dhcplistener_ints);
    my $j = 0;
    foreach my $interface ( @ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        next if (!isenabled($cfg->{'active_active_enabled'}));
        my $i = 0;
        if ($cfg->{'type'} eq 'management') {
            $tags{'active_active_ip'} = $cfg->{'active_active_ip'};
            my @mysql_backend = split(',',$cfg->{'active_active_members'});
            my $backup = '';
            foreach my $mysql_back (@mysql_backend) {
                $tags{'mysql_backend'} .= <<"EOT";
        server MySQL$i $mysql_back:3306 check weight 1
EOT
            $i++;
            $backup = 'backup';
            }
        }
        if ($cfg->{'type'} eq 'internal') {
            my @backend_ip = split(',',$cfg->{'active_active_members'});
            my $backend_ip_config = '';
            foreach my $back_ip ( @backend_ip ) {

                $backend_ip_config .= <<"EOT";
        server pf$i $back_ip:80 check
EOT
                $i++;
            }
 
            $tags{'http'} .= <<"EOT";
frontend http-$j
        bind $cfg->{'active_active_ip'}:80
        reqadd X-Forwarded-Proto:\\ http
        default_backend $j-backend

frontend https-$j
        bind $cfg->{'active_active_ip'}:443 ssl crt /usr/local/pf/conf/ssl/server.pem
        reqadd X-Forwarded-Proto:\\ https
        default_backend $j-backend

backend $j-backend
        balance leastconn
        option httpclose
        option forwardfor
$backend_ip_config

EOT

            $j++;
        }
    }

    parse_template( \%tags, "$conf_dir/haproxy.conf", "$generated_conf_dir/haproxy.conf" );
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
