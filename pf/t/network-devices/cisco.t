#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 3;

use lib '/usr/local/pf/lib';
use pf::config;
use pf::SwitchFactory;

BEGIN { use pf::SNMP; }
BEGIN {
    use_ok('pf::SNMP::Cisco');
}

# create the object
my $switchFactory = new pf::SwitchFactory( -configFile => './data/switches.conf' );
my $switch = $switchFactory->instantiate('192.168.0.60');

# test the object
isa_ok($switch, 'pf::SNMP::Cisco');

# test subs
can_ok($switch, qw(
    enablePortConfigAsTrunk
    disablePortConfigAsTrunk
));

# TODO a lot missing here
