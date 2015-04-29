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

extends 'pf::services::manager';

has '+name' => ( default => sub {'radsniff3'} );
has '+optional' => ( default => sub {1} );

has '+launcher' => (
    default => sub {
        "sudo %1\$s -d $install_dir/raddb/ -D $install_dir/raddb/ -q -P $install_dir/var/run/radsniff3.pid -W10 -O $install_dir/var/run/collectd-unixsock";
    }
);

has dependsOnServices => ( is => 'ro', default => sub { [qw(collectd)] } );

1;
