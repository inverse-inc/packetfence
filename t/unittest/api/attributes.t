=head1 NAME

api

=cut

=head1 DESCRIPTION

api

=cut

package api::test;
use lib qw(/usr/local/pf/lib);
use base qw(pf::api::attributes);
sub isAPublicFunction :Public {}
sub isAPublicFunction2 :Public {}
sub isAPrivateFunction {}
sub anotherFunction {}

package api::test2;
use base qw(api::test);
sub anotherFunction : Public {}
sub isAPublicFunction2 {}



use threads;
use strict;
use warnings;

use Test::More tests => 17;                      # last test to print

use Test::NoWarnings;

ok(api::test->isPublic("isAPublicFunction"),"isAPublicFunction is public");
ok(api::test->isPublic("isAPublicFunction2"),"isAPublicFunction2 is public");
ok(!api::test->isPublic("isAPrivateFunction"),"isAPrivateFunction is private");
ok(!api::test->isPublic("anotherFunction"),"anotherFunction is private");
ok(api::test2->isPublic("isAPublicFunction"),"isAPublicFunction is public sub class");
ok(!api::test2->isPublic("isAPrivateFunction"),"isAPrivateFunction is private sub class");
ok(api::test2->isPublic("anotherFunction"),"anotherFunction is public");
ok(!api::test2->isPublic("isAPublicFunction2"),"isAPublicFunction2 is not public anymore");
my $thr = threads->create(
    {'context' => 'list'},
    sub {
        ok(api::test->isPublic("isAPublicFunction"),"isAPublicFunction is public in a thread");
        ok(api::test->isPublic("isAPublicFunction2"),"isAPublicFunction2 is public in a thread");
        ok(!api::test->isPublic("isAPrivateFunction"),"isAPrivateFunction is private in a thread");
        ok(!api::test->isPublic("anotherFunction"),"anotherFunction is private");
        ok(api::test2->isPublic("isAPublicFunction"),"isAPublicFunction is public sub class in a thread");
        ok(!api::test2->isPublic("isAPrivateFunction"),"isAPrivateFunction is private sub class in a thread");
        ok(api::test2->isPublic("anotherFunction"),"anotherFunction is public in a thread");
        ok(!api::test2->isPublic("isAPublicFunction2"),"isAPublicFunction2 is not public anymore in a thread");
    }
);


$thr->join();

 
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


