#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
use Test::More tests => 7;
use Test::NoWarnings;

BEGIN { use_ok('pf::node') }

# method that we can test with a database that won't alter data and that need no parameters
my @simple_methods = qw(
    node_db_prepare
    node_view_all
    node_count_all
);

# Test methods with no parameters, assume no warnings and some results
{
    no strict 'refs';

    foreach my $method (@simple_methods) {
    
        ok(defined(&{$method}()), "testing $method call");
    }
}

# node_view_with_fingerprint returns 0 on failure, test against that
ok(node_view_with_fingerprint('aa:bb:cc:dd:ee:ff'), "node_view_with_fingerprint SQL query pass");

# node_view returns 0 on failure, test against that
ok(node_view('aa:bb:cc:dd:ee:ff'), "node_view SQL query pass");

# TODO add more tests, we should test:
#  - node_view on a node with no category should be empty ('') category and not undef (see #1063)
#  - all methods with mocked db call (replacing db_query... and db_data with happy returns ok stuff) GOAL: is module code valid
#  - all methods with mocked db driver or straight to db GOAL: is SQL valid or not
