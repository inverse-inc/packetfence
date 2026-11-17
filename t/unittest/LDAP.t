#!/usr/bin/perl

=head1 NAME

LDAP

=head1 DESCRIPTION

unit test for pf::LDAP

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 4;

#This test will running last
use Test::NoWarnings;
use pf::LDAP;

my @keys = map { "key$_" } 1 .. 20;
my %a = map { ($_ => $_) } @keys;
my %b = map { ($_ => $_) } reverse @keys;

is_deeply(
    pf::LDAP::cache_key('ldap.example.com', \%a),
    pf::LDAP::cache_key('ldap.example.com', \%b),
    "Same arguments give the same cache key regardless of hash order",
);

is_deeply(
    pf::LDAP::cache_key('ldap.example.com', { port => 636, encryption => 'ssl' }),
    ['ldap.example.com', encryption => 'ssl', port => 636],
    "Cache key lists the arguments sorted by name",
);

{
    # compute_connection deletes from %args, so the key must not depend on it afterwards
    my $connects = 0;
    no warnings 'redefine';
    local *pf::LDAP::compute_connection = sub {
        my ($class, $server, $args) = @_;
        delete @$args{qw(encryption read_timeout write_timeout start_tls_options)};
        $connects++;
        return "connection";
    };
    local *pf::LDAP::expire_if = sub { 0 };
    pf::LDAP->new(
        'ldap.example.com',
        credentials => ['cn=bind', password => 'secret'],
        port => 636, encryption => 'ssl', timeout => 1, read_timeout => 10,
        write_timeout => 5, verify => 'none', start_tls_options => { verify => 'none' },
    ) for 1 .. 100;
    is($connects, 1, "Cached connection is reused for identical arguments");
    $pf::LDAP::CHI_CACHE->clear;
}

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
