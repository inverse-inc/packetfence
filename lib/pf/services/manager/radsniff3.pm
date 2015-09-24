package pf::services::manager::radsniff3;

=head1 NAME

pf::services::manager::radsniff3 management module. 

=cut

=head1 DESCRIPTION

pf::services::manager::radsniff

=cut

use strict;
use warnings;
use pf::file_paths;
use pf::util;
use pf::config;
use Moo;
use pf::cluster;

extends 'pf::services::manager';

has '+name' => ( default => sub {'radsniff3'} );
has '+optional' => ( default => sub {1} );

has '+launcher' => (
    default => sub {
        if($cluster_enabled){
          my $cluster_management_ip = pf::cluster::management_cluster_ip();
          my $management_ip = pf::cluster::current_server()->{management_ip};
          # We don't count requests/answers to the VIP
          # We don't count outbound resquests from the mgmt IP
          # We count outbound answers from the mgmt IP
          # We count requests/answers from the mgmt IP to the mgmt IP (local proxy)
          "sudo %1\$s -d $install_dir/raddb/ -D $install_dir/raddb/ -q -P $install_dir/var/run/radsniff3.pid -W10 -O $install_dir/var/run/collectd-unixsock -f 'not host $cluster_management_ip and ((not src host $management_ip and (udp dst port 1812 or 1813)) or (src host $management_ip and (not udp dst port 1812 or 1813)) or (src host $management_ip and dst host $management_ip))'";
        }
        else {
          "sudo %1\$s -d $install_dir/raddb/ -D $install_dir/raddb/ -q -P $install_dir/var/run/radsniff3.pid -W10 -O $install_dir/var/run/collectd-unixsock -i $management_network->{Tint}";
        }
    }
);

has dependsOnServices => ( is => 'ro', default => sub { [qw(collectd)] } );

1;
