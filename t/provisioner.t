#!/usr/bin/perl

=head1 NAME

provisioner

=cut

=head1 DESCRIPTION

provisioner

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

our $TEST_CATEGORY = "test";

our $ANDROID_OS = 'Android OS';
our $TEST_OS = 'iOS';
our $TEST_OS_FINGERBANK_ID = '33450';

our %TEST_NODE_ATTRIBUTE = ( category => $TEST_CATEGORY, device_type => $TEST_OS, device_name => $TEST_OS );

use_ok("pf::provisioner");

my $provisioner = new_ok(
    "pf::provisioner",
    [{
        type     => 'autoconfig',
        category => [$TEST_CATEGORY],
        template => 'dummy',
        oses     => [$TEST_OS_FINGERBANK_ID],
    }]
);

=head2 test_node_attributes

test_node_attributes

=cut

sub test_node_attributes {
    return {%TEST_NODE_ATTRIBUTE};
}

ok($provisioner->match($TEST_OS, test_node_attributes()),"Match both os and category");

ok(!$provisioner->match($ANDROID_OS, test_node_attributes()),"Don't Match os but Matching category");

ok($provisioner->match(undef, test_node_attributes()),"Use device_name as the device_type");

ok(!$provisioner->match($ANDROID_OS, {category => 'not_matching', device_type => $ANDROID_OS, 'device_name' => $ANDROID_OS}),"Don't Match os and category");

$provisioner->category(['not_matching']);

ok(!$provisioner->match($TEST_OS, test_node_attributes()),"Match os but not category");

$provisioner->category([]);

ok($provisioner->match($TEST_OS, test_node_attributes()),"Match os with the any category");

ok(!$provisioner->match($ANDROID_OS, test_node_attributes()),"Don't match os with the any category");

$provisioner->category([$TEST_CATEGORY]);
$provisioner->oses([]);

ok($provisioner->match($TEST_OS, test_node_attributes()),"Match both os and category");

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

1;
