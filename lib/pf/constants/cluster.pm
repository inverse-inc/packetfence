package pf::constants::cluster;

=head1 NAME

pf::constants::cluster - constants for cluster object

=cut

=head1 DESCRIPTION

pf::constants::cluster

=cut

use strict;
use warnings;
use base qw(Exporter);

use pfconfig::constants;
use fingerbank::FilePath;
use pf::file_paths qw(
    $server_cert
    $server_key
    $server_pem
    $radius_server_key
    $radius_server_cert
    $radius_ca_cert
    $conf_dir
    $local_secret_file
    $unified_api_system_pass_file
    $network_behavior_policy_config_file
    $firewalld_config_path_default
    $firewalld_config_path_default_template
    $firewalld_config_path_generated
    $firewalld_config_path_applied
    $firewalld_config_config_file $firewalld_config_config_defaults_file    
    $firewalld_services_config_file $firewalld_services_config_defaults_file
    $firewalld_zones_config_file $firewalld_zones_config_defaults_file
    $firewalld_policies_config_file $firewalld_policies_config_defaults_file
    $firewalld_ipsets_config_file $firewalld_ipsets_config_defaults_file
    $firewalld_icmptypes_config_file $firewalld_icmptypes_config_defaults_file
    $firewalld_helpers_config_file $firewalld_helpers_config_defaults_file
    $firewalld_lockdown_whitelist_config_file $firewalld_lockdown_whitelist_config_defaults_file
);

our @EXPORT_OK = qw(@FILES_TO_SYNC);

our @FILES_TO_SYNC = (
    $server_cert, 
    $server_key, 
    $server_pem, 
    $radius_server_key,
    $radius_server_cert,
    $radius_ca_cert,
    $local_secret_file, 
    $unified_api_system_pass_file,
    $network_behavior_policy_config_file,
    $pfconfig::constants::CONFIG_FILE_PATH,
    $fingerbank::FilePath::CONF_FILE, 
    $fingerbank::FilePath::LOCAL_DB_FILE,
    $firewalld_config_path_default,
    $firewalld_config_path_default_template,
    $firewalld_config_path_generated,
    $firewalld_config_path_applied,
    $firewalld_config_config_file,
    $firewalld_config_config_defaults_file,
    $firewalld_services_config_file,
    $firewalld_services_config_defaults_file,
    $firewalld_zones_config_file,
    $firewalld_zones_config_defaults_file,
    $firewalld_policies_config_file,
    $firewalld_policies_config_defaults_file,
    $firewalld_ipsets_config_file,
    $firewalld_ipsets_config_defaults_file,
    $firewalld_icmptypes_config_file,
    $firewalld_icmptypes_config_defaults_file,
    $firewalld_helpers_config_file,
    $firewalld_helpers_config_defaults_file,
    $firewalld_lockdown_whitelist_config_file,
    $firewalld_lockdown_whitelist_config_defaults_file
);

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

