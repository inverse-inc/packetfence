#!/usr/bin/perl
=head1 NAME

pfconfig::memory_cached

=cut

=head1 DESCRIPTION

pfconfig::memory_cached

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use setup_test_config;
}

use Test::More tests => 6;                      # last test to print

use Test::NoWarnings;

use_ok("pfconfig::memory_cached");
use_ok("pfconfig::manager");

my $testkey = "testkey";
my $testns = "testns";

my $mem = pfconfig::memory_cached->new($testns);

my $manager = pfconfig::manager->new();
$manager->touch_cache($testns);

my $result;

$result = $mem->compute($testkey, sub {"dinde"});
is($result, "dinde", 
    "Computing should return proper value");

$result = $mem->compute($testkey, sub {"that-would-be-bad"});
is($result, "dinde", 
    "Computing should return cached value if namespace hasn't expired");

$manager->touch_cache($testns);

$result = $mem->compute($testkey, sub {"value changed !"});
is($result, "value changed !", 
    "Value is properly recomputed when namespace expired.");

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



