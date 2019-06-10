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
@EXPORT = qw($cluster_enabled $multi_zone_enabled $host_id);

use pf::log;
use File::Slurp qw(read_file write_file);
use pf::util;
use pf::file_paths qw($cluster_config_file);
use Config::IniFiles;
use Sys::Hostname;
use pf::constants qw($TRUE $FALSE);
use pf::file_paths qw(
    $config_version_file
);

our $host_id = hostname();

our $multi_zone_enabled = sub {
    my $cfg = cluster_ini_config();
    return $FALSE unless($cfg);
    my $multi_zone = $cfg->val('general', 'multi_zone');
    
    return isenabled($multi_zone);
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

=head2 cluster_ini_config

Get the cluster.conf Config::IniFiles object

=cut

sub cluster_ini_config {
    my $cfg = Config::IniFiles->new( -file => $cluster_config_file );
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
    my $results = write_file($config_version_file, { perms => 0660}, $ver);
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


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
