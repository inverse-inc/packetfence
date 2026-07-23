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

{
    no warnings 'redefine';
    *pfconfig::util::control_file_path = sub {
        my ($namespace) = @_;
        $namespace =~ s/\//;/g;
        return "$scratch_control_dir/$namespace-control";
    };
}

use Test::More tests => 23;
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

$manager->expire($overlay);
ok(!exists $manager->{memory}{$overlay}, "expiring an overlay evicts it from the L1 memory cache");
ok(!exists $manager->{memorized_at}{$overlay}, "expiring an overlay evicts its memorized_at timestamp");
ok(!exists $manager->{memory}{"ORDERED::$overlay"}, "expiring an overlay evicts its ordered copy");
ok(!defined $manager->{cache}->get($overlay), "expiring an overlay removes it from the L2 backend");

ok(defined $manager->get_cache($overlay), "overlay rebuilds on demand after being evicted");
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
