#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use lib  getcwd . '/lib';

use Test::More tests => 1; 

use_ok('pf::StatsD'); 
