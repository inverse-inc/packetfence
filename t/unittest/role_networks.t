#!/usr/bin/perl

=head1 NAME

role_networks

=head1 DESCRIPTION

unit test for pf::role_networks

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 15;

#This test will running last
use Test::NoWarnings;

use pf::role_networks;

my $cache = pf::role_networks::cache();
$cache->clear();

my $switches = {
    'default'   => { NetworkMap => 'Y', networks => { Printer => '192.168.99.0/24' } },
    'group g1'  => { NetworkMap => 'Y', networks => { Printer => '192.168.98.0/24' } },
    '10.0.0.1'  => { NetworkMap => 'Y', networks => { Printer => '10.0.0.0/25', Camera => '10.1.0.7/32' } },
    '10.0.0.2'  => { NetworkMap => 'Y', networks => { Printer => '10.0.0.128/25, 10.0.2.0/24', Camera => 'fd00::/64' } },
    '10.0.0.3'  => { NetworkMap => 'N', networks => { Printer => '172.16.0.0/16' } },
};

is_deeply(
    pf::role_networks::compute_role_networks($switches),
    { Printer => ['10.0.0.0/24', '10.0.2.0/24'], Camera => ['10.1.0.7/32'] },
    "merge adjacent networks, skip default, groups, NetworkMap disabled and IPv6"
);

is_deeply(
    [ sort { $a cmp $b } (pf::role_networks::refresh_cache($switches)) ],
    ['Camera', 'Printer'],
    "first refresh populates every role"
);

is_deeply(
    [ pf::role_networks::refresh_cache($switches) ],
    [],
    "refresh without change rewrites nothing"
);

is_deeply($cache->get('Printer'), ['10.0.0.0/24', '10.0.2.0/24'], "Printer networks cached");

$switches->{'10.0.0.2'}{networks}{Printer} = '10.0.0.128/25';
delete $switches->{'10.0.0.1'}{networks}{Camera};

is_deeply(
    [ sort { $a cmp $b } (pf::role_networks::refresh_cache($switches)) ],
    ['Camera', 'Printer'],
    "only the roles whose networks changed are reported"
);

is_deeply(pf::role_networks::networks_for_role('Printer'), ['10.0.0.0/24'], "Printer recomputed after the switch update");
is_deeply(pf::role_networks::networks_for_role('Camera'), [], "Camera has no network anymore");
is_deeply($cache->get('Camera'), [], "a role without network is cached as empty");

is_deeply(
    [ pf::role_networks::acl_destinations('Printer') ],
    ['10.0.0.0 0.0.0.255'],
    "network destination uses a wildcard"
);

$cache->set('Server', ['10.5.5.5/32']);
is_deeply(
    [ pf::role_networks::acl_destinations('Server') ],
    ['host 10.5.5.5'],
    "/32 destination uses host"
);

$cache->set('Multi', ['10.0.0.0/24', '10.0.2.0/24']);
my $acls = join("\n",
    'permit tcp any any eq 443',
    '#permit ip any  net Multi ',
    '#permit tcp any  net Printer eq 9100',
    '#in|permit udp any net Server eq 161',
    '#permit ip any net Camera',
    '#permit ip any host aa:bb:cc:dd:ee:ff',
    'deny ip any any',
);

is(
    pf::role_networks::expand_acls($acls),
    join("\n",
        'permit tcp any any eq 443',
        'permit ip any 10.0.0.0 0.0.0.255',
        'permit ip any 10.0.2.0 0.0.0.255',
        'permit tcp any 10.0.0.0 0.0.0.255 eq 9100',
        'in|permit udp any host 10.5.5.5 eq 161',
        '#permit ip any net Camera',
        '#permit ip any host aa:bb:cc:dd:ee:ff',
        'deny ip any any',
    ),
    "net <Role> destinations are expanded, unresolved ones stay commented out"
);

is(pf::role_networks::expand_acls("permit ip any any"), "permit ip any any", "ACL without net destination is untouched");

$cache->set('Other', ['1.1.1.0/24']);
pf::role_networks::networks_for_role('Unknown');
is_deeply($cache->get('Other'), ['1.1.1.0/24'], "a cache miss does not touch other roles");
is_deeply($cache->get('Unknown'), [], "a cache miss for an unknown role is cached as empty");

$cache->clear();

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
