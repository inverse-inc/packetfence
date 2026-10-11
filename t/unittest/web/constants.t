#!/usr/bin/perl

=head1 NAME

constants

=head1 DESCRIPTION

unit test for pf::web::constants

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

our @EXTERNAL_PORTAL_URIS;
BEGIN {
    @EXTERNAL_PORTAL_URIS = (
        '/Cisco::Catalyst_2960/sid123456',
        '/Cisco::Cisco_IOS_15_0/sid123456',
        '/Cisco::Cisco_IOS_15_5/sid123456',
        '/Cisco::Cisco_IOS_15_5',
        '/Cisco::Cisco_WLC_AireOS',
        '/Aruba::2930M/sid123456',
    );
}

use Test::More tests => 3 + scalar @EXTERNAL_PORTAL_URIS;

#This test will running last
use Test::NoWarnings;
use pf::web::constants;

for my $uri (@EXTERNAL_PORTAL_URIS) {
    like($uri, $WEB::EXTERNAL_PORTAL_URL, "$uri is an external portal URL");
}

unlike('/captive-portal', $WEB::EXTERNAL_PORTAL_URL, '/captive-portal is not an external portal URL');
unlike('/Cisco::Cisco_IOS_15_55', $WEB::EXTERNAL_PORTAL_URL, 'switch type must match exactly');

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
