#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use lib  getcwd . '/lib';

use Test::More tests => 1; 

use_ok('pf::StatsD'); 
