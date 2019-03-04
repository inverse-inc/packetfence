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
    use test_paths;
    use setup_test_config;
}

use Test::More tests => 10;                      # last test to print

use Test::NoWarnings;

use_ok("pfconfig::memory_cached");
use_ok("pfconfig::manager");

my $testkey = "testkey";
my $testns = "testns";
my $testns2 = "testns2";

my $mem = pfconfig::memory_cached->new($testns);

my $manager = pfconfig::manager->new();
$manager->touch_cache($testns);
$manager->touch_cache($testns2);

my $result;

$result = $mem->compute_from_subcache($testkey, sub {"dinde"});
is($result, "dinde", 
    "Computing should return proper value");

$result = $mem->compute_from_subcache($testkey, sub {"that-would-be-bad"});
is($result, "dinde", 
    "Computing should return cached value if namespace hasn't expired");

$manager->touch_cache($testns);

$result = $mem->compute_from_subcache($testkey, sub {"value changed !"});
is($result, "value changed !", 
    "Value is properly recompute_from_subcached when namespace expired.");

$mem = pfconfig::memory_cached->new($testns, $testns2);

$result = $mem->compute_from_subcache($testkey, sub {"dinde"});
is($result, "dinde", 
    "Computing should return proper value");

$result = $mem->compute_from_subcache($testkey, sub {"that-would-be-bad"});
is($result, "dinde", 
    "Computing should return cached value if no namespace has expired in the namespace list");

$manager->touch_cache($testns);

$result = $mem->compute_from_subcache($testkey, sub {"value changed !"});
is($result, "value changed !", 
    "Value is properly recompute_from_subcached when one of the namespaces expired.");

$manager->touch_cache($testns2);

$result = $mem->compute_from_subcache($testkey, sub {"value changed again !"});
is($result, "value changed again !", 
    "Value is properly recompute_from_subcached when on of the namespaces expired.");


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



