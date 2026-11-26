#!/usr/bin/perl

=head1 NAME

namespace_names

=head1 DESCRIPTION

pfconfig only loads namespaces whose name is a Perl package name; other
names are refused before any module is loaded or any cache entry is touched.

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use test_paths;
}

use Test::More tests => 30;
use Test::NoWarnings;

use pfconfig::util qw(is_valid_namespace);
use pfconfig::manager;

my @valid = (
    'config::Pf',
    'config::Pf()',
    'config::Pf(CLUSTER,pf1.example.com)',
    'resource::passthroughs',
    'interfaces::listen_ints',
    '_private::Name_2',
);

my @invalid = (
    undef,
    '',
    'X::;$main::hit=1;1',
    'config::Pf->VERSION;$main::hit=1;1',
    'config::Pf;system("true")',
    'a/b',
    '../config::Pf',
    '::config::Pf',
    'config::',
    '1config::Pf',
    'config::Pf ',
    "config::Pf\n",
    'config::Pf-x',
    "config::Pf\x{e9}",
);

ok(is_valid_namespace($_), "'$_' is a valid namespace") for @valid;
ok(!is_valid_namespace($_), "'" . ($_ // 'undef') . "' is not a valid namespace") for @invalid;

# A manager that records what it would load or build instead of doing it
{
    package test_manager;
    our @ISA = ('pfconfig::manager');
    our @TOUCHED;
    sub new { bless { memory => {}, memorized_at => {} }, shift }
    sub is_valid { my ($self, $what) = @_; push @TOUCHED, "is_valid:$what"; 0 }
    sub cache_resource { my ($self, $what) = @_; push @TOUCHED, "cache_resource:$what"; undef }
    sub is_overlayed_namespace { 0 }
    sub overlayed_namespaces { () }
}

my $manager = test_manager->new;
our $hit;

for my $name ('X::;$main::hit=1;1', 'config::Pf->VERSION;$main::hit=1;1') {
    @test_manager::TOUCHED = ();
    is($manager->get_namespace($name), undef, "get_namespace refuses '$name'");
    is($manager->get_cache($name), undef, "get_cache refuses '$name'");
    is($manager->get_cache_ordered($name), undef, "get_cache_ordered refuses '$name'");
    $manager->expire($name);
    is_deeply(\@test_manager::TOUCHED, [], "nothing is loaded or built for '$name'");
}

ok(!$hit, "no code from a namespace name was run");

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
