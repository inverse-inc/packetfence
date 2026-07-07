#!/usr/bin/perl

=head1 NAME

Pftest_Cluster

=head1 DESCRIPTION

unit test for pf::UnifiedApi::Controller::Pftest::Cluster

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 3;
use Test::NoWarnings;

use pf::UnifiedApi::Controller::Pftest::Cluster;

ok(defined &pf::UnifiedApi::Controller::Pftest::Cluster::authentication,
    'authentication action defined');
ok(defined &pf::UnifiedApi::Controller::Pftest::Cluster::profile_filter,
    'profile_filter action defined');
