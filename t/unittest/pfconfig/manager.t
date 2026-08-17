#!/usr/bin/perl

=head1 NAME

pfconfig::manager

=cut

=head1 DESCRIPTION

Tests the cache lifecycle of pfconfig::manager, notably that overlayed
namespaces are evicted on expiration instead of accumulating forever and
that unknown namespaces never create persistent state.

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use setup_test_config;
}

use File::Path qw(make_path remove_tree);
use File::Spec::Functions qw(catfile catdir);
use pfconfig::constants;
use pfconfig::util;

# Use the memory L2 backend and a scratch control dir so the test cannot
# interfere with a pfconfig instance sharing this machine
$pfconfig::constants::CONFIG_FILE_PATH = catfile($test_paths::test_dir, 'data/pfconfig.conf');
my $scratch_control_dir = catdir("/tmp", "pfconfig-manager-test-$$");
make_path($scratch_control_dir);
END { remove_tree($scratch_control_dir) if $scratch_control_dir }

# Redirect the control directory rather than control_file_path, so *discovery*
# (list_control_overlayed_namespaces) is redirected too. Overriding the path
# builder alone left expire_all enumerating the real /usr/local/pf/var/control and
# calling remove() on every overlay a live pfconfig had registered there.
#
# And stub the notification socket for the whole file: a manager without
# pfconfig_server set notifies pfconfig from cache_resource, so a test run on a
# machine with a live daemon was making that daemon expire its own namespaces.
{
    no warnings 'redefine';
    *pfconfig::util::control_file_dir = sub { return $scratch_control_dir };
    *pfconfig::util::socket_expire = sub { return 1 };
}

use Test::More tests => 38;
use Test::NoWarnings;

use_ok("pfconfig::manager");

my $manager = pfconfig::manager->new;
$manager->{pfconfig_server} = 1;

my $overlay = "config::Pf(manager-test-overlay)";

ok(defined $manager->get_cache($overlay), "overlay with an arbitrary argument builds on demand");
ok(exists $manager->{memory}{$overlay}, "overlay is stored in the L1 memory cache");
ok(defined $manager->{cache}->get($overlay), "overlay is stored in the L2 backend");

ok(defined $manager->get_cache_ordered($overlay), "ordered copy of the overlay is served");
ok(exists $manager->{memory}{"ORDERED::$overlay"}, "ordered copy of the overlay is stored in L1");
ok(-f pfconfig::util::control_file_path($overlay), "building an overlay creates its control file");

$manager->expire($overlay);
ok(!exists $manager->{memory}{$overlay}, "expiring an overlay evicts it from the L1 memory cache");
ok(!exists $manager->{memorized_at}{$overlay}, "expiring an overlay evicts its memorized_at timestamp");
ok(!exists $manager->{memory}{"ORDERED::$overlay"}, "expiring an overlay evicts its ordered copy");
ok(!defined $manager->{cache}->get($overlay), "expiring an overlay removes it from the L2 backend");
ok(!-f pfconfig::util::control_file_path($overlay), "expiring an overlay deletes its control file so it stops being rediscovered");

ok(defined $manager->get_cache($overlay), "overlay rebuilds on demand after being evicted");
ok(-f pfconfig::util::control_file_path($overlay), "rebuilding an evicted overlay re-creates its control file");
$manager->expire($overlay);

my $unknown = eval { $manager->get_cache("totally::bogus(x)") };
is($@, '', "requesting an unknown namespace does not die");
ok(!defined $unknown, "unknown namespace returns undef");
ok(!exists $manager->{memory}{"totally::bogus(x)"}, "unknown namespace is not stored in L1");
ok(!defined $manager->{cache}->get("totally::bogus(x)"), "unknown namespace is not stored in L2");
ok(!-f pfconfig::util::control_file_path("totally::bogus(x)"), "unknown namespace does not create a control file");

my $unknown_ordered = eval { $manager->get_cache_ordered("totally::bogus") };
is($@, '', "unknown namespace via the ordered path does not die");
ok(!defined $unknown_ordered, "unknown namespace via the ordered path returns undef");
ok(!exists $manager->{memory}{"ORDERED::totally::bogus"}, "no undef ordered slot is stored for an unknown namespace");

$manager->{memory}{"config::GoneNamespace"} = {};
$manager->{memorized_at}{"config::GoneNamespace"} = time;
$manager->{memory}{"ORDERED::config::GoneNamespace"} = {};
$manager->expire_all(1);
ok(!exists $manager->{memory}{"config::GoneNamespace"}, "expire_all prunes L1 keys of namespaces that no longer exist");
ok(!exists $manager->{memorized_at}{"config::GoneNamespace"}, "expire_all prunes stale memorized_at keys");
ok(!exists $manager->{memory}{"ORDERED::config::GoneNamespace"}, "expire_all prunes stale ordered keys");

