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

use Test::More tests => 32;

#This test will running last
use Test::NoWarnings;

use pf::role_networks;
use pf::error::switch;

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
    pf::role_networks::compute_role_networks({ '10.0.0.9' => { networks => { Printer => '10.0.9.0/24' } } }),
    { Printer => ['10.0.9.0/24'] },
    "a switch that does not set NetworkMap maps networks, like pf::Switch does"
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
        '#permit ip any host aa:bb:cc:dd:ee:ff',
        'deny ip any any',
    ),
    "net <Role> destinations are expanded, unresolved ones are dropped"
);

is(pf::role_networks::expand_acls("permit ip any any"), "permit ip any any", "ACL without net destination is untouched");

# The switch modules parse all the ACLs of a role at once and drop every one of
# them on a single invalid line, so an expansion must never produce one.
is(
    pf::role_networks::expand_acls("# printers on the net Printer queue are blocked\ndeny ip any any"),
    "deny ip any any",
    "a comment that mentions net <Role> is not a valid ACL once expanded, it is dropped"
);

is(
    pf::role_networks::expand_acls("#permit tcp net Server net Multi eq 9100"),
    join("\n",
        'permit tcp host 10.5.5.5 10.0.0.0 0.0.0.255 eq 9100',
        'permit tcp host 10.5.5.5 10.0.2.0 0.0.0.255 eq 9100',
    ),
    "every net <Role> of a line is expanded, one line per combination of networks"
);

is(
    pf::role_networks::expand_acls("#permit tcp net Server net Camera eq 9100"),
    "deny ip any any",
    "a line naming a role without network is dropped, even when its other role has networks (and the role denies all, see below)"
);

is(
    pf::role_networks::expand_acls("#out|permit ip net Server any"),
    "out|permit ip host 10.5.5.5 any",
    "net <Role> is expanded as a source too, with its direction"
);

is(
    pf::role_networks::expand_acls("#permit tcp any net Server eq"),
    "deny ip any any",
    "an ACL that is malformed once expanded is dropped"
);

# A permit to a role without network permits nothing: a direction left without
# any ACL denies everything, never sends no ACL (which leaves the device unrestricted)
is(
    pf::role_networks::expand_acls("#permit ip any net Camera"),
    "deny ip any any",
    "a role whose only ACL can't be expanded denies all the traffic"
);
is(
    pf::role_networks::expand_acls("#out|permit ip net Camera any\npermit ip any any"),
    "permit ip any any\nout|deny ip any any",
    "the deny all has the direction of the dropped line"
);
is(
    pf::role_networks::expand_acls("#permit ip any net Camera\npermit udp any any eq 53"),
    "permit udp any any eq 53",
    "no deny all when an ACL is left in that direction"
);

# pf::Switch::format_acl uncomments a line naming a host by its MAC: an
# unexpanded "net <Role>" must not reach it
is(
    pf::role_networks::expand_acls("#permit ip host 00:11:22:33:44:55 net Camera\npermit ip any any"),
    "permit ip any any",
    "a line with a host MAC and a role without network is dropped"
);

is(
    pf::role_networks::expand_acls("#permit ip host 00:11:22:33:44:55 net Server\npermit ip any any"),
    "permit ip any any",
    "a line with a host MAC is not a valid ACL once expanded, it is dropped"
);

# The ACL limits of the switches apply to the expanded lines
{
    require pf::Switch::Cisco::Cisco_IOS_15_5;
    $cache->set('Large', ['10.10.0.0/24', '10.10.2.0/24', '10.10.4.0/24']);
    my $switch = pf::Switch::Cisco::Cisco_IOS_15_5->new({ id => '10.0.0.9', ACLsLimit => 2 });
    my $error = $switch->checkRoleACLs('testrole', ['#permit ip any net Large']);
    is(ref($error) eq 'HASH' ? $error->{code} : undef, $pf::error::switch::ACLsLimitErrCode, "a net <Role> line counts as one ACL per network against the switch limit");
    is($switch->checkRoleACLs('testrole', ['#permit ip any net Server', 'deny ip any any']), undef, "expanded ACLs within the limit pass");
}

ok(
    !pf::role_networks::_are_valid_acls("printers on the 10.0.0.0 0.0.0.255 queue"),
    "free text is not a valid ACL"
);
ok(
    pf::role_networks::_are_valid_acls("permit ip any 10.0.0.0 0.0.0.255", "permit ip any host 10.0.2.1"),
    "the expanded lines are validated in one parse"
);
ok(
    !pf::role_networks::_are_valid_acls("permit ip any 10.0.0.0 0.0.0.255", "permit tcp any host 10.0.2.1 eq"),
    "one invalid line makes them invalid"
);

$cache->set('Other', ['1.1.1.0/24']);
pf::role_networks::networks_for_role('Unknown');
is_deeply($cache->get('Other'), ['1.1.1.0/24'], "a cache miss does not touch other roles");
is_deeply($cache->get('Unknown'), [], "a cache miss for an unknown role is cached as empty");
ok((grep { $_ eq 'Unknown' } @{ $cache->get($pf::role_networks::ROLES_INDEX_KEY) // [] }), "a role cached on a miss is indexed, so the next refresh rewrites or removes it");

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
