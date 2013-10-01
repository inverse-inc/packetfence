use strict;
use warnings;

use Test::More 'no_plan';

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

is( $mac->get_oui(), "00-12-F0", "get oui() extracts the OUI from the MAC" );

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
