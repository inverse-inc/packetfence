use strict;
use warnings;

use Test::More 'no_plan';

use_ok( 'pf::MAC' ) or die;
use pf::MAC;

my $mac = pf::MAC->new( mac => '00:12:f0:13:32:ba' );
isa_ok( $mac, 'pf::MAC');

use pf::util;
is( mac2oid( $mac ), '0.18.240.19.50.186', "mac2oid returns correct notation");
