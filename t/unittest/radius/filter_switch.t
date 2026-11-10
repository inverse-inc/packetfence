#!/usr/bin/perl

=head1 NAME

filter_switch

=head1 DESCRIPTION

pf::radius::radius_filter looks the switch up from the NAS IP address or from
the switch MAC (Called-Station-Id), and skips the filters only when the
request has neither (the proxied copy of a request, #9142)

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;
use pf::radius;
use pf::radius::constants;
use pf::SwitchFactory;

#This test will running last
use Test::NoWarnings;

# Record the lookups, and find no switch: radius_filter then answers with a Reply-Message
my @lookups;
{
    no warnings qw(redefine once);
    *pf::SwitchFactory::instantiate = sub { my ($class, $request) = @_; push @lookups, $request; return undef };
}

my $radius = pf::radius->new;

@lookups = ();
my $reply = $radius->radius_filter('packetfence.authorize', { 'User-Name' => 'aabbccddeeff', 'Calling-Station-Id' => 'aa:bb:cc:dd:ee:ff' });
is($reply->[0], $RADIUS::RLM_MODULE_NOOP, 'no NAS IP and no switch MAC: the filters are skipped');
is(scalar @lookups, 0, 'no NAS IP and no switch MAC: no switch lookup');
is(scalar @$reply, 1, 'no NAS IP and no switch MAC: no Reply-Message');

@lookups = ();
$reply = $radius->radius_filter('packetfence.authorize', { 'User-Name' => 'aabbccddeeff', 'Calling-Station-Id' => 'aa:bb:cc:dd:ee:ff', 'Called-Station-Id' => '01-01-01-01-01-01:SSID' });
is(scalar @lookups, 1, 'no NAS IP but a switch MAC: the switch is looked up');
is($lookups[0]{switch_mac}, '01:01:01:01:01:01', 'the switch is looked up by its MAC');

@lookups = ();
$radius->radius_filter('packetfence.authorize', { 'User-Name' => 'aabbccddeeff', 'Calling-Station-Id' => 'aa:bb:cc:dd:ee:ff', 'NAS-IP-Address' => '192.0.2.1' });
is($lookups[0]{switch_ip}, '192.0.2.1', 'with a NAS IP the switch is looked up by its IP');

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
