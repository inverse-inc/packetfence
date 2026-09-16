#!/usr/bin/perl

=head1 NAME

cluster_check

=head1 DESCRIPTION

unit test for cluster_check

Resolving a configuration conflict expires every configuration store on every member of the
cluster, so it must only happen once the members have been running different versions for longer
than active_active.conflict_resolution_threshold, and never on the first divergent check.

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;

#This test will running last
use Test::NoWarnings;

use pf::CHI;
use pf::cluster;
use pf::config qw(%Config);
use pf::factory::pfcron::task;

my $threshold = $Config{active_active}{conflict_resolution_threshold};
ok($threshold > 0, "the conflict resolution threshold is configured");

my $cache = pf::CHI->new(namespace => 'clustering');
my $task  = pf::factory::pfcron::task->new('cluster_check');

my $resolved;
my $versions;
{
    no warnings 'redefine';
    *pf::cluster::get_all_config_version = sub { return ({}, $versions) };
    *pf::cluster::handle_config_conflict = sub { $resolved++ };
}

# Runs the task with the members having diverged $unhealthy_for seconds ago and the state having
# been checked $checked_ago seconds ago. Returns the number of conflict resolutions it triggered
sub run_task {
    my (%args) = @_;
    my $now = time;
    $versions = $args{versions} // { 1 => ['a'], 2 => ['b'] };
    $resolved = 0;
    $cache->set('last_config_healthy_timestamp', $now - $args{unhealthy_for});
    $cache->set('last_config_checked_timestamp', $now - ($args{checked_ago} // 0));
    $task->run();
    return $resolved;
}

is(run_task(unhealthy_for => 10), 0,
    "a divergence that just appeared is left alone");

is(run_task(unhealthy_for => $threshold - 60), 0,
    "a divergence younger than the threshold is left alone");

is(run_task(unhealthy_for => $threshold + 60), 1,
    "a divergence older than the threshold gets resolved");

is(run_task(unhealthy_for => $threshold + 60, versions => { 1 => ['a', 'b'] }), 0,
    "members running the same version are never resolved");

is(run_task(unhealthy_for => $threshold + 60, checked_ago => 3 * $task->interval), 0,
    "a state that hasn't been checked for more than 2 intervals is considered healthy again");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;
