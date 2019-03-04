#!/usr/bin/perl
=head1 NAME

threecom.t

=cut

use strict;
use warnings;
use diagnostics;

use Test::MockObject::Extends;
use Test::More tests => 6;

use lib '/usr/local/pf/lib';
BEGIN { use lib qw(/usr/local/pf/t); }
BEGIN { use setup_test_config; }
use pf::config;
use pf::SwitchFactory;

BEGIN { use pf::Switch; }
BEGIN {
    use_ok('pf::Switch::ThreeCom::Switch_4200G');
}

# create the object
my $switch = pf::SwitchFactory->instantiate('10.0.0.3');

# test the object
isa_ok($switch, 'pf::Switch::ThreeCom::Switch_4200G');

# test subs
can_ok($switch, qw(
    NasPortToIfIndex
));

# sample NAS-Port -> ifIndex mappings
my %NasPortIfIndex = (
    '16781313' => '4227145',
    '16855041' => '4227289',
    '16859137' => '4227297',
);

# here we hardcode the dot1d to ifIndex table in a mocked call so we can run the test offline
$switch = Test::MockObject::Extends->new( $switch );
$switch->mock('getIfIndexForThisDot1dBasePort',
    sub {
        my ($self, $dot1dBasePort) = @_;
        my %hardcoded_table = (
            1 => 4227145, 2 => 4227153, 3 => 4227161, 4 => 4227169, 5 => 4227177, 6 => 4227185, 7 => 4227193,
            8 => 4227201, 9 => 4227209, 10 => 4227217, 11 => 4227225, 12 => 4227233, 13 => 4227241, 14 => 4227249,
            15 => 4227257, 16 => 4227265, 17 => 4227273, 18 => 4227281, 19 => 4227289, 20 => 4227297, 21 => 4227305,
            22 => 4227313, 23 => 4227321, 24 => 4227329,
        );
        return $hardcoded_table{$dot1dBasePort};
    }
);

foreach my $NasPort (keys %NasPortIfIndex) {
    is($switch->NasPortToIfIndex($NasPort), $NasPortIfIndex{$NasPort}, "port translation for $NasPort");
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

