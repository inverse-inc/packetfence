#!/usr/bin/perl
=head1 NAME

pfconfig::cached

=cut

=head1 DESCRIPTION

pfconfig::cached

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use setup_test_config;
}

use Test::More tests => 21;                      # last test to print

use Test::NoWarnings;

use_ok("pfconfig::cached");
use_ok("pfconfig::manager");
use_ok("pfconfig::util");

my $cached_test = pfconfig::cached->new();
$cached_test->{_namespace} = 'testing()';
$cached_test->{"_control_file_path"} = pfconfig::util::control_file_path("testing()");

my $manager = pfconfig::manager->new();
$manager->touch_cache('testing');

# test get_from_subcache
is(undef, $cached_test->get_from_subcache('dinde'),
    "subcache is empty and thus invalid so it shouldn't hit");

$cached_test->set_in_subcache('dinde', 'turkey');

is('turkey', $cached_test->get_from_subcache('dinde'), 
    "Can get from subcache when it's set and valid");

is(undef, $cached_test->get_from_subcache('dinde2'),
    "Cannot get unset subcache key even when it exists");

$manager->touch_cache('testing');

is(undef, $cached_test->get_from_subcache('dinde'),
    "Subcache is invalidated when cache is");

$cached_test->set_in_subcache('dinde', 'turkey');

is('turkey', $cached_test->get_from_subcache('dinde'),
    "Subcache can be properly repopulated after expiration");

$cached_test->set_in_subcache('dinde', 'dindo');

is('dindo', $cached_test->get_from_subcache('dinde'),
    "Subcache values can be changed");

$manager->touch_cache('testing');

# test compute_from_subcache with a value

my $hits = 0;

is('turkey', $cached_test->compute_from_subcache('dinde', sub { $hits++ ; return 'turkey' }),
    "Computing a value works");

is(1, $hits,
    "Computing an uncomputed value increments the hits");

is('turkey', $cached_test->compute_from_subcache('dinde', sub { $hits++ ; return 'turkey' }),
    "Re-Computing a value works");

is('turkey', $cached_test->compute_from_subcache('dinde', sub { $hits++ ; return 'turkied' }),
    "Re-Computing a value with a different sub while it's not expired gives subcache");

is(1, $hits,
    "Recomputing an computed value doesn't increments the hits");
 
$manager->touch_cache('testing');

is('turkied', $cached_test->compute_from_subcache('dinde', sub { $hits++ ; return 'turkied' }),
    "Computing a value works with a different sub after it's expired works");

is(2, $hits,
    "Recomputing an expired value increments the hits");

$manager->touch_cache('testing');

# test compute_from_subcache with the undef handling

$hits = 0;

is(undef, $cached_test->compute_from_subcache('dinde', sub { $hits++; return undef }),
    "Computing undef should return undef");

is(1, $hits,
    "Computing an uncomputed value increments the hits");

is(undef, $cached_test->compute_from_subcache('dinde', sub { $hits++; return undef}),
    "Computing undef should return undef even when already computed");

is(1, $hits,
    "Recomputing an computed value doesn't increments the hits when computing undef");
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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


