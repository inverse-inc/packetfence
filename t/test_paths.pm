package test_paths;
=head1 NAME

test_paths

=cut

=head1 DESCRIPTION

test_paths
Overrides the the location of config files to help with testing

=cut

use strict;
use warnings;


our $PFCONFIG_TEST_PID_FILE;
our $test_dir;

BEGIN {
    use File::Spec::Functions qw(catfile catdir rel2abs);
    use File::Basename qw(dirname);
    use pf::file_paths;
    use pfconfig::constants;

    $test_dir = rel2abs(dirname($INC{'setup_test_config.pm'})) if exists $INC{'setup_test_config.pm'};
    $test_dir ||= catdir($install_dir,'t');
    $pf::file_paths::switches_config_file = catfile($test_dir,'data/switches.conf');
    $pf::file_paths::admin_roles_config_file = catfile($test_dir,'data/admin_roles.conf');
    $pf::file_paths::chi_config_file = catfile($test_dir,'data/chi.conf');
    $pf::file_paths::profiles_config_file = catfile($test_dir,'data/profiles.conf');
    $pf::file_paths::authentication_config_file = catfile($test_dir,'data/authentication.conf');
    $pf::file_paths::log_config_file = catfile($test_dir,'log.conf');
    $pf::file_paths::vlan_filters_config_file = catfile($test_dir,'data/vlan_filters.conf');
    $pf::file_paths::violations_config_file = catfile($test_dir,'data/violations.conf');
    $pf::file_paths::firewall_sso_config_file = catfile($test_dir,'data/firewall_sso.conf');
    $pf::file_paths::config_file = catfile($test_dir,'data/pf.conf');
    $pf::file_paths::pf_config_file = catfile($test_dir,'data/pf.conf');
    
    $pfconfig::constants::CONFIG_FILE_PATH = catfile($test_paths::test_dir, 'data/pfconfig.conf');
    $pfconfig::constants::SOCKET_PATH = "/usr/local/pf/var/run/pfconfig-test.sock";


}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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


