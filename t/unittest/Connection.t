#!/usr/bin/perl
=head1 NAME

Connection

=cut

=head1 DESCRIPTION

tests for pf::Connection class

=cut

use strict;
use warnings;

use Test::More tests => 9;                      # last test to print

use Test::NoWarnings;
use diagnostics;
use lib '/usr/local/pf/lib';
BEGIN {
    use lib '/usr/local/pf/t';
    use setup_test_config;
}

use pf::config qw(
    $WIRELESS_802_1X
    $WIRELESS_MAC_AUTH
    $WIRED_802_1X
    $WIRED_MAC_AUTH
    $WIRED_SNMP_TRAPS
    $INLINE
    $UNKNOWN
);

use_ok("pf::Connection");

my $conn;

my $type_tests = {
    $pf::config::connection_type_to_str{$pf::config::WIRELESS_802_1X} => pf::Connection->new(
        'transport' => 'Wireless',
        'isMacAuth' => 0,
        'isSNMP' => 0,
        'isEAP' => 1,
        'is8021X' => 1   
      ),
    $pf::config::connection_type_to_str{$pf::config::WIRELESS_MAC_AUTH} => pf::Connection->new(
        'transport' => 'Wireless',
        'isMacAuth' => 1,
        'isSNMP' => 0,
        'isEAP' => 0,
        'is8021X' => 0   
      ),
    $pf::config::connection_type_to_str{$pf::config::WIRED_802_1X} => pf::Connection->new(
        'transport' => 'Wired',
        'isMacAuth' => 0,
        'isSNMP' => 0,
        'isEAP' => 1,
        'is8021X' => 1   
      ),
    $pf::config::connection_type_to_str{$pf::config::WIRED_MAC_AUTH} => pf::Connection->new(
        'transport' => 'Wired',
        'isMacAuth' => 1,
        'isSNMP' => 0,
        'isEAP' => 0,
        'is8021X' => 0   
      ),
    $pf::config::connection_type_to_str{$pf::config::WIRED_SNMP_TRAPS} => pf::Connection->new(
        'transport' => 'Wired',
        'isMacAuth' => 0,
        'isSNMP' => 1,
        'isEAP' => 0,
        'is8021X' => 0   
      ),
    $pf::config::connection_type_to_str{$pf::config::INLINE} => pf::Connection->new(),
    $pf::config::connection_type_to_str{$pf::config::UNKNOWN} => pf::Connection->new(),
};

while( my ($type, $expected) = each(%$type_tests) ) {
    $conn = pf::Connection->new;
    $conn->backwardCompatibleToAttributes($type);
    is_deeply(
        $conn,
        $expected,
        "Matched correctly $type"
    );
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

1;



