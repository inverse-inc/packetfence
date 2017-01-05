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

BEGIN {
    use test_paths;
    use pfconfig::constants;
    use File::Spec::Functions qw(catfile);
    use File::Slurp qw(read_file);

    use File::Path qw(remove_tree);
    remove_tree('/tmp/chi');

    `/usr/local/pf/t/pfconfig-test`;

    use pf::db;
    # Setup database connection infos based on ENV variables if they are defined
    $pf::db::DB_Config->{host} = $ENV{PF_TEST_DB_HOST} // $pf::db::DB_Config->{host};
    $pf::db::DB_Config->{user} = $ENV{PF_TEST_DB_USER} // $pf::db::DB_Config->{user};
    $pf::db::DB_Config->{pass} = $ENV{PF_TEST_DB_PASS} // $pf::db::DB_Config->{pass};
    $pf::db::DB_Config->{db}   = $ENV{PF_TEST_DB_NAME} // $pf::db::DB_Config->{db};
    $pf::db::DB_Config->{port} = $ENV{PF_TEST_DB_PORT} // $pf::db::DB_Config->{port};

    use pf::config qw(
        %Config
        $management_network
    );
    # Setup IP and VIP of management network
    if(defined($ENV{PF_TEST_MGMT_INT})){
        my $section_name = "interface ".$ENV{PF_TEST_MGMT_INT};
        $Config{$section_name}{ip} = $ENV{PF_TEST_MGMT_IP} // $pf::config::Config{$section_name}{ip};
        $Config{$section_name}{vip} = $ENV{PF_TEST_MGMT_IP} // $pf::config::Config{$section_name}{vip};
        $Config{$section_name}{mask} = $ENV{PF_TEST_MGMT_MASK} // $pf::config::Config{$section_name}{mask};
        $management_network->tag('ip', $Config{$section_name}{ip});
        $management_network->tag('vip', $Config{$section_name}{vip});
    }
}

END {
    my $pid = read_file($test_paths::PFCONFIG_TEST_PID_FILE);
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

