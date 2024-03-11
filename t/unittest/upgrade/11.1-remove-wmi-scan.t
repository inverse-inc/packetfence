#!/usr/bin/perl

=head1 NAME

o-11.1-remove-unused-sources

=head1 DESCRIPTION

unit test for o-11.1-remove-unused-sources

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::file_paths qw($install_dir);
require "$install_dir/addons/upgrade/to-11.1-remove-wmi-scan.pl";
use Test::More tests => 6;

our @expected_wmi_scan_engines = qw(wmi1 wmi2);
#This test will running last
use Test::NoWarnings;
{
    my ($cs, $removed) = removeWmiScanEngine("$install_dir/t/data/update-11.1/scan.conf");
    ok ($cs, "cs remove");
    is_deeply($removed, \@expected_wmi_scan_engines, "remove the correct scan engines");
    is_deeply([$cs->Sections()] ,[qw(scan1 scan2)], "proper sections are kept");
}

{
    my $cs = updateProfile(
        "$install_dir/t/data/update-11.1/profiles-wmi.conf",
        \@expected_wmi_scan_engines
    );

    ok($cs, "Profiles updated");
    is($cs->val('p1', 'scans'), 'bob', "Remove the proper scan engines");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

