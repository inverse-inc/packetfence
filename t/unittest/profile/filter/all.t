=head1 NAME

t/profile/filter/all.t

=head1 DESCRIPTION

Test for pf::profile::filter::all module

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
BEGIN {
    use lib qw(/usr/local/pf/t);
    use PfFilePaths;
}

use Test::More tests => 9;                      # last test to print

use Test::NoWarnings;

use_ok("pf::profile::filter::all");
use_ok("pf::profile::filter::key");

my $filter_key1 = new_ok ( "pf::profile::filter::key", [profile => 'Test', value => 'test1', key => 'test1' ],"Test value based filter");
my $filter_key2 = new_ok ( "pf::profile::filter::key", [profile => 'Test', value => 'test2', key => 'test2' ],"Test value based filter");
my $filter = new_ok ( "pf::profile::filter::all", [profile => 'Test', value => [$filter_key1,$filter_key2], ],"Test all profile filter");

ok($filter->match({ test1 => 'test1', test2 => 'test2'}),"all filter matches");

ok(!$filter->match({ test1 => 'test', test2 => 'test'}),"no filter matches");
 
ok(!$filter->match({ test2 => 'test2'}),"fails to match when only one filter matches");
 
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


