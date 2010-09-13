#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
use Test::More tests => 19;
use Test::NoWarnings;

BEGIN { use_ok('pf::pfcmd::report') }

my @methods = qw(
    report_os_all
    report_os_active
    report_osclass_all
    report_osclass_active
    report_active_all
    report_inactive_all
    report_unregistered_active
    report_unregistered_all
    report_active_reg
    report_registered_all
    report_registered_active
    report_openviolations_all
    report_openviolations_active
    report_statics_all
    report_statics_active
    report_unknownprints_all
    report_unknownprints_active
);

# Test each method, assume no warnings and results
{
    no strict 'refs';

    foreach my $method (@methods) {
    
        ok(defined(&{$method}()), "testing $method call");
    }
}
