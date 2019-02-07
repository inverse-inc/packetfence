#!/usr/bin/perl

=head1 NAME

node - 

=cut

=head1 DESCRIPTION

node

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::node;
use pf::SwitchFactory;
use pf::Connection::ProfileFactory;
use Data::Dumper;
use Benchmark qw(timethis cmpthese);
use CHI::Memoize qw(unmemoize);

my $mac = "00:00:00:00:00:ff";
bench_node_view();
bench_node_exist();
bench_switch_factory();
bench_profile_factory();

sub bench_node_view {
    bench_cache("pf::node::_node_view", sub { my $node = pf::node::node_view($mac) });
}

sub bench_node_exist {
    bench_cache("pf::node::_node_exist", sub { my $node = pf::node::node_exist($mac) });
}

sub bench_switch_factory {
    bench_cache("pf::SwitchFactory::instantiate", sub { my $switch = pf::SwitchFactory->instantiate("192.168.0.1")});
}

sub bench_profile_factory {
    bench_cache("pf::Connection::ProfileFactory::instantiate", sub { my $switch = pf::Portal::ProfileFactory->instantiate($mac)});
}

sub bench_cache {
    my ($func_id, $func, $count) = @_;
    print "\n$func_id\n";
    my %counts;
    $count //= 0;
    $counts{"with caching"} = timethis($count, $func, "with caching");

    unmemoize($func_id);

    $counts{"without caching"} = timethis($count, $func, "without caching");
    cmpthese(\%counts);
}

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

