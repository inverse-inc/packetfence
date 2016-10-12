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
use Data::Dumper;
use Benchmark qw(timethis cmpthese);
use CHI::Memoize qw(unmemoize);
my %counts;

{
    print "\nnode_view\n";

    $counts{"with caching"} = timethis(0,sub { my $node = pf::node::node_view("00:00:00:00:00:ff") }, "with caching");

    unmemoize("pf::node::node_view");

    $counts{"without caching"} = timethis(0,sub { my $node = pf::node::node_view("00:00:00:00:00:ff") }, "without caching");

    cmpthese(\%counts);
}

{
    %counts = ();

    print "\nnode_exist\n";

    $counts{"with caching"} = timethis(0,sub { my $node = pf::node::node_exist("00:00:00:00:00:ff") }, "with caching");

    unmemoize("pf::node::node_exist");

    $counts{"without caching"} = timethis(0,sub { my $node = pf::node::node_exist("00:00:00:00:00:ff") }, "without caching");

    cmpthese(\%counts);
}

{
    %counts = ();

    my $switch = pf::SwitchFactory->instantiate("192.168.0.1");

    print "\npf::SwitchFactory->instantiate\n";

    $counts{"with caching"} = timethis(0, sub { my $switch = pf::SwitchFactory->instantiate("192.168.0.1")}, "with caching");

    unmemoize("pf::SwitchFactory::instantiate");

    $counts{"without caching"} = timethis(0, sub { my $switch = pf::SwitchFactory->instantiate("192.168.0.1")}, "without caching");

    cmpthese(\%counts);
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

