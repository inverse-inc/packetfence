package pf::config::cluster;

=head1 NAME

pf::config::cluster

=cut

=head1 DESCRIPTION

Module to get basic configuration about the cluster without any dependencies to pfconfig

=cut


use strict;
use warnings;

use Exporter;
our ( @ISA, @EXPORT );
@ISA = qw(Exporter);
@EXPORT = qw($cluster_enabled $multi_zone_enabled $host_id $master_multi_zone $zone_dbs_only);

use pf::log;
use File::Slurp qw(read_file write_file);
use pf::util;
use pf::file_paths qw($cluster_config_file);
use pf::IniFiles;
use Sys::Hostname;
use pf::constants qw($TRUE $FALSE);
use pf::file_paths qw(
    $config_version_file
);

our $multi_zone_enabled = sub {
    my $cfg = cluster_ini_config();
    return $FALSE unless($cfg);
    my $multi_zone = $cfg->val('general', 'multi_zone');
    
    return isenabled($multi_zone);
}->();

our $zone_dbs_only = sub {
    my $cfg = cluster_ini_config();
    return $FALSE unless($cfg);
    my $val = $cfg->val('general', 'zone_dbs_only');
    
    return isenabled($val);
}->();

our $cluster_enabled = sub {
    return $TRUE if $multi_zone_enabled;

    my $cfg = cluster_ini_config();
    return $FALSE unless($cfg);
    my $mgmt_ip = $cfg->val('CLUSTER', 'management_ip');
    if (defined($mgmt_ip) && valid_ip($mgmt_ip)) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}->();

our $master_multi_zone = sub {
    my $cfg = cluster_ini_config();
    return $FALSE unless($cfg);
    my $multi_zone = $cfg->val('general', 'multi_zone');

    if (isenabled($multi_zone)) {
        foreach my $section ($cfg->Sections()) {
            if ($section =~ /^(\w+)\s+CLUSTER/) {
                return $1;
            }
        }
    }
    return 'DEFAULT';
}->();

# Set a consistent host_id unless we're in a cluster
# This is to prevent the pfconfig resource overlays for containers that keep having different hostnames
# TODO: when we start working on the containerization in a cluster, we need to have hostname() replaced with the hostname of the physical machine in the cluster
our $host_id = $cluster_enabled ? hostname() : '';

=head2 cluster_ini_config

Get the cluster.conf pf::IniFiles object

=cut

sub cluster_ini_config {
    my $cfg = pf::IniFiles->new( -file => $cluster_config_file, -envsubst => 1 );
    return $cfg;
}

=head2 increment_config_version

=cut

sub increment_config_version {
    return set_config_version(time);
}

=head2 set_config_version

Set the configuration version for this server

=cut

sub set_config_version {
    my ($ver) = @_;
    my $old_umask = umask(0002);
    my $results = write_file($config_version_file, { perms => 0666}, $ver);
    umask($old_umask);
    return $results;
}

=head2 get_config_version

Get the configuration version for this server

=cut

sub get_config_version {
    my $result;
    eval {
        $result = read_file($config_version_file);
    };
    if($@) {
        get_logger->error("Cannot read $config_version_file to get the current configuration version.");
        return $FALSE;
    }
    return $result;
}

=head2

Get the configuration of a specific cluster

=cut

sub getClusterConfig {
    my ($cluster_name) = @_;
    my %cluster_servers;

    if ($cluster_enabled) {
        tie %cluster_servers, 'pfconfig::cached_hash', "config::Cluster($cluster_name)";

        return \%cluster_servers;
    }
    return {};
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
