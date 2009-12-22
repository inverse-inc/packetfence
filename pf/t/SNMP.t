#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 9;
use lib '/usr/local/pf/lib';

BEGIN { use_ok('pf::SNMP') }

# test the object
my $snmp_obj = new_ok('pf::SNMP');

# test subs
#TODO: list all mandatory subs here
can_ok($snmp_obj, qw(
    connectRead
    connectWrite
    setVlan
    _setVlanByOnlyModifyingPvid
    setVlanByName
    setMacDetectionVlan
  ));
