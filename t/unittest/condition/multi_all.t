#!/usr/bin/perl

=head1 NAME

Tests for pf::condition::all

=cut

=head1 DESCRIPTION

Tests for pf::condition::all

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';
use Test::More tests => 9;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}


#This test will running last
use Test::NoWarnings;
use pf::condition::multi_all;
use pf::condition::false;
use pf::condition::true;

{

    my $condition1 = pf::condition::multi_all->new(
        condition => pf::condition::false->new,
    );
    my $condition2 = pf::condition::multi_all->new(
        condition => pf::condition::true->new,
    );
    ok(!$condition1->match([1..10]));
    ok(!$condition1->match([]));
    ok($condition2->match([1..10]));
    ok(!$condition2->match([]));
}

{

    my $condition1 = pf::condition::multi_all->new(
        condition => pf::condition::false->new,
        match_on_empty => 1,
    );
    my $condition2 = pf::condition::multi_all->new(
        condition => pf::condition::true->new,
        match_on_empty => 1,
    );
    ok(!$condition1->match([1..10]));
    ok($condition1->match([]));
    ok($condition2->match([1..10]));
    ok($condition2->match([]));
}

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


