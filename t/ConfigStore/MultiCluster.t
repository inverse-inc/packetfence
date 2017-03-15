#!/usr/bin/perl
=head1 NAME

MultiCluster configstore related tests

=cut

=head1 DESCRIPTION

MultiCluster configstore related tests

=cut

use strict;
use warnings;
use File::Temp;
use Config::IniFiles;
use Data::Dumper;

use Test::More tests => 67;

use Test::NoWarnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use setup_test_config;
    use File::Temp qw(tempdir);
    # TODO: change this to cleanup 1
    $pf::file_paths::multi_cluster_conf_dir = tempdir(CLEANUP => 0);
}

my $cs_class = "pf::ConfigStore::Domain";

# Tests for a configstore that doesn't have a defaults file
use_ok($cs_class);

my $global_scope = "global";
my $child_scope = join("/", $global_scope, "child");
my $cluster_scope = join("/", $child_scope, "cluster");

# create last-level specific data
my $cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);

$cluster_cs->update_or_create("test", {"test" => "cluster"});

$cluster_cs->commit();

# validate the section was written
my $ini = Config::IniFiles->new(-file => $cluster_cs->configFile, -allowempty => 1) or die Dumper(@Config::IniFiles::errors);
is($ini->exists("test", "test"), 1, "test.test was written properly to file");


my $section = $cluster_cs->read("test");
is($section->{test}, "cluster", "test.test was written properly to ConfigStore");

# create mid-level specific data
my $child_cs = $cs_class->new(multiClusterHost => $child_scope);

$child_cs->update_or_create("test", { "test" => "child" });
$child_cs->update_or_create("test", { "test2" => "child" });

$child_cs->commit();

$cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);

$section = $cluster_cs->read("test");
is($section->{test}, "cluster", "scope overriden attribute is still overriden");
is($section->{test2}, "child", "scope non-overriden attribute picks up the parent value");

# create top-level specific data
my $global_cs = $cs_class->new(multiClusterHost => $global_scope);

$global_cs->update_or_create("test", {"test" => "global", "test2" => "global", "test3" => "global"});

$global_cs->commit();

# validate the section was written only where it should have
$ini = Config::IniFiles->new(-file => $global_cs->configFile, -allowempty => 1) or die Dumper(@Config::IniFiles::errors);
is($ini->exists("test", "test"), 1, "test.test was written properly to file");
is($ini->exists("test", "test2"), 1, "test.test2 was written properly to file");
is($ini->exists("test", "test3"), 1, "test.test3 was written properly to file");

$ini = Config::IniFiles->new(-file => $child_cs->configFile, -allowempty => 1) or die Dumper(@Config::IniFiles::errors);
is($ini->exists("test", "test"), 1, "test.test was written properly to file");
is($ini->exists("test", "test2"), 1, "test.test2 was written properly to file");
is($ini->exists("test", "test3"), '', "test.test3 was not written to file");

$ini = Config::IniFiles->new(-file => $cluster_cs->configFile, -allowempty => 1) or die Dumper(@Config::IniFiles::errors);
is($ini->exists("test", "test"), 1, "test.test was written properly to file");
is($ini->exists("test", "test2"), '', "test.test2 was not written to file");
is($ini->exists("test", "test3"), '', "test.test3 was not written to file");

# check the mid-level picks up the top-level data
$child_cs = $cs_class->new(multiClusterHost => $child_scope);
$section = $child_cs->read("test");

is($section->{test}, "child", "scope overriden attribute is still overriden");
is($section->{test2}, "child", "scope overriden attribute is still overriden");
is($section->{test3}, "global", "scope non-overriden attribute picks up the parent value");

# check the last-level picks up the top-level data
$cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);
$section = $cluster_cs->read("test");

is($section->{test}, "cluster", "scope overriden attribute is still overriden");
is($section->{test2}, "child", "scope overriden attribute is still overriden");
is($section->{test3}, "global", "scope non-overriden attribute picks up the parent value");

# remove inherited value from mid-level file which should disapear from the bottom level
$child_cs = $cs_class->new(multiClusterHost => $child_scope);

$child_cs->update_or_create("test", {"test2" => undef});

$child_cs->commit();

# check the last-level picks up the the right data
$cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);
$section = $cluster_cs->read("test");

is($section->{test}, "cluster", "scope overriden attribute is still overriden");
is($section->{test2}, "global", "scope overriden attribute is still overriden");
is($section->{test3}, "global", "scope non-overriden attribute picks up the parent value");

# remove top-level inherited value which should disapear from the mid-level and last-level
$global_cs = $cs_class->new(multiClusterHost => $global_scope);

$global_cs->update_or_create("test", {"test2" => undef});

$global_cs->commit();

# check the mid-level picks up the the right data
$child_cs = $cs_class->new(multiClusterHost => $child_scope);
$section = $child_cs->read("test");

is($section->{test}, "child", "scope overriden attribute is still overriden");
is($section->{test2}, undef, "scope overriden attribute is still overriden");
is($section->{test3}, "global", "scope non-overriden attribute picks up the parent value");

# check the last-level picks up the the right data
$cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);
$section = $cluster_cs->read("test");

is($section->{test}, "cluster", "scope overriden attribute is still overriden");
is($section->{test2}, undef, "scope overriden attribute is still overriden");
is($section->{test3}, "global", "scope non-overriden attribute picks up the parent value");


# modify last-level data so its now the same as the top-level and check the file doesn't contain the section anymore
$cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);

$cluster_cs->update_or_create("test", {"test" => "child"});

$cluster_cs->commit();

$ini = Config::IniFiles->new(-file => $cluster_cs->configFile, -allowempty => 1) or die Dumper(@Config::IniFiles::errors);
is($ini->exists("test", "test"), '', "test.test doesn't exist after it became the same value as the parent");

