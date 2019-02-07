#!/usr/bin/perl

=head1 NAME

wireless.t

=head1 DESCRIPTION

Test for wireless network devices modules

=cut

use strict;
use warnings;
use diagnostics;

use UNIVERSAL::require;

use lib '/usr/local/pf/lib';
use Test::More;
use Test::NoWarnings;
use Test::MockModule;
use Test::MockObject::Extends;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use TestUtils;

my @wireless_devices;
foreach my $networkdevice_class (TestUtils::get_networkdevices_classes()) {
    # create the object
    $networkdevice_class->require();
    my $networkdevice_object = $networkdevice_class->new();
    if ($networkdevice_object->supportsWirelessMacAuth() || $networkdevice_object->supportsWirelessDot1x()) {
        # if a wireless device we keep for the tests
        push(@wireless_devices, $networkdevice_object);
    }
}

my $mock = new Test::MockModule('pf::roles');

$mock->mock('node_attributes', sub {
    return { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '', category => 'default',
        lastskip => '', status => 'reg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', bypass_vlan => 1, }
});

# + no warnings
plan tests => scalar @wireless_devices * 2 + 1;

foreach my $wireless_object (@wireless_devices) {

    # test the object's heritage
    isa_ok($wireless_object, 'pf::Switch');

    # test its interface
    can_ok($wireless_object, qw(
        parseTrap getVersion extractSsid deauthenticateMacDefault
    ));

    # bogusly calling methods trying to generate warnings
    #$wireless_object->deauthenticateMac("aa:bb:cc:dd:ee:ff");
}

# regression test for #1426: RADIUS CoA Broken on WLC 5500
# http://www.packetfence.org/bugs/view.php?id=1426
my $networkdevice_object = pf::Switch::Cisco::WiSM2->new({
    'mode' => 'production',
    'radiusSecret' => 'fake',
    'ip' => '127.0.0.1',
    'id' => '127.0.0.1',
});
# bogusly calling methods trying to generate warnings
$networkdevice_object->deauthenticateMacDefault("aa:bb:cc:dd:ee:ff");

# regression test for #1437: RADIUS-based Disconnects not working for Aruba, AeroHIVE
# http://www.packetfence.org/bugs/view.php?id=1437
# installing a custom die handler to issue a warning on a different die than "No answer from 127.0.0.1 on port 3799"
# the warning will be trapped by the Test::NoWarnings;
# there's probably a cleaner way to do this but I can't seem to find it right now
my $die_handler = $SIG{__DIE__};
local $SIG{__DIE__} = sub {
    my $str = join("\n", @_);
    warn(@_) if ($str !~ /No answer from 127\.0\.0\.1 on port 3799/m);
};
$networkdevice_object = pf::Switch::Aruba->new({
    'mode' => 'production',
    'radiusSecret' => 'fake',
    'ip' => '127.0.0.1',
    'id' => '127.0.0.1',
});
# bogusly calling methods trying to generate warnings
$networkdevice_object->deauthenticateMacDefault("aa:bb:cc:dd:ee:ff");
# putting back old die handler
$SIG{__DIE__} = $die_handler;

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

