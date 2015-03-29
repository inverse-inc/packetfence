package pf::services::manager::statsd;

=head1 NAME

pf::services::manager::statsd

=cut

=head1 DESCRIPTION

pf::services::manager::statsd
StatD daemon manager module for PacketFence.

=cut

use strict;
use warnings;
use pf::file_paths;
use pf::util;
use pf::config;
use Moo;

extends 'pf::services::manager';

has '+name' => ( default => sub {'statsd'} );

has '+launcher' =>
    ( default => sub {"sudo %1\$s /usr/lib/statsd/stats.js $install_dir/var/conf/statsd_config.js "} );

sub generateConfig {
    my %tags;
    $tags{'template'}      = "$conf_dir/monitoring/statsd_config.js";
    $tags{'graphite_host'} = "$Config{'monitoring'}{'graphite_host'}";
    $tags{'graphite_port'} = "$Config{'monitoring'}{'graphite_port'}";
    $tags{'statsd_port'}   = "$Config{'monitoring'}{'statsd_port'}";
    $tags{'management_ip'}
        = defined( $management_network->tag('vip') )
        ? $management_network->tag('vip')
        : $management_network->tag('ip');

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/statsd_config.js" );
}

