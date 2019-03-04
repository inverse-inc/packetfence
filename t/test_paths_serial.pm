package test_paths_serial;

=head1 NAME

test_paths

=cut

=head1 DESCRIPTION

test_paths
Overrides the the location of config files to help with testing

=cut

use strict;
use warnings;


BEGIN {
    use test_paths;
    use File::Spec::Functions qw(catfile catdir rel2abs);
    use File::Basename qw(dirname);
    use pf::file_paths qw($install_dir);
    use pfconfig::constants;
    $test_paths::PFCONFIG_TEST_PID_FILE = "/usr/local/pf/var/run/pfconfig-test-serial.pid";
    $pfconfig::constants::CONFIG_FILE_PATH = catfile($test_paths::test_dir, 'data/pfconfig-serial.conf');
    $test_paths::PFCONFIG_RUNNER = catfile($test_paths::test_dir, 'pfconfig-test-serial');
    $pfconfig::constants::SOCKET_PATH = catfile($install_dir, "var/run/pfconfig-test-serial.sock");

}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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


