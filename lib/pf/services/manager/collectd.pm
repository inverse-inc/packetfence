package pf::services::manager::collectd;

=head1 NAME

pf::services::manager::collectd

=cut

=head1 DESCRIPTION

pf::services::manager::collectd
collectd daemon manager module for PacketFence.

=cut

use strict;
use warnings;
use pf::file_paths;
use pf::util;
use pf::config;
use Moo;

extends 'pf::services::manager';

has '+name' => ( default => sub { 'collectd' } );
has dependsOnServices => ( is => 'ro', default => sub { [qw(carbon_relay)] } );

has '+launcher' => (
    default => sub {
"sudo %1\$s -P $install_dir/var/run/collectd.pid -C $install_dir/var/conf/collectd.conf";
    }
);

sub generateConfig {
    generateCollectd();
    generateTypes();
}

sub generateCollectd {
    my %tags;
    $tags{'template'}      = "$conf_dir/monitoring/collectd.conf";
    $tags{'install_dir'}   = "$install_dir";
    $tags{'graphite_host'} = "$Config{'monitoring'}{'graphite_host'}";
    $tags{'graphite_port'} = "$Config{'monitoring'}{'graphite_port'}";

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/collectd.conf" );
}

sub generateTypes { 
    my %tags;
    $tags{'template'}      = "$conf_dir/monitoring/types.db";
    $tags{'install_dir'}   = "$install_dir";

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/types.db" );
}

1;
