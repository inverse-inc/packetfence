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
use pf::file_paths qw(
    $install_dir
    $conf_dir
);
use pf::util;
use Moo;

extends 'pf::services::manager';

has '+name' => ( default => sub {'statsd'} );
has '+optional' => ( default => sub {'1'} );

has '+launcher' =>
    ( default => sub {"%1\$s $install_dir/lib/Etsy/statsd/bin/statsd $install_dir/var/conf/statsd_config.js >>$install_dir/logs/statsd.log 2>&1 \& "} );

sub generateConfig {
    my %tags;
    $tags{'template'}      = "$conf_dir/monitoring/statsd_config.js";
    $tags{'pid_file'}      = "$install_dir/var/run/statsd.pid";

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/statsd_config.js", '//' );
}

has startDependsOnServices => (is => 'ro', default => sub { [qw(carbon_relay)] } );

1;
