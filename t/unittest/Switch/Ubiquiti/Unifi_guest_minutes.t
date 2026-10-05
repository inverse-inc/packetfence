#!/usr/bin/perl

=head1 NAME

Unifi_guest_minutes

=head1 DESCRIPTION

unit test for pf::Switch::Ubiquiti::Unifi::guestAuthorizationMinutes (#9203)

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 9;
use Test::NoWarnings;
use DateTime;
use DateTime::Format::MySQL;
use pf::constants qw($ZERO_DATE);
use pf::Switch::Ubiquiti::Unifi;

my $switch = pf::Switch::Ubiquiti::Unifi->new({ id => '10.9.9.9', ip => '10.9.9.9', SNMPUseConnector => 'N', radiusDeauthUseConnector => 'N' });

my $now = time;
my $in = sub {
    my ($seconds) = @_;
    my $dt = DateTime->from_epoch(epoch => $now + $seconds, time_zone => 'local');
    return DateTime::Format::MySQL->format_datetime($dt);
};

is($switch->guestAuthorizationMinutes($in->(24 * 3600), $now), 1440, 'one day ahead is 1440 minutes');
is($switch->guestAuthorizationMinutes($in->(7 * 24 * 3600), $now), 10080, 'seven days ahead');
is($switch->guestAuthorizationMinutes($in->(90), $now), 2, 'a partial minute is rounded up');
is($switch->guestAuthorizationMinutes($in->(-2 * 3600), $now), 1, 'an expired date gives 1 minute, not the absolute difference');
is($switch->guestAuthorizationMinutes($ZERO_DATE, $now), $pf::Switch::Ubiquiti::Unifi::GUEST_AUTHORIZATION_MINUTES_NO_EXPIRY, 'no unregistration date gets the long default');
is($switch->guestAuthorizationMinutes(undef, $now), $pf::Switch::Ubiquiti::Unifi::GUEST_AUTHORIZATION_MINUTES_NO_EXPIRY, 'undefined unregistration date gets the long default');
ok($switch->guestAuthorizationMinutes('not a date', $now) > 0, 'an unparseable date still returns a positive duration');
cmp_ok($pf::Switch::Ubiquiti::Unifi::GUEST_AUTHORIZATION_MINUTES_NO_EXPIRY, '>', 480, 'the no-expiry default is longer than the controller defaults');

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
