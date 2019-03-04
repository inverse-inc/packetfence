#!/usr/bin/perl

=head1 NAME

wired.t

=head1 DESCRIPTION

Test for wired network devices modules

=cut

use strict;
use warnings;
use diagnostics;

use UNIVERSAL::require;

use lib '/usr/local/pf/lib';
use Test::More;
use Test::NoWarnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use TestUtils;

my @wired_devices;
foreach my $networkdevice_class (TestUtils::get_networkdevices_classes()) {
    # create the object
    $networkdevice_class->require();
    my $networkdevice_object = $networkdevice_class->new();
    # TODO this should be ported to supportsWiredSnmp (or the equivalent) when supported
    if (!$networkdevice_object->supportsWirelessMacAuth() && !$networkdevice_object->supportsWirelessDot1x()) {

        # skip special modules
        next if (ref($networkdevice_object) =~ /^pf::Switch$/);
        next if (ref($networkdevice_object) =~ /^pf::Switch::PacketFence$/);

        # if a wired device we keep for the tests
        push(@wired_devices, $networkdevice_object);
    }
}

# + no warnings
plan tests => scalar @wired_devices * 2;

foreach my $wired_object (@wired_devices) {

    # test the object's heritage
    isa_ok($wired_object, 'pf::Switch');

    # test its interface
    can_ok($wired_object, qw(
        parseTrap getVersion
    ));
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

