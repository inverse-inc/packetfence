#!/usr/bin/perl

=head1 NAME

redis-memcached-chi-benchmark -

=cut

=head1 DESCRIPTION

redis-memcached-chi-benchmark

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use CHI;
use Cache::Memcached;
use Redis::Fast;
use Redis;
use CHI::Driver::Redis;
use CHI::Driver::Memcached;
use Redis::hiredis;
use Benchmark qw(timethese cmpthese);

my $chi_redis = CHI->new(
    driver      => 'Redis',
    redis_class => 'Redis::Fast',
    on_get_error => 'die',
    on_set_error => 'die',
);

my $chi_redis_sock = CHI->new(
    driver      => 'Redis',
    redis_class => 'Redis::Fast',
    sock => '/usr/local/pf/var/run/redis_cache.sock',
    on_get_error => 'die',
    on_set_error => 'die',
);

my $chi_memcached = CHI->new(driver => 'Memcached',
    on_get_error => 'die',
    on_set_error => 'die',
    servers => [qw(127.0.0.1:11211)],
);

my $redis = Redis::Fast->new;
my $redis_sock = Redis::Fast->new(sock => '/usr/local/pf/var/run/redis_cache.sock');

my $memcached = Cache::Memcached->new({servers => [qw(127.0.0.1:11211)]});

my $results = timethese(
    0,
    {
        "Chi::Redis Set" => make_set_test($chi_redis),
        "Chi::Redis Set Sock" => make_set_test($chi_redis_sock),
        "Chi::Memcached Set" => make_set_test($chi_memcached),
        "Redis::Fast Set" => make_set_test($redis),
        "Redis::Fast Sock Set" => make_set_test($redis_sock),
        "Memcached Set" => make_set_test($memcached),
    }
);

print "\n";

cmpthese($results);

print "\n";

$results = timethese(
    0,
    {
        "Chi::Redis Get" => make_get_test($chi_redis),
        "Chi::Redis Get Sock" => make_get_test($chi_redis_sock),
        "Chi::Memcached Get" => make_get_test($chi_memcached),
        "Redis::Fast Get" => make_get_test($redis),
        "Redis::Fast Sock Get" => make_get_test($redis_sock),
        "Memcached Get" => make_get_test($memcached),
    }
);

print "\n";

cmpthese($results);

sub make_set_test {
    my $cache = shift;
    my $i = 0;
    return sub {
        $cache->set($i,"1" x 1024);
    };
}

sub make_get_test {
    my $cache = shift;
    my $i = 0;
    return sub {
        $cache->get($i++);
    };
}

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

