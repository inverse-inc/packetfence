#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib qw(
   /usr/local/pf/conf
   /usr/local/pf/lib
);

use Test::Pod::Coverage tests => 8;

pod_coverage_ok("authentication::ldap");
pod_coverage_ok("authentication::local");
pod_coverage_ok("authentication::radius");

pod_coverage_ok("pf::radius");
pod_coverage_ok("pf::vlan");
pod_coverage_ok("pf::SNMP");
pod_coverage_ok("pf::floatingdevice");
# Warning: this doesn't test for PFAPI subs since it's under another package name
# I couldn't find a way to tell T::P::C to cover it
pod_coverage_ok("pf::WebAPI");
