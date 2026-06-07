#!/usr/bin/perl

=head1 NAME

Logs_ClusterHistory

=head1 DESCRIPTION

unit test for pf::UnifiedApi::Controller::Logs::ClusterHistory

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

use pf::UnifiedApi::Controller::Logs::ClusterHistory;

# This package compiles and is callable; functional coverage of the standalone
# fallback and the per-peer fan-out comes from the manual curl smoke-test on
# the cluster (see plan section 5.B / 5.A).
ok(defined &pf::UnifiedApi::Controller::Logs::ClusterHistory::query,
    'query action defined');

ok(pf::UnifiedApi::Controller::Logs::ClusterHistory->isa('pf::UnifiedApi::Controller::RestRoute'),
    'inherits from RestRoute');
