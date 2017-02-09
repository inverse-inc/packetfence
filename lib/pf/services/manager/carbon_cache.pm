package pf::services::manager::carbon_cache;

=head1 NAME

pf::services::manager::carbon_cache

=cut

=head1 DESCRIPTION

pf::services::manager::carbon_cache
carbon-cache daemon manager module for PacketFence.

=cut

use strict;
use warnings;
use pf::file_paths qw(
    $install_dir
    $conf_dir
);
use pf::util;
use pf::config qw(
    %Config
    $management_network
);
use pf::cluster;
use Moo;

extends 'pf::services::manager';

has '+name'     => ( default => sub { 'carbon-cache' } );
has '+optional' => ( default => sub { 1 } );

sub _cmdLine {
    my $self = shift;
    $self->executable 
        . " --pidfile=" . $self->pidFile
        . " --config=$install_dir/var/conf/carbon.conf  --logdir=$install_dir/logs --nodaemon start";
}

sub generateConfig {
    generate_storage_config();
    generate_carbon_config();
}

sub generate_storage_config {
    my %tags;
    $tags{'template'}      = "$conf_dir/monitoring/storage-schemas.conf";
    $tags{'hostname'}      = "$Config{'general'}{'hostname'}";
    $tags{'graphite_host'} = "$Config{'monitoring'}{'graphite_host'}";
    $tags{'graphite_port'} = "$Config{'monitoring'}{'graphite_port'}";
    $tags{'install_dir'}   = "$install_dir";

    parse_template( \%tags, "$tags{'template'}",
        "$install_dir/var/conf/storage-schemas.conf" );
}

sub generate_carbon_config {
    my %tags;
    $tags{'template'}    = "$conf_dir/monitoring/carbon.conf";
    $tags{'install_dir'} = "$install_dir";
    $tags{'management_ip'} =
      defined( $management_network->tag('vip') )
      ? $management_network->tag('vip')
      : $management_network->tag('ip');
    $tags{'graphite_host'} = "$Config{'monitoring'}{'graphite_host'}";
    $tags{'graphite_port'} = "$Config{'monitoring'}{'graphite_port'}";
    $tags{'carbon_hosts'} =
      ( get_cluster_destinations() || $tags{'management_ip'} . ":2004" );

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/carbon.conf" );
}

sub get_cluster_destinations {
    @cluster_hosts
      ? join( ', ', map { $_->{management_ip} . ":2004" } @cluster_servers )
      : undef;
}


1;
