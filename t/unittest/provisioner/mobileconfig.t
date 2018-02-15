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
use Test::More tests => 5;

use Test::NoWarnings;
use Test::Exception;

our $TEST_CATEGORY = "test";

our $ANDROID_DEVICE = 'Android OS';
our $APPLE_DEVICE   = 'iOS',
our $TEST_NODE_ATTRIBUTE = { category => $TEST_CATEGORY };

use_ok("pf::provisioner::mobileconfig");

my $provisioner = new_ok(
    "pf::provisioner::mobileconfig",
    [{
        category => [$TEST_CATEGORY],
    }]
);

ok(!$provisioner->match($ANDROID_DEVICE,$TEST_NODE_ATTRIBUTE),"Does not match android device");

ok($provisioner->match($APPLE_DEVICE,$TEST_NODE_ATTRIBUTE),"Matches apple device");

1;

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


