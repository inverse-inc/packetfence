package PfFilePaths;
=head1 NAME

PfFilePaths

=cut

=head1 DESCRIPTION

PfFilePaths
Overrides the the location of config files to help with testing

=cut

use strict;
use warnings;

BEGIN {
    use File::Path qw(remove_tree);
    use File::Spec::Functions qw(catfile catdir rel2abs);
    use File::Basename qw(dirname);
    use pf::file_paths;
    remove_tree('/tmp/chi');
    my $test_dir = rel2abs(dirname($INC{'PfFilePaths.pm'})) if exists $INC{'PfFilePaths.pm'};
    $test_dir ||= catdir($install_dir,'t');
    $pf::file_paths::switches_config_file = catfile($test_dir,'data/switches.conf');
    $pf::file_paths::admin_roles_config_file = catfile($test_dir,'data/admin_roles.conf');
    $pf::file_paths::chi_config_file = catfile($test_dir,'data/chi.conf');
    $pf::file_paths::profiles_config_file = catfile($test_dir,'data/profiles.conf');
    $pf::file_paths::authentication_config_file = catfile($test_dir,'data/authentication.conf');
    $pf::file_paths::log_config_file = catfile($test_dir,'log.conf');
    $pf::file_paths::vlan_filters_config_file = catfile($test_dir,'data/vlan_filters.conf');
}

# we need to load the proper data in pfconfig
use pfconfig::manager;
pfconfig::manager->new->expire_all;

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

