#!/usr/bin/perl

=head1 NAME

api

=cut

=head1 DESCRIPTION

api

=cut

{
package api::test;
use lib qw(/usr/local/pf/lib);
use base qw(pf::api::attributes);
sub isAPublicFunction :Public {}
sub isAPublicFunction2 :Public {}
sub isAForkFunction :Public :Fork {}
sub isAForkFunction2 :Public :Fork {}
sub isaRest : Public :RestPath(/path) {}
sub isAPrivateFunction {}
sub anotherFunction {}
}

{
package api::test2;
use base qw(api::test);
sub anotherFunction : Public {}
sub isAPublicFunction2 {}
sub isAForkFunction2 {}
}

use threads;
use strict;
use warnings;

use Test::More tests => 1 + 2 * (13);                      # last test to print

use Test::NoWarnings;

sub full_tests {
    ok(api::test->isPublic("isAPublicFunction"),    "isAPublicFunction is public");
    ok(api::test->isPublic("isAPublicFunction2"),   "isAPublicFunction2 is public");
    ok(!api::test->isPublic("isAPrivateFunction"),  "isAPrivateFunction is private");
    ok(ref(api::test->restPath("/path")) eq 'CODE', "/path is a rest path");
    ok(!defined api::test->restPath("/path/"),      "/path/ is not a rest path");
    ok(!api::test->isPublic("anotherFunction"),     "anotherFunction is private");
    ok(api::test2->isPublic("isAPublicFunction"),   "isAPublicFunction is public sub class");
    ok(!api::test2->isPublic("isAPrivateFunction"), "isAPrivateFunction is private sub class");
    ok(api::test2->isPublic("anotherFunction"),     "anotherFunction is public");
    ok(!api::test2->isPublic("isAPublicFunction2"), "isAPublicFunction2 is not public anymore");
    ok(api::test->shouldFork("isAForkFunction"),    "isAForkFunction should fork");
    ok(api::test->shouldFork("isAForkFunction2"),   "isAForkFunction2 should fork");
    ok(!api::test2->shouldFork("isAForkFunction2"), "isAForkFunction is not forkable anymore");
}

full_tests();

my $thr = threads->create(
    {'context' => 'list'},
    \&full_tests,
);

$thr->join();

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


