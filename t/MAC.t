#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 30;
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use_ok('pf::MAC') or die;
use pf::MAC;
use pf::util;

my $mac = pf::MAC->new( mac => '00:12:f0:13:32:BA' );
isa_ok( $mac, 'Net::MAC' );
isa_ok( $mac, 'pf::MAC' );

like( "MAC: " . $mac, qr/MAC: 00:12:F0:13:32:BA/i, "String concatenation works" );
is( mac2oid($mac), '0.18.240.19.50.186', "mac2oid returns correct notation" );

is( clean_mac($mac), '00:12:f0:13:32:ba', "pf::util::clean_mac returns valid MAC" );

my $cleaned_mac = $mac->clean();
is( $cleaned_mac, '00:12:f0:13:32:ba', "clean() returns valid MAC" );

is( $mac->get_hex_stripped(), "0012F01332BA", "stripping returns string without delimiters" );

my $dash_mac = pf::MAC->new( mac => '00-12-f0-13-32-ba' );
is( $dash_mac->get_stripped(), "0012f01332ba", "get_stripped returns MAC without delimiters" );

like( $mac->get_dec_stripped(), qr/^\d+$/, "MAC is returned as decimal integer" );
is( $mac->get_dec_stripped(),
    mac2nb($mac), "get_dec_stripped() and pf::util::mac2nb() return the same values" );
is( $mac->get_dec_stripped(), $mac->mac2nb(), "get_dec_stripped() and mac2nb() return the same values" );

is( $mac->get_oui(), "00:12:f0", "get_oui() extracts the OUI from the MAC" );
is( $mac->get_IEEE_oui(), "00-12-F0", "get_IEEE_oui() extracts the IEEE OUI from the MAC" );

like( $mac->get_dec_oui(), qr/^\d+$/, "get_dec_oui() returns a decimal integer" );
is( $mac->get_dec_oui(), macoui2nb($mac),   "get_dec_oui() and pf::util::macoui2nb return the same values" );
is( $mac->get_dec_oui(), $mac->macoui2nb(), "get_dec_oui() and macoui2nb() return the same values" );

is( valid_mac($mac), 1, "pf::util::valid_mac() accepts our pf::MAC object" );

is( $mac->as_oid, "0.18.240.19.50.186", "pf::MAC::as_oid returns the correct OID." );
is( $mac->as_oid, mac2oid($mac),        "pf::MAC::as_oid and pf::util::mac2oid return the same values" );

is( $mac->as_acct(), "0012F01332BA", "as_acct() returns valid MAC" );
is( $mac->as_acct(),
    format_mac_for_acct($mac),
    "pf::MAC::as_acct() and pf::util::format_for_acct return the same values."
);
is( $mac->as_acct(), $mac->format_for_acct(), "as_acct() and format_for_acct() return the same values" );

my $mac2 = pf::MAC->new( mac => '0012.f013.32ba' );
is( $mac eq $mac2, 1, "Overloaded string comparison eq compares internal MACS"); 

my $mac3 = pf::MAC->new( mac => '00:12:f0:DE:AD:BE' );
is( $mac ne $mac3, 1, "Overloaded string comparison ne works"); 

is( $mac->in_OUI('00:12:f0'), 1, "MAC is in OUI");
is( $mac->in_OUI('00:12:F0'), 1, "MAC is in OUI regardless of case");
is( $mac->in_OUI('00-12-f0'), 1, "MAC is in OUI regardless of delimiter");
is( $mac->in_OUI('0012f0'), 1, "MAC is in OUI without delimiter");
is( $mac->in_OUI('00:12:f7'), 0, "MAC is not in wrong OUI");



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

