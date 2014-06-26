package PfFilePath;
=head1 NAME

PfFilePath

=cut

=head1 DESCRIPTION

PfFilePath
Overrides the the location of config files to help with testing

=cut

use strict;
use warnings;

BEGIN {
    use File::Path qw(remove_tree);
    use pf::file_paths;
    remove_tree('/tmp/chi');
    $pf::file_paths::switches_config_file = './data/switches.conf';
    $pf::file_paths::chi_config_file = './data/chi.conf';
    $pf::file_paths::profiles_config_file = './data/profiles.conf';
    $pf::file_paths::authentication_config_file = './data/authentication.conf';
    $pf::file_paths::log_config_file = './log.conf';
    $pf::file_paths::vlan_filters_config_file = './data/vlan_filters.conf';
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

