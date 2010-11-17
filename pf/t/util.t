#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
use Test::More tests => 10;
use Test::NoWarnings;

BEGIN { use_ok('pf::util') }

# valid_mac
ok(valid_mac("aa:bb:cc:dd:ee:ff"), "validate MAC address of the form xx:xx:xx:xx:xx:xx");
ok(valid_mac("aa-bb-cc-dd-ee-ff"), "validate MAC address of the form xx-xx-xx-xx-xx-xx");
ok(valid_mac("aabb.ccdd.eeff"), "validate MAC address of the form xxxx.xxxx.xxxx");
ok(valid_mac("aabbccddeeff"), "validate MAC address of the form xxxxxxxxxxxx");

# clean_mac
is(clean_mac("aa:bb:cc:dd:ee:ff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xx:xx:xx:xx:xx:xx");
is(clean_mac("aa-bb-cc-dd-ee-ff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xx-xx-xx-xx-xx-xx");
is(clean_mac("aabb.ccdd.eeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxx.xxxx.xxxx");
is(clean_mac("aabbccddeeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxxxxxxxxxx");

# TODO add more tests, we should test:
#  - all methods ;)
