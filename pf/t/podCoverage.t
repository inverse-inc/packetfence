#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib qw(
   /usr/local/pf/conf
);

use Test::Pod::Coverage tests => 3;

pod_coverage_ok("authentication::ldap");
pod_coverage_ok("authentication::local");
pod_coverage_ok("authentication::radius");
