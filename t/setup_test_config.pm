package setup_test_config;
=head1 NAME

setup_test_config

=cut

=head1 DESCRIPTION

setup_test_config
Setups the configuration for the testing environment

=cut

use strict;
use warnings;


our $PFCONFIG_TEST_PID_FILE;

BEGIN {
    use test_paths;
    use pfconfig::manager;
    use pfconfig::constants;
    use File::Spec::Functions qw(catfile);
    use File::Slurp qw(read_file);

    use File::Path qw(remove_tree);
    remove_tree('/tmp/chi');

    $PFCONFIG_TEST_PID_FILE = "/usr/local/pf/var/run/pfconfig-test.pid";
    `/usr/local/pf/sbin/pfconfig -s $pfconfig::constants::SOCKET_PATH -p $PFCONFIG_TEST_PID_FILE -c $pfconfig::constants::CONFIG_FILE_PATH -d`;

    my $manager = pfconfig::manager->new;
    $manager->expire_all;
}
 
END {
    my $pid = read_file($PFCONFIG_TEST_PID_FILE);
    `kill $pid`
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

