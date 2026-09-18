#!/usr/bin/perl
=head1 NAME

pfconfig validity

=cut

=head1 DESCRIPTION

Tests that the cache validity checks only compare timestamps that come from the same clock.

The control files in var/control are touched by whichever process expired a namespace, which is
often another container or another cluster member, and pfconfig reports its last touch cache with
its own clock. Comparing any of those to the local time makes every namespace look permanently
expired as soon as the clocks differ, which rebuilds the configuration over and over.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use setup_test_config;
}

use Test::More tests => 22;

use Test::NoWarnings;

use_ok("pfconfig::cached");
use_ok("pfconfig::manager");

my $ns           = 'testing_validity()';
my $manager      = pfconfig::manager->new;
my $control_file = pfconfig::util::control_file_path($ns);

# What get_cache and cache_resource do once they have loaded a namespace
my $load = sub { $manager->{control_timestamp}{$ns} = $manager->control_file_timestamp($ns) };

unlink($control_file);

ok(!$manager->is_valid($ns), "a namespace without a control file is invalid");
ok(-f $control_file, "the missing control file got created");

$load->();
ok($manager->is_valid($ns), "valid once loaded");

my $touched_at = $manager->touch_cache($ns);
ok(!$manager->is_valid($ns), "invalid after the namespace was expired");
is($touched_at, $manager->control_file_timestamp($ns),
    "touch_cache reports the timestamp of the expiration it did, which is what cache_resource records");

$load->();
ok($manager->is_valid($ns), "valid again once reloaded");

# Simulate another writer touching the file after our futimens but before
# touch_cache returns. The returned marker must still describe our own write.
{
    no warnings qw(redefine once);
    my $touch = \&pfconfig::manager::touch_file;
    my $own_timestamp;
    local *pfconfig::manager::touch_file = sub {
        $own_timestamp = $touch->(@_);
        my $later = time + 60;
        utime($later, $later, $_[0]) or die "cannot touch $_[0]: $!";
        return $own_timestamp;
    };
    local *pfconfig::manager::config_builder = sub { return { value => 'built' } };
    local $manager->{pfconfig_server} = 1;
    $manager->cache_resource($ns);
    is($manager->{control_timestamp}{$ns}, $own_timestamp,
        "a concurrent touch is not recorded as our expiration");
    ok(!$manager->is_valid($ns), "a concurrent expiration leaves the loaded resource invalid");
}

# An external builder cannot identify the timestamp of its remote expiration.
# It must reload from L2 before treating its memory entry as current.
{
    no warnings qw(redefine once);
    local *pfconfig::manager::config_builder = sub { return { value => 'external' } };
    local *pfconfig::git_storage::is_enabled = sub { return 0 };
    local *pfconfig::util::socket_expire = sub { $manager->touch_cache($ns); return 1 };
    local $manager->{pfconfig_server} = 0;
    $manager->cache_resource($ns);
    ok(!$manager->is_valid($ns), "external build does not adopt an unverified control timestamp");
    is_deeply($manager->get_cache($ns), { value => 'external' }, "external build is reloaded from L2");
    ok($manager->is_valid($ns), "the L2 reload establishes a valid control timestamp");
}

subtest 'external builds remain usable before the database is configured' => sub {
    {
        package BootstrapUnavailableCache;
        sub get { $_[0]->{reads}++; return undef }
        sub set { $_[0]->{writes}++; return undef }
    }
    no warnings qw(redefine once);
    my $builds = 0;
    my $expirations = 0;
    my $backend = bless { reads => 0, writes => 0 }, 'BootstrapUnavailableCache';
    local $manager->{cache} = $backend;
    local $manager->{pfconfig_server} = 0;
    local *pfconfig::manager::config_builder = sub { return { build => ++$builds } };
    local *pfconfig::git_storage::is_enabled = sub { return 0 };
    local *pfconfig::util::socket_expire = sub {
        $expirations++;
        $manager->touch_cache($ns);
        return 1;
    };
    delete $manager->{memory}{$ns};
    is_deeply($manager->get_cache($ns), { build => 1 }, 'build succeeds without L2');
    for (1 .. 3) {
        is_deeply($manager->get_cache($ns), { build => 1 }, 'reuse the bootstrap configuration');
    }
    is($builds, 1, 'repeated reads do not rebuild configuration');
    is($backend->{reads}, 1, 'repeated reads do not retry the unavailable database');
    is($backend->{writes}, 1, 'only the initial build attempts an L2 write');
    is($expirations, 1, 'the server still receives the expiration');

    my $later = time + 60;
    utime($later, $later, $control_file) or die "cannot touch $control_file: $!";
    ok(!$manager->is_valid($ns), 'another expiration invalidates the bootstrap configuration');
    is_deeply($manager->get_cache($ns), { build => 2 }, 'reload configuration after expiration');
    ok($manager->is_valid($ns), 'the rebuilt configuration is reusable');

    my $touch = \&pfconfig::manager::touch_file;
    local *pfconfig::manager::touch_file = sub {
        my $own_timestamp = $touch->(@_);
        utime($later, $later, $_[0]) or die "cannot touch $_[0]: $!";
        return $own_timestamp;
    };
    $manager->cache_resource($ns);
    ok(!$manager->is_valid($ns), 'fallback does not adopt a concurrent expiration');
    done_testing;
};

# The process that expired the namespace has a clock an hour ahead of ours
my $ahead = time + 3600;
utime($ahead, $ahead, $control_file) or die "cannot set the timestamp of $control_file: $!";
ok(!$manager->is_valid($ns), "a control file dated in the future is seen as expired once");

$load->();
ok($manager->is_valid($ns), "valid with a control file dated in the future");
ok($manager->is_valid($ns), "and on the accesses that follow, instead of rebuilding forever");

# The clock steps backwards
my $behind = time - 7200;
utime($behind, $behind, $control_file) or die "cannot set the timestamp of $control_file: $!";
ok(!$manager->is_valid($ns), "a control file dated in the past is seen as expired once");

$load->();
ok($manager->is_valid($ns), "and it settles on the next load");

# Same thing on the client side, where the last touch cache comes from pfconfig itself
my $cached = pfconfig::cached->new();
$cached->{_namespace} = $ns;

$pfconfig::cached::RELOADED_TOUCH_CACHE = time;
$pfconfig::cached::LAST_TOUCH_CACHE     = time + 3600;
$cached->set_in_subcache('key', 'value');
ok($cached->is_valid, "subcache stays valid when pfconfig's clock is ahead of ours");

$pfconfig::cached::LAST_TOUCH_CACHE = time + 3601;
ok(!$cached->is_valid, "subcache is invalidated when pfconfig reports a new last touch cache");

unlink($control_file);

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
