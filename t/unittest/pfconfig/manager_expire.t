#!/usr/bin/perl

=head1 NAME

manager_expire

=head1 DESCRIPTION

Order in which pfconfig::manager expires the namespaces derived from the one
it is asked to expire: each once, and only after every namespace it derives
from in the same run.

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use test_paths;
}

use Test::More tests => 7;
use Test::NoWarnings;

use pfconfig::manager;

# A manager whose namespaces are a fixed graph (namespace => child resources)
# and that records the expiries instead of rebuilding anything.
{
    package test_manager;
    our @ISA = ('pfconfig::manager');
    our %GRAPH;
    our @EXPIRED;
    sub new { bless {}, shift }
    # the manager normalizes the names: "a" is queried as "a()"
    sub bare { my ($what) = @_; $what =~ s/\(\)$//; return $what }
    sub get_namespace { my ($self, $what) = @_; return { child_resources => $GRAPH{bare($what)} // [] } }
    sub is_overlayed_namespace { 0 }
    sub overlayed_namespaces { () }
    sub cache_resource { my ($self, $what) = @_; push @EXPIRED, bare($what) }
}

my $manager = test_manager->new;

sub expired_after {
    my ($graph, @what) = @_;
    %test_manager::GRAPH = %$graph;
    @test_manager::EXPIRED = ();
    if (@what == 1) {
        $manager->expire($what[0]);
    } else {
        $manager->expire_namespaces(\@what);
    }
    return [@test_manager::EXPIRED];
}

sub position {
    my ($list, $what) = @_;
    my ($i) = grep { $list->[$_] eq $what } 0..$#$list;
    return $i;
}

# The connectors case: resource::connectors_config derives from both
# config::DnsConnectors and config::DomainsConnectors, themselves derived
# from config::Connector.
my %connectors = (
    'config::Connector' => ['resource::connectors_ordered', 'config::DnsConnectors', 'config::DomainsConnectors'],
    'config::DnsConnectors' => ['resource::connectors_config', 'resource::pfconnector_static_connections'],
    'config::DomainsConnectors' => ['resource::connectors_config'],
);
my $expired = expired_after(\%connectors, 'config::Connector');

is_deeply(
    [sort @$expired],
    [sort qw(config::Connector resource::connectors_ordered config::DnsConnectors config::DomainsConnectors resource::connectors_config resource::pfconnector_static_connections)],
    'every derived namespace is expired, once',
);

ok(
    position($expired, 'resource::connectors_config') > position($expired, 'config::DomainsConnectors')
      && position($expired, 'resource::connectors_config') > position($expired, 'config::DnsConnectors'),
    'a namespace with two parents is expired after both',
);

is($expired->[0], 'config::Connector', 'the expired namespace comes first');

# A chain: each namespace after its parent
is_deeply(expired_after({ a => ['b'], b => ['c'] }, 'a'), [qw(a b c)], 'a chain is expired in order');

# Several roots sharing a child (expire_all)
my $all = expired_after({ a => ['shared'], b => ['shared'] }, 'a', 'b');
is($all->[-1], 'shared', 'a child shared by two expired namespaces comes after both');

# A cycle does not stop the expiry
is_deeply([sort @{ expired_after({ a => ['b'], b => ['a'] }, 'a') }], [qw(a b)], 'a dependency cycle is still expired');

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
