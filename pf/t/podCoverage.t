#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib qw(
   /Users/dgehl/pf/org.packetfence.1_8/pf/conf
);

use Test::Pod::Coverage tests => 3;

pod_coverage_ok("authentication::ldap");
pod_coverage_ok("authentication::local");
pod_coverage_ok("authentication::radius");