=head2 The expire path must not construct namespaces

expire only needs each namespace's child_resources, but it used to obtain them by
constructing the namespace object. Most namespaces read their dependencies with
get_cache inside init, so that reached the L2 backend and deserialized a config
blob per namespace and per child, on every expire request. A single
`pfcmd pfconfig reload` fanned that out to thousands of L2 reads, leaked a few MB
of retained config per reload, and eventually corrupted memory badly enough to
segfault the daemon.

=cut

{
    my $counting_manager = pfconfig::manager->new;
    $counting_manager->{pfconfig_server} = 1;

    my $constructions = 0;
    my $overlay_scans = 0;
    my %constructed;
    my $real_get_namespace = \&pfconfig::manager::get_namespace;
    my $real_all_overlayed = \&pfconfig::manager::all_overlayed_namespaces;
    {
        no warnings 'redefine';
        *pfconfig::manager::get_namespace = sub {
            $constructions++;
            $constructed{$_[1]}++;
            return $real_get_namespace->(@_);
        };
        *pfconfig::manager::all_overlayed_namespaces = sub { $overlay_scans++; return $real_all_overlayed->(@_) };
    }

    # First run warms the child graph memo
    $counting_manager->expire_all(1);
    ok($constructions > 0, "the first expire_all has to construct namespaces to learn the child graph");
    is($overlay_scans, 1, "the first expire_all enumerates the overlays exactly once");

    $constructions = 0;
    $overlay_scans = 0;
    $counting_manager->expire_all(1);
    is($constructions, 0, "a second expire_all constructs no namespaces at all");
    is($overlay_scans, 1, "a second expire_all still enumerates the overlays exactly once");

    # A single namespace expire must be just as cheap
    $constructions = 0;
    $counting_manager->expire("config::Pf", 1);
    is($constructions, 0, "expiring one namespace constructs nothing once the memo is warm");

    # cache_resource needs an object to know the namespace exists at all, and
    # config_builder needs one to call build() on. Letting each fetch its own paid
    # init() -- the expensive, leaky half -- twice for the same namespace. Counted
    # per name: the build legitimately constructs its dependencies (config::PfDefault,
    # config::Documentation, config::Cluster(DEFAULT)) once each on the way.
    %constructed = ();
    $counting_manager->cache_resource("config::Pf()");
    is($constructed{"config::Pf()"}, 1, "building a namespace constructs it exactly once, not twice");

    {
        no warnings 'redefine';
        *pfconfig::manager::get_namespace = $real_get_namespace;
        *pfconfig::manager::all_overlayed_namespaces = $real_all_overlayed;
    }
}

# child_resources_for must not blow up on a namespace that cannot be loaded --
# get_namespace documents an undef return and the old code dereferenced it blindly
my $bogus_children = eval { $manager->child_resources_for("totally::bogus") };
is($@, '', "child_resources_for on an unknown namespace does not die");
is_deeply($bogus_children, [], "child_resources_for returns an empty list for an unknown namespace");

# The memo must reproduce the real child graph, not an empty one
{
    my $fresh = pfconfig::manager->new;
    my $from_object = $fresh->get_namespace("config::Pf()")->{child_resources};
    is_deeply($fresh->child_resources_for("config::Pf"), $from_object,
        "the memoised child graph matches what the namespace object declares");
    is_deeply($fresh->child_resources_for("config::Pf"), $from_object,
        "the memoised child graph is stable on a second call");
}

# The memo must not grow per overlay argument. expire treats an overlay as terminal
# and never asks for its children, so an entry per argument would be an unbounded
# cache of something nothing reads -- the very growth overlay eviction bounds.
{
    my $fresh = pfconfig::manager->new;
    $fresh->{pfconfig_server} = 1;
    $fresh->child_resources_for("config::Pf");
    $fresh->get_cache("config::Pf(memo-host-a)");
    $fresh->get_cache("config::Pf(memo-host-b)");

    my @overlay_keys = grep { /\(.+\)$/ } keys %{$fresh->{child_resources_cache}};
    is_deeply(\@overlay_keys, [], "building overlays adds no per-argument child graph entries");
    ok(exists $fresh->{child_resources_cache}{"config::Pf()"},
        "the static namespace behind those overlays is still memoised");
}

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
