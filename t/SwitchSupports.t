#!/usr/bin/perl

=head1 NAME

SwitchSupports

=head1 DESCRIPTION

unit test for SwitchSupports

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

{
    package m1;
    use base qw(pf::Switch);
    use pf::SwitchSupports qw(
        VPN
        -RadiusDynamicVlanAssignment
    );
}

{
    package m2;
    use base qw(m1);
    use pf::SwitchSupports qw(
        RadiusDynamicVlanAssignment
    );
}

{
    package m3;
    use base qw(m1);
    use pf::SwitchSupports qw(
        ?RadiusDynamicVlanAssignment
    );
}

{
    package m4;
    use base qw(m1);
    use pf::SwitchSupports qw(
        ~RadiusDynamicVlanAssignment
    );
}

use Test::More tests => 11;

#This test will running last
use Test::NoWarnings;

is_deeply([m1->supports()], [qw(VPN)], "");

is_deeply([m2->supports()], [qw(RadiusDynamicVlanAssignment VPN)], "");

is_deeply([m3->supports()], [qw(RadiusDynamicVlanAssignment VPN)], "");

is_deeply([m4->supports()], [qw(RadiusDynamicVlanAssignment VPN)], "");

ok(exists &m1::supportsVPN, "m1->supportsVPN exists");

ok(exists &m2::supportsRadiusDynamicVlanAssignment, "m2->supportsRadiusDynamicVlanAssignment exists");

ok(!exists &m3::supportsRadiusDynamicVlanAssignment, "m3->supportsRadiusDynamicVlanAssignment does not exists");

ok(m3->supportsRadiusDynamicVlanAssignmentTested, "tested m3->supportsRadiusDynamicVlanAssignmentTested");

ok(m4->supportsRadiusDynamicVlanAssignment, "m4->supportsRadiusDynamicVlanAssignment +");

ok(!m4->supportsRadiusDynamicVlanAssignmentTested, "not tested m4->supportsRadiusDynamicVlanAssignmentTested");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

