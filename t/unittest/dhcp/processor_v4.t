#!/usr/bin/perl

=head1 NAME

processor_v4

=head1 DESCRIPTION

unit test for processor_v4

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

use Test::More tests => 5;

#Test no warnings will run last
use Test::NoWarnings;
use pf::dhcp::processor_v4;
use NetAddr::IP;
my @testNetworkLookup;
is_deeply(
    pf::dhcp::processor_v4::lookupNetwork(\@testNetworkLookup, '192.168.1.1'),
    undef
);

@testNetworkLookup = (
    [NetAddr::IP->new('192.168.1.0/24'), {  }],
    [NetAddr::IP->new('192.168.2.0/24'), {  }],
);

is_deeply(
    pf::dhcp::processor_v4::lookupNetwork(\@testNetworkLookup, '192.168.1.1'),
    {},
);

is_deeply(
    pf::dhcp::processor_v4::lookupNetwork(\@testNetworkLookup, '192.168.2.1'),
    {},
);

is_deeply(
    pf::dhcp::processor_v4::lookupNetwork(\@testNetworkLookup, '192.168.3.1'),
    undef,
);

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
