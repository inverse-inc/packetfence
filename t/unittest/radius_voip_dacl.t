#!/usr/bin/perl

=head1 NAME

radius_voip_dacl

=head1 DESCRIPTION

Unit tests for the VoIPDACL feature:
  - pf::radius::_merge_radius_attrs (helper used to merge the Voice VSA on
    top of the regular Access-Accept reply)
  - Switch field default and parsing for _VoIPDACL

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 16;
use Test::NoWarnings;

use pf::radius;
use pf::SwitchFactory;
use pf::util qw(isenabled);

# ----------------------------------------------------------------------------
# _merge_radius_attrs
# ----------------------------------------------------------------------------

{
    # Disjoint keys: both sides preserved, order = left-to-right.
    my @out = pf::radius::_merge_radius_attrs(
        'Tunnel-Type'   => 22,
        'Filter-Id'     => 'phone_acl',
        'Cisco-AVPair'  => 'device-traffic-class=voice',
    );
    is_deeply(
        \@out,
        [
            'Tunnel-Type'  => 22,
            'Filter-Id'    => 'phone_acl',
            'Cisco-AVPair' => 'device-traffic-class=voice',
        ],
        '_merge_radius_attrs preserves disjoint keys',
    );
}

{
    # Same scalar key twice -> promoted to arrayref of both values.
    my @out = pf::radius::_merge_radius_attrs(
        'Cisco-AVPair' => 'ip:inacl#10=permit ip any any',
        'Cisco-AVPair' => 'device-traffic-class=voice',
    );
    is_deeply(
        \@out,
        [
            'Cisco-AVPair' => [
                'ip:inacl#10=permit ip any any',
                'device-traffic-class=voice',
            ],
        ],
        '_merge_radius_attrs promotes duplicate scalar values to arrayref',
    );
}

{
    # Existing arrayref + new scalar -> appended to the arrayref.
    my @out = pf::radius::_merge_radius_attrs(
        'Cisco-AVPair' => [ 'avp1', 'avp2' ],
        'Cisco-AVPair' => 'avp3',
    );
    is_deeply(
        \@out,
        [ 'Cisco-AVPair' => [ 'avp1', 'avp2', 'avp3' ] ],
        '_merge_radius_attrs appends scalar to existing arrayref',
    );
}

{
    # Both sides arrayrefs -> concatenated.
    my @out = pf::radius::_merge_radius_attrs(
        'Cisco-AVPair' => [ 'a', 'b' ],
        'Cisco-AVPair' => [ 'c', 'd' ],
    );
    is_deeply(
        \@out,
        [ 'Cisco-AVPair' => [ 'a', 'b', 'c', 'd' ] ],
        '_merge_radius_attrs concatenates two arrayref values',
    );
}

{
    # Mixed: some disjoint, some duplicate (typical real-world reply).
    my @out = pf::radius::_merge_radius_attrs(
        # Regular Access-Accept (VLAN + ACL via Cisco-AVPair)
        'Tunnel-Medium-Type'      => 6,
        'Tunnel-Type'             => 13,
        'Tunnel-Private-Group-ID' => '100',
        'Cisco-AVPair'            => 'ip:inacl#10=permit ip any any',
        # Voice VSA merged on top
        'Cisco-AVPair'            => 'device-traffic-class=voice',
    );
    is_deeply(
        \@out,
        [
            'Tunnel-Medium-Type'      => 6,
            'Tunnel-Type'             => 13,
            'Tunnel-Private-Group-ID' => '100',
            'Cisco-AVPair'            => [
                'ip:inacl#10=permit ip any any',
                'device-traffic-class=voice',
            ],
        ],
        '_merge_radius_attrs mixed disjoint+duplicate (typical VoIPDACL reply)',
    );
}

{
    # Empty input -> empty output.
    my @out = pf::radius::_merge_radius_attrs();
    is_deeply(\@out, [], '_merge_radius_attrs on empty input returns empty list');
}

{
    # Defined-but-falsy values must NOT be dropped (e.g. VLAN id 0,
    # empty string Reply-Message). splice/while-guard would normally
    # exit on a 0 key, so this guards against that regression.
    my @out = pf::radius::_merge_radius_attrs(
        'Tunnel-Private-Group-ID' => '0',
        'Reply-Message'           => '',
        'Filter-Id'               => 0,
    );
    is_deeply(
        \@out,
        [
            'Tunnel-Private-Group-ID' => '0',
            'Reply-Message'           => '',
            'Filter-Id'               => 0,
        ],
        '_merge_radius_attrs keeps falsy values (0, "")',
    );
}

# ----------------------------------------------------------------------------
# Switch field: _VoIPDACL
# ----------------------------------------------------------------------------

{
    # Default value when neither the switch nor the [default] section sets it.
    # The 172.16.8.40 fixture sets only VoIPEnabled=Y, no VoIPDACL.
    my $switch = pf::SwitchFactory->instantiate('172.16.8.40');
    ok(defined $switch, 'instantiated switch 172.16.8.40');
    ok(!isenabled($switch->{_VoIPDACL}),
        '_VoIPDACL defaults to a disabled value when not set');
    ok(isenabled($switch->{_VoIPEnabled}),
        '_VoIPEnabled is on for the VoIPDACL-off fixture (sanity)');
}

{
    # Explicit on.
    my $switch = pf::SwitchFactory->instantiate('172.16.8.39');
    ok(defined $switch, 'instantiated switch 172.16.8.39');
    ok(isenabled($switch->{_VoIPDACL}),
        '_VoIPDACL=Y in switches.conf is recognized by isenabled()');
    ok(isenabled($switch->{_VoIPEnabled}),
        '_VoIPEnabled is on for the VoIPDACL-on fixture (sanity)');
}

{
    # Switches with no VoIP setup at all still expose a sane _VoIPDACL.
    my $switch = pf::SwitchFactory->instantiate('172.16.8.28');
    ok(defined $switch, 'instantiated switch 172.16.8.28');
    ok(!isenabled($switch->{_VoIPDACL}),
        '_VoIPDACL is disabled for a non-VoIP switch');
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
