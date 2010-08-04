#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 13;
use lib '/usr/local/pf/lib';

BEGIN { use_ok('pf::pfcmd::graph') }

# These tests validate that the graph methods produce non-zero output
ok(graph_registered('day'), 'graph registered day');
ok(graph_registered('month'), 'graph registered month');
ok(graph_registered('year'), 'graph registered year');

ok(graph_unregistered('day'), 'graph unregistered day');
ok(graph_unregistered('month'), 'graph unregistered month');
ok(graph_unregistered('year'), 'graph unregistered year');

ok(graph_violations('day'), 'graph violations day');
ok(graph_violations('month'), 'graph violations month');
ok(graph_violations('year'), 'graph violations year');

# graph_nodes needs to be evaluated in an array context to give useful output
my @tmp;
ok((@tmp = graph_nodes('day')), 'graph nodes day');
ok((@tmp = graph_nodes('month')), 'graph nodes month');
ok((@tmp = graph_nodes('year')), 'graph nodes year');
