#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 86;
use lib '/usr/local/pf/lib';

# Test all modules that provides data
BEGIN { use_ok('pf::db') }
BEGIN { 
    use_ok('pf::action');
    use_ok('pf::class');
    use_ok('pf::configfile');
    use_ok('pf::ifoctetslog');
    use_ok('pf::iplog');
    use_ok('pf::locationlog');
    use_ok('pf::node');
    use_ok('pf::os');
    use_ok('pf::person');
    use_ok('pf::switchlocation');
    use_ok('pf::traplog');
    use_ok('pf::trigger');
    use_ok('pf::useragent');
    use_ok('pf::violation');
    use_ok('pf::pfcmd::dashboard');
    use_ok('pf::pfcmd::graph');
    use_ok('pf::pfcmd::report');
}

my @data_modules = qw(
    pf::action
    pf::class
    pf::configfile
    pf::ifoctetslog
    pf::iplog
    pf::locationlog
    pf::node
    pf::os
    pf::person
    pf::switchlocation
    pf::traplog
    pf::trigger
    pf::useragent
    pf::violation
    pf::pfcmd::dashboard
    pf::pfcmd::graph
    pf::pfcmd::report
);

foreach my $module (@data_modules) {

    # setup
    # grab the portion after the last ::
    $module =~ /\w+::(\w+)$/;
    my $var = $1."_db_prepared";
    my $method = $1."_db_prepare";

    # is there a prepared variable?
    ok(defined(${$var}), "$var exposed");

    # is there a prepare method?
    can_ok($module, $method) 
        or diag("no prepare method for data module! Never do such a thing, the pf::db module expects that method.");

    {
        no strict 'refs';
        is(&{$method}(), 1, "preparing statements for $module");

        # is prepared to the right value?
        is(${$var}, 1, "data is marked as prepared");
    }
}

