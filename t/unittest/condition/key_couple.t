=head1 NAME

profile/filter/value.t

=cut

=head1 DESCRIPTION

value

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
BEGIN {
    use lib qw(/usr/local/pf/t);
    use PfFilePaths;
}

use Test::More tests => 10;                      # last test to print

use Test::NoWarnings;

use_ok("pf::condition::key_couple");

my $filter = new_ok ( "pf::condition::key_couple", [ value => 'value1-value2', key1 => 'key1', key2 => 'key2' ],"Test value based filter");

ok($filter->match({ key1 => 'value1', key2 => 'value2'}),"filter matches");

ok(!$filter->match({ key1 => 'value1', key2 => 'value1'}),"key1 matches but not key2");

ok(!$filter->match({ key1 => 'value2', key2 => 'value2'}),"key2 matches but not key1");

ok(!$filter->match({ key3 => 'value3'}),"key1 or key2 does not exists in hash");

ok(!$filter->match({ key1 => undef, key2 => undef }),"key1 and key2 are undef");

ok(!$filter->match({ key1 => 'value1', key2 => undef }),"key1 matches but key2 is undef");

ok(!$filter->match({ key1 => undef, key2 => 'value2' }),"key2 matches but key1 is undef");

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


