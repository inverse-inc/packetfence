#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 33;
use lib '/usr/local/pf/lib';

BEGIN { use_ok('pf::action') }
BEGIN { use_ok('pf::class') }
BEGIN { use_ok('pf::configfile') }
BEGIN { use_ok('pf::config') }
BEGIN { use_ok('pf::db') }
BEGIN { use_ok('pf::ifoctetslog') }
BEGIN { use_ok('pf::iplog') }
BEGIN { use_ok('pf::locationlog') }
BEGIN { use_ok('pf::lookup::node') }
BEGIN { use_ok('pf::lookup::person') }
BEGIN { use_ok('pf::nodecache') }
BEGIN { use_ok('pf::nodecategory') }
BEGIN { use_ok('pf::node') }
BEGIN { use_ok('pf::os') }
BEGIN { use_ok('pf::person') }
BEGIN { use_ok('pf::pfcmd::dashboard') }
BEGIN { use_ok('pf::pfcmd::graph') }
BEGIN { use_ok('pf::pfcmd::help') }
BEGIN { use_ok('pf::pfcmd::pfcmd') }
BEGIN { use_ok('pf::pfcmd::report') }
BEGIN { use_ok('pf::rawip') }
BEGIN { use_ok('pf::scan') }
BEGIN { use_ok('pf::schedule') }
BEGIN { use_ok('pf::services') }
BEGIN { use_ok('pf::switchlocation') }
BEGIN { use_ok('pf::traplog') }
BEGIN { use_ok('pf::trigger') }
BEGIN { use_ok('pf::useragent') }
BEGIN { use_ok('pf::util') }
BEGIN { use_ok('pf::violation') }
BEGIN { use_ok('pf::vlan') }
BEGIN { use_ok('pf::vlan::custom') }
BEGIN { use_ok('pf::web') }
