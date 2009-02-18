#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::Harness;
runtests(qw(pf.t person.t SNMP.t SwitchFactory.t));
