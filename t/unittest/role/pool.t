#!/usr/bin/perl

=head1 NAME

pool

=head1 DESCRIPTION

unit test for pf::role::pool - VLAN pool and switch role pool selection

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More;
use Number::Range;
use pf::Switch;

use_ok('pf::role::pool');

my $pool = pf::role::pool->new;

my @members = qw(net_a net_b net_c);
my $poolstr = join( ',', @members );

# --- _isRolePool ---------------------------------------------------------
ok( !$pool->_isRolePool('net_a'),           'single role is not a pool' );
ok( !$pool->_isRolePool(''),                'empty string is not a pool' );
ok( !$pool->_isRolePool(undef),             'undef is not a pool' );
ok( !$pool->_isRolePool('net_a,'),          'single member + trailing comma is not a pool' );
ok( $pool->_isRolePool('net_a,net_b'),      'comma list is a pool' );
ok( $pool->_isRolePool('net_a, net_b , net_c'), 'whitespaced comma list is a pool' );

# --- getRoleFromPool: single value passes through unchanged --------------
is( $pool->getRoleFromPool( { role => 'net_a', node_info => { pid => 'alice' } } ),
    'net_a', 'single role returned unchanged' );

# --- getRoleFromPool: always returns a member of the pool ----------------
my %seen;
for my $u (qw(alice bob carol dave erin frank grace heidi ivan judy)) {
    my $r = $pool->getRoleFromPool( { role => $poolstr, node_info => { pid => $u } } );
    ok( ( grep { $_ eq $r } @members ), "pid '$u' -> valid pool member ($r)" );
    $seen{$r}++;
}

# --- determinism == roaming stability: same pid always the same role -----
my $first = $pool->getRoleFromPool( { role => $poolstr, node_info => { pid => 'alice' } } );
my $stable = 1;
for ( 1 .. 50 ) {
    $stable = 0
      if $pool->getRoleFromPool( { role => $poolstr, node_info => { pid => 'alice' } } ) ne $first;
}
ok( $stable, 'same pid maps to the same role across 50 calls (roaming stable)' );

# --- even-ish distribution: more than one member is used -----------------
ok( scalar( keys %seen ) > 1, 'pool spreads users across multiple roles' );

# --- DRY parity: role hash uses the same index as the VLAN username hash --
my $range = Number::Range->new("10..12");
my @vlans = $range->range;
for my $u (qw(alice bob carol)) {
    my $args = { node_info => { pid => $u } };
    my $vlan = $pool->getVlanByUsername( $args, $range );
    my $role = $pool->getRoleFromPool( { role => join( ',', @vlans ), node_info => { pid => $u } } );
    is( $role, $vlan, "role hash matches vlan hash for pid '$u' (shared _usernameHashIndex)" );
}

# --- integration through pf::Switch::getRoleByName -----------------------
my $switch = pf::Switch->new(
    { id => 'test', roles => { staff => $poolstr, guest => 'guestnet' } } );
my $args = { user_role => 'staff', node_info => { pid => 'alice' } };

my $picked = $switch->getRoleByName( 'staff', $args );
ok( ( grep { $_ eq $picked } @members ), "getRoleByName resolves a pool when args given ($picked)" );
is( $switch->getRoleByName( 'staff', $args ), $picked,
    'getRoleByName pool selection is deterministic per pid' );
is( $switch->getRoleByName('staff'), $poolstr,
    'getRoleByName without args returns the raw pool string' );
is( $switch->getRoleByName( 'guest', $args ), 'guestnet',
    'a single (non-pool) role is unaffected' );

# --- CoA / deauth path: performRoleLookup must pick the same pool member ------
# so that the role re-applied on a Change-of-Authorization matches the one
# handed out in the initial RADIUS Access-Accept.
use pf::roles::custom;
my $resolver = pf::roles::custom->instance();
for my $pid (qw(alice bob carol dave)) {
    my $node = { mac => 'aa:bb:cc:00:00:01', status => 'reg', category => 'staff', pid => $pid };
    my $via_coa    = $resolver->performRoleLookup( $node, $switch );
    my $via_accept = $switch->getRoleByName( 'staff', { node_info => { pid => $pid }, user_role => 'staff' } );
    ok( ( grep { $_ eq $via_coa } @members ), "performRoleLookup returns a pool member for pid '$pid' ($via_coa)" );
    is( $via_coa, $via_accept, "CoA role matches Access-Accept role for pid '$pid'" );
}
is( $resolver->performRoleLookup( { mac => 'x', status => 'reg', category => 'guest', pid => 'alice' }, $switch ),
    'guestnet', 'performRoleLookup leaves a single (non-pool) role unchanged' );

# --- machine auth / MAB / unowned nodes: no usable pid -> hash on the MAC -----
# Those clients must be spread per-device (by MAC), not all land on one member,
# and each MAC must be deterministic (roaming-stable per device).
{
    my @macs = map { sprintf( '00:11:22:33:44:%02x', $_ ) } 1 .. 12;
    my %used;
    my $stable = 1;
    for my $mac (@macs) {
        my @res = map {
            $pool->getRoleFromPool( { role => $poolstr, node_info => { pid => $_ }, mac => $mac } )
        } ( undef, '', 'default' );
        $stable = 0 if grep { $_ ne $res[0] } @res;
        ok( ( grep { $_ eq $res[0] } @members ), "no-pid node (mac $mac) -> valid pool member ($res[0])" );
        $used{ $res[0] }++;
    }
    ok( $stable, 'undef / "" / "default" pid all fall back to the same MAC-based member' );
    ok( scalar( keys %used ) > 1, 'no-pid nodes are distributed across the pool by MAC' );
}

# --- _poolMembers edge cases: empty members dropped, members trimmed ---------
is_deeply( [ pf::role::pool::_poolMembers('net_a,,net_b') ], [ 'net_a', 'net_b' ],
    'empty members are dropped' );
is_deeply( [ pf::role::pool::_poolMembers(' net_a , net_b ') ], [ 'net_a', 'net_b' ],
    'members are trimmed' );
{
    my $r = $pool->getRoleFromPool( { role => ' net_a , net_b ', node_info => { pid => 'alice' } } );
    ok( $r eq 'net_a' || $r eq 'net_b', "whitespaced pool returns a trimmed member ($r)" );
    unlike( $r, qr/\s/, 'returned pool member has no surrounding whitespace' );
}

# --- inherited (parent) role resolves the parent's pool ----------------------
{
    local %pf::config::ConfigRoles = (
        child => { inherit_role => 'enabled', parent_id => 'staff' },
    );
    my $sw = pf::Switch->new( { id => 'inh', roles => { staff => $poolstr } } );
    my $r = $sw->getRoleByName( 'child', { node_info => { pid => 'alice' } } );
    ok( ( grep { $_ eq $r } @members ),
        "getRoleByName('child') inherits staff's pool and resolves one member ($r)" );
}

done_testing();

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
