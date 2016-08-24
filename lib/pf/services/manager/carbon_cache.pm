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
use Template;
extends 'pf::services::manager';

has '+name'     => ( default => sub { 'carbon-cache' } );
has '+optional' => ( default => sub { 1 } );

has '+launcher' => (
    default => sub {
"sudo %1\$s --config=$install_dir/var/conf/carbon.conf --pidfile=$install_dir/var/run/carbon-cache.pid --logdir=$install_dir/logs start";
    }
);


sub generateConfig {
    generate_storage_config();
    generate_carbon_config();
}

sub generate_storage_config {
    my %vars;
    $vars{'template'}      = "$conf_dir/monitoring/storage-schemas.conf";
    $vars{'hostname'}      = "$Config{'general'}{'hostname'}";
    $vars{'graphite_host'} = "$Config{'monitoring'}{'graphite_host'}";
    $vars{'graphite_port'} = "$Config{'monitoring'}{'graphite_port'}";
    $vars{'install_dir'}   = "$install_dir";

    
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process($vars{'template'}, \%vars, "$install_dir/var/conf/storage-schemas.conf");
}

sub generate_carbon_config {
    my %vars;
    $vars{'template'}    = "$conf_dir/monitoring/carbon.conf";
    $vars{'install_dir'} = "$install_dir";
    $vars{'management_ip'} =
      defined( $management_network->tag('vip') )
      ? $management_network->tag('vip')
      : $management_network->tag('ip');
    $vars{'graphite_host'} = "$Config{'monitoring'}{'graphite_host'}";
    $vars{'graphite_port'} = "$Config{'monitoring'}{'graphite_port'}";
    $vars{'carbon_hosts'} =
      ( get_cluster_destinations() || $vars{'management_ip'} . ":2004" );
    
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process($vars{'template'}, \%vars, "$install_dir/var/conf/carbon.conf");
}

sub get_cluster_destinations {
    @cluster_hosts
      ? join( ', ', map { $_->{management_ip} . ":2004" } @cluster_servers )
      : undef;
}
=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
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
