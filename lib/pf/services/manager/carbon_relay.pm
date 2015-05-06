package pf::services::manager::carbon_relay;

=head1 NAME

pf::services::manager::carbon_relay

=cut

=head1 DESCRIPTION

pf::services::manager::carbon_relay
carbon-relay daemon manager module for PacketFence.

=cut

use strict;
use warnings;
use pf::file_paths;
use pf::util;
use pf::config;
use pf::cluster;
use Moo;

extends 'pf::services::manager';

has '+name' => ( default => sub {'carbon-relay'} );
has '+optional' => ( default => sub {1} );

has '+launcher' =>
    ( default => sub {"sudo %1\$s --config=$install_dir/var/conf/carbon.conf --pidfile=$install_dir/var/run/carbon-relay.pid --logdir=$install_dir/logs start"} );

1;