# Tests for a configstore that has a defaults file
$cs_class = "pf::ConfigStore::Realm";

use_ok($cs_class);

my $global_scope = "global";
my $child_scope = join("/", $global_scope, "child");
my $cluster_scope = join("/", $child_scope, "cluster");

# create last-level specific data
my $cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);

$cluster_cs->update_or_create("test", {"test" => "cluster"});

$cluster_cs->commit();

# validate the section was written
my $ini = Config::IniFiles->new(-file => $cluster_cs->configFile, -allowempty => 1) or die Dumper(@Config::IniFiles::errors);
is($ini->exists("test", "test"), 1, "test.test was written properly to file");

is($cluster_cs->hasId("NULL"), 1, "inherited section from defaults file is there");

my $section = $cluster_cs->read("test");
is($section->{test}, "cluster", "test.test was written properly to ConfigStore");

# create mid-level specific data
my $child_cs = $cs_class->new(multiClusterHost => $child_scope);

$child_cs->update_or_create("test", { "test" => "child" });
$child_cs->update_or_create("test", { "test2" => "child" });

$child_cs->commit();

$cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);

$section = $cluster_cs->read("test");
is($section->{test}, "cluster", "scope overriden attribute is still overriden");
is($section->{test2}, "child", "scope non-overriden attribute picks up the parent value");

is($child_cs->hasId("NULL"), 1, "inherited section from defaults file is there");
is($cluster_cs->hasId("NULL"), 1, "inherited section from defaults file is there");

# create top-level specific data
my $global_cs = $cs_class->new(multiClusterHost => $global_scope);

$global_cs->update_or_create("test", {"test" => "global", "test2" => "global", "test3" => "global"});

$global_cs->commit();

# validate the section was written only where it should have
$ini = Config::IniFiles->new(-file => $global_cs->configFile, -allowempty => 1) or die Dumper(@Config::IniFiles::errors);
is($ini->exists("test", "test"), 1, "test.test was written properly to file");
is($ini->exists("test", "test2"), 1, "test.test2 was written properly to file");
is($ini->exists("test", "test3"), 1, "test.test3 was written properly to file");

$ini = Config::IniFiles->new(-file => $child_cs->configFile, -allowempty => 1) or die Dumper(@Config::IniFiles::errors);
is($ini->exists("test", "test"), 1, "test.test was written properly to file");
is($ini->exists("test", "test2"), 1, "test.test2 was written properly to file");
is($ini->exists("test", "test3"), '', "test.test3 was not written to file");

$ini = Config::IniFiles->new(-file => $cluster_cs->configFile, -allowempty => 1) or die Dumper(@Config::IniFiles::errors);
is($ini->exists("test", "test"), 1, "test.test was written properly to file");
is($ini->exists("test", "test2"), '', "test.test2 was not written to file");
is($ini->exists("test", "test3"), '', "test.test3 was not written to file");

is($global_cs->hasId("NULL"), 1, "inherited section from defaults file is there");
is($child_cs->hasId("NULL"), 1, "inherited section from defaults file is there");
is($cluster_cs->hasId("NULL"), 1, "inherited section from defaults file is there");

# check the mid-level picks up the top-level data
$child_cs = $cs_class->new(multiClusterHost => $child_scope);
$section = $child_cs->read("test");

is($section->{test}, "child", "scope overriden attribute is still overriden");
is($section->{test2}, "child", "scope overriden attribute is still overriden");
is($section->{test3}, "global", "scope non-overriden attribute picks up the parent value");

# check the last-level picks up the top-level data
$cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);
$section = $cluster_cs->read("test");

is($section->{test}, "cluster", "scope overriden attribute is still overriden");
is($section->{test2}, "child", "scope overriden attribute is still overriden");
is($section->{test3}, "global", "scope non-overriden attribute picks up the parent value");

# remove inherited value from mid-level file which should disapear from the bottom level
$child_cs = $cs_class->new(multiClusterHost => $child_scope);

$child_cs->update_or_create("test", {"test2" => undef});

$child_cs->commit();

# check the last-level picks up the the right data
$cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);
$section = $cluster_cs->read("test");

is($section->{test}, "cluster", "scope overriden attribute is still overriden");
is($section->{test2}, "global", "scope overriden attribute is still overriden");
is($section->{test3}, "global", "scope non-overriden attribute picks up the parent value");

# remove top-level inherited value which should disapear from the mid-level and last-level
$global_cs = $cs_class->new(multiClusterHost => $global_scope);

$global_cs->update_or_create("test", {"test2" => undef});

$global_cs->commit();

# check the mid-level picks up the the right data
$child_cs = $cs_class->new(multiClusterHost => $child_scope);
$section = $child_cs->read("test");

is($section->{test}, "child", "scope overriden attribute is still overriden");
is($section->{test2}, undef, "scope overriden attribute is still overriden");
is($section->{test3}, "global", "scope non-overriden attribute picks up the parent value");

# check the last-level picks up the the right data
$cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);
$section = $cluster_cs->read("test");

is($section->{test}, "cluster", "scope overriden attribute is still overriden");
is($section->{test2}, undef, "scope overriden attribute is still overriden");
is($section->{test3}, "global", "scope non-overriden attribute picks up the parent value");


# modify last-level data so its now the same as the top-level and check the file doesn't contain the section anymore
$cluster_cs = $cs_class->new(multiClusterHost => $cluster_scope);

$cluster_cs->update_or_create("test", {"test" => "child"});

$cluster_cs->commit();

$ini = Config::IniFiles->new(-file => $cluster_cs->configFile, -allowempty => 1) or die Dumper(@Config::IniFiles::errors);
is($ini->exists("test", "test"), '', "test.test doesn't exist after it became the same value as the parent");



=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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



