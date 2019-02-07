#!/usr/bin/perl

=head1 NAME

roles.t

=head1 DESCRIPTION

Test for network devices modules that support roles

=cut

use strict;
use warnings;

use UNIVERSAL::require;

use lib '/usr/local/pf/lib';
use Test::More;
use Test::NoWarnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use TestUtils;

my @supports_roles;
foreach my $networkdevice_class (TestUtils::get_networkdevices_classes()) {
    # create the object
    $networkdevice_class->require();
    my $networkdevice_object = $networkdevice_class->new();
    if ($networkdevice_object->supportsRoleBasedEnforcement()) {
        # if it supports roles we keep for the tests
        push(@supports_roles, $networkdevice_object);
    }
}

# + no warnings
plan tests => scalar @supports_roles * 2 + 1;

foreach my $support_roles (@supports_roles) {

    # test the object's heritage
    isa_ok($support_roles, 'pf::Switch');

    # test its interface
    can_ok($support_roles, qw(returnRoleAttribute));

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

