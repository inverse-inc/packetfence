#!/usr/bin/perl

=head1 NAME

lock

=head1 DESCRIPTION

unit test for pf::ConfigStore::lock_config

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
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile);
use Time::HiRes qw();
use pf::ConfigStore;
use pf::IniFiles;

#This test will running last
use Test::NoWarnings;

my $dir = tempdir(CLEANUP => 1);
my $file = catfile($dir, "lock.conf");
open(my $fh, '>', $file) or die "$file: $!";
print $fh "[existing]\nkey=value\n";
close($fh);

# Each writer reads the file, waits, then adds its section: without the lock the
# last writer would drop the other writer's section
sub writer {
    my ($section) = @_;
    my $pid = fork();
    die "fork: $!" unless defined $pid;
    return $pid if $pid;
    my $cs = pf::ConfigStore->new(configFile => $file);
    my $lock = $cs->lock_config;
    $cs->readAllIds;
    Time::HiRes::sleep(0.5);
    $cs->create($section, { key => $section });
    $cs->rewriteConfig;
    exit(defined $lock ? 0 : 1);
}

my @pids = map { writer($_) } qw(first second third);
my @failed = grep { waitpid($_, 0); $? != 0 } @pids;
is(scalar @failed, 0, "Every writer got the lock");

my $ini = pf::IniFiles->new(-file => $file, -allowempty => 1);
is_deeply([sort $ini->Sections], [qw(existing first second third)], "No section was lost by concurrent writers");

{
    my $first = pf::ConfigStore->new(configFile => $file);
    $first->lock_config;
    my $second = pf::ConfigStore->new(configFile => $file);
    ok($second->lock_config, "The lock is shared by the stores of the same process");
    undef $first;
    is($pf::ConfigStore::LOCKS{$file}{count}, 1, "The lock is kept while a store still uses it");

    my $child = fork();
    die "fork: $!" unless defined $child;
    if (!$child) {
        %pf::ConfigStore::LOCKS = ();
        local $pf::ConfigStore::LOCK_TIMEOUT = 0.3;
        my $other = pf::ConfigStore->new(configFile => $file);
        exit($other->lock_config ? 1 : 0);
    }
    waitpid($child, 0);
    is($? >> 8, 0, "The lock times out while another process holds it");
}

ok(!exists $pf::ConfigStore::LOCKS{$file}, "The lock is released once its stores are destroyed");

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
