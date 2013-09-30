use strict;
use warnings;

use Test::More 'no_plan';

use_ok( 'pf::MAC' ) or die;
use pf::MAC;

my $mac = pf::MAC->new( mac => '00:12:F0:13:32:BA' );
isa_ok( $mac, 'Net::MAC');
isa_ok( $mac, 'pf::MAC');

is( "MAC: " . $mac, "MAC: 00:12:F0:13:32:BA",  "String concatenation works");
use pf::util;
is( mac2oid( $mac ), '0.18.240.19.50.186', "mac2oid returns correct notation");

is( clean_mac($mac), '00:12:f0:13:32:ba', "pf::util::clean_mac returns valid MAC");

my $cleaned_mac = $mac->clean();
is( $cleaned_mac, '00:12:f0:13:32:ba', "clean() returns valid MAC");

is( $mac->get_hex_stripped(), "0012F01332BA", "stripping returns string without delimiters" );
my $acct_mac = $mac->format_for_acct();
is( $acct_mac, "0012F01332BA", "format_for_acct returns valid MAC");
is( $acct_mac, format_mac_for_acct($mac), "pf::MAC::format_for_acct() and pf::util::format_for_acct return the same values.");

my $dash_mac = pf::MAC->new( mac => '00-12-f0-13-32-ba' );
is( $dash_mac->get_stripped(), "0012f01332ba", "get_stripped returns MAC without delimiters");

is( $mac->get_dec_stripped(), '81337201338', "MAC is returned as an integer" );
is( $mac->get_dec_stripped(), mac2nb($mac), "get_dec_stripped() and mac2nb return the same values" );

is( $mac->get_oui(), "00-12-F0", "get oui() extracts the OUI from the MAC");

like( $mac->get_dec_oui(), qr/^\d+$/, "get_dec_oui() returns a decimal integer");
is( $mac->get_dec_oui(), macoui2nb($mac), "get_dec_oui() and macoui2nb return the same values");

