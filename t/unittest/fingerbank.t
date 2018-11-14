#!/usr/bin/perl

=head1 NAME

fingerbank

=cut

=head1 DESCRIPTION

fingerbank

=cut

use strict;
use warnings;
# pf core libs
use lib '/usr/local/pf/lib';

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use Test::More tests => 11;

use Test::NoWarnings;
use Test::Exception;
use pf::config qw(%Config);

use_ok("pf::fingerbank");

my $result;

# test invalid data
my $non_existing_device = "DUMMYKJFSKJFLKJAJKLFKJLKLJDFJKLDKJLFJKLDFLKJKLSF";
$result = pf::fingerbank::device_class_transition_allowed($non_existing_device, $non_existing_device, $non_existing_device, $non_existing_device);
ok(!defined($result), "Invalid device name provides undefined result");

# Disable the device class transition check for all device classes to test the manual trigger
$Config{fingerbank_device_change}{trigger_on_device_class_change} = "disabled";

# test manual transition trigger
$result = pf::fingerbank::device_class_transition_allowed("Windows OS", "Windows OS", "Medical Device", "Abbott Medical");
ok(!$result, "Manual trigger provides not allowed result");

# Re-enable the device class transition check for all device classes 
$Config{fingerbank_device_change}{trigger_on_device_class_change} = "enabled";

# test valid transition
$result = pf::fingerbank::device_class_transition_allowed("Windows OS", "Windows OS", "Windows OS", "Microsoft Windows Kernel 10.0");
ok($result, "Not switching device class provides allowed result");

# test transition to same device
$result = pf::fingerbank::device_class_transition_allowed("Windows OS", "Windows OS", "Windows OS", "Windows OS");
ok($result, "Not switching device class provides allowed result");

# test invalid transition
$result = pf::fingerbank::device_class_transition_allowed("Windows OS", "Windows OS", "Android OS", "Galaxy S8");
ok(!$result, "Not switching device class provides allowed result");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

