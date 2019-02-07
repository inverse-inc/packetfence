#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 20;
use Test::NoWarnings;

use lib '/usr/local/pf/lib';
BEGIN { use lib qw(/usr/local/pf/t); }
BEGIN { use setup_test_config; }
use pf::config;
use pf::SwitchFactory;

BEGIN { use pf::Switch; }
BEGIN {
    use_ok('pf::Switch::Cisco');
}

# create the object
my $switch = pf::SwitchFactory->instantiate('10.0.0.1');

# test the object
isa_ok($switch, 'pf::Switch::Cisco');

# test subs
can_ok($switch, qw(
    enablePortConfigAsTrunk
    disablePortConfigAsTrunk
    NasPortToIfIndex
));

# Catalyst 3750 tests

$switch = pf::SwitchFactory->instantiate('10.0.0.4');

# sample NAS-Port -> ifIndex mappings
my %nasPortIfIndex = (
    '50101' => '10001',
    '50128' => '10028',
    '50201' => '10501',
    '50228' => '10528',
    '50301' => '11001',
    '50328' => '11028',
    '50401' => '11501',
    '50428' => '11528',
);

foreach my $nasPort (keys %nasPortIfIndex) {
    is($switch->NasPortToIfIndex($nasPort), $nasPortIfIndex{$nasPort}, "port translation for $nasPort");
}

# Catalyst 3750G tests

$switch = pf::SwitchFactory->instantiate('10.0.0.10');

# sample NAS-Port -> ifIndex mappings
%nasPortIfIndex = (
    '50101' => '10101',
    '50128' => '10128',
    '50201' => '10601',
    '50228' => '10628',
    '50301' => '11101',
    '50328' => '11128',
    '50401' => '11601',
    '50428' => '11628',
);

foreach my $nasPort (keys %nasPortIfIndex) {
    is($switch->NasPortToIfIndex($nasPort), $nasPortIfIndex{$nasPort}, "port translation for $nasPort");
}

# TODO a lot missing here

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

