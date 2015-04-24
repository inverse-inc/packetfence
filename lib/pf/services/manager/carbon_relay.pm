package pf::services::manager::carbon_relay;

=head1 NAME

pf::services::manager::carbon-relay

=cut

=head1 DESCRIPTION

pf::services::manager::carbon-relay
carbon-relay daemon manager module for PacketFence.

=cut

use strict;
use warnings;
use pf::file_paths;
use pf::util;
use pf::config;
use Moo;

extends 'pf::services::manager';

has '+name' => ( default => sub {'carbon_relay'} );

has '+launcher' =>
    ( default => sub {"sudo %1\$s --config=$install_dir/var/conf/carbon.conf --pidfile=$install_dir/var/run/carbon_relay.pid --logdir=$install_dir/logs start"} );

#sub generateConfig {
#    generate_carbon_config();
#}

sub generate_carbon_config { 
    my %tags;
    $tags{'template'}      = "$conf_dir/monitoring/carbon.conf";
    $tags{'graphite_host'} = "$Config{'monitoring'}{'graphite_host'}";
    $tags{'graphite_port'} = "$Config{'monitoring'}{'graphite_port'}";

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/carbon.conf" );
}

has dependsOnServices => (is => 'ro', default => sub { [qw(carbon_cache)] } );

1;
