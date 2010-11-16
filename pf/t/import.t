#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
use Test::More tests => 1;
use Test::NoWarnings;

BEGIN { use_ok('pf::import') }

# TODO add more tests, we should test:
# - import data/node-import-success.csv expect success
# - import data/node-import-fail-detect.csv expect a die
# - import data/node-import-fail-during.csv expect one warning on CLI output

# TODO potential integration tests (don't add here)
# - node_view unexistent
# - import
# - node_view that it exists
