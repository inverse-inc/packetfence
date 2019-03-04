#!/usr/bin/perl

=head1 NAME

pfconfig::cached_array

=cut

=head1 DESCRIPTION

pfconfig::cached_array

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use setup_test_config;
}

use Test::More tests => 13;                      # last test to print

use Test::NoWarnings;

##
# Test cached_array
my @array_test;
tie @array_test, 'pfconfig::cached_array', 'resource::array_test';

ok(@array_test eq 3, "test array test is valid");

my @array_test_result = ("first", "second", "third");

is_deeply(\@array_test, \@array_test_result, "test arrays are the same");

##
# Test FETCH

foreach my $i (0..2){
  is($array_test[$i], $array_test_result[$i],
    "Fetching element $i gives the right result");
}

ok(!defined($array_test[3]),
  "Fetching an inexistant element gives undef");

is(@array_test, 3,
  "Fetching size of array gives the right result");

##
# Test exists in array

ok(exists($array_test[0]), "First element exists");
ok(exists($array_test[1]), "Second element exists");
ok(exists($array_test[2]), "Third element exists");
ok(!exists($array_test[3]), "Fourth element doesn't exists");
ok(exists($array_test[-1]), "-1 element exists");

 
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


