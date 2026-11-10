#!/usr/bin/perl

=head1 NAME

scan

=head1 DESCRIPTION

unit test for pf::scan

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 9;

#This test will running last
use Test::NoWarnings;
use pf::scan;

my $any = bless { _categories => [] }, 'pf::scan';
my $default_only = bless { _categories => ['default'] }, 'pf::scan';
my $guest_only = bless { _categories => ['guest'] }, 'pf::scan';

ok($any->matchCategory({ category => undef }), 'scanner without roles matches a node without role');
ok($any->matchCategory({ category => 'guest' }), 'scanner without roles matches any role');

ok($default_only->matchCategory({ category => undef }), 'node without role is considered default');
ok($default_only->matchCategory({ category => '' }), 'node with an empty role is considered default');
ok($default_only->matchCategory({ category => 'default' }), 'default role matches');
ok(!$default_only->matchCategory({ category => 'guest' }), 'other role does not match');

ok(!$guest_only->matchCategory({ category => undef }), 'node without role does not match a scanner limited to other roles');
ok($guest_only->matchCategory({ category => 'guest' }), 'node with the role matches');

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
