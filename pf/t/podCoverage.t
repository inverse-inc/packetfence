#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib qw(
   /usr/local/pf/conf
   /usr/local/pf/lib
);

use Test::Pod::Coverage tests => 5;

pod_coverage_ok("authentication::ldap");
pod_coverage_ok("authentication::local");
pod_coverage_ok("authentication::radius");

pod_coverage_ok("pf::radius");
pod_coverage_ok("pf::vlan");
