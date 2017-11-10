#!/usr/bin/perl

=head1 NAME

query_filters

=cut

=head1 DESCRIPTION

unit test for query_filters

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 21;
use pf::generate_filter qw(generate_filter);

#This test will running last
use Test::NoWarnings;

my $filter = generate_filter("equal", "param1", "value1");
ok ($filter->({"param1" => "value1"}), "equal filter succeeds");
ok (!$filter->({"param1" => "value2"}), "equal filter should fail");
ok (!$filter->({"param2" => "value1"}), "equal filter should fail");
ok (!$filter->(undef), "equal filter should fail");

my $not_filter = generate_filter("not_equal", "param1", "value1");

ok (!$not_filter->({"param1" => "value1"}), "not_equal filter value1!=value1");
ok ($not_filter->({"param1" => "value2"}), "not_equal filter  value1!=value2");
ok (!$not_filter->({"param2" => "value1"}), "not_equal filter should fail");
ok (!$not_filter->(undef), "not_equal filter should fail");

my $starts_with_filter = generate_filter("starts_with", "param1", "v");
ok ($starts_with_filter->({"param1" => "value1"}), "starts_with filter succeeds");
ok (!$starts_with_filter->({"param1" => "avalue2"}), "starts_with filter should fail");
ok (!$starts_with_filter->({"param2" => "value1"}), "starts_with filter should fail");
ok (!$starts_with_filter->(undef), "starts_with filter should fail");

my $ends_with_filter = generate_filter("ends_with", "param1", "1");
ok ($ends_with_filter->({"param1" => "value1"}), "ends_with filter succeeds");
ok (!$ends_with_filter->({"param1" => "avalue"}), "ends_with filter should fail");
ok (!$ends_with_filter->({"param2" => "value1"}), "ends_with filter should fail");
ok (!$ends_with_filter->(undef), "ends_with filter should fail");

my $like_filter = generate_filter("like", "param1", "v");
ok ($like_filter->({"param1" => "value1"}), "like filter succeeds");
ok (!$like_filter->({"param1" => "aalue2"}), "like filter should fail");
ok (!$like_filter->({"param2" => "value1"}), "like filter should fail");
ok (!$like_filter->(undef), "like filter should fail");

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
