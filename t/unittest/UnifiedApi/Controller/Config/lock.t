#!/usr/bin/perl

=head1 NAME

lock

=head1 DESCRIPTION

The config controllers lock the config file for the writes only: a search
(POST) is answered while another writer holds the lock (#8959)

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
use Test::Mojo;
use File::Temp qw(tempdir);
use Time::HiRes qw();
use pf::ConfigStore;
use pf::ConfigStore::Switch;

#This test will running last
use Test::NoWarnings;

my $dir = tempdir(CLEANUP => 1);
local $pf::ConfigStore::run_dir = $dir;
local $pf::ConfigStore::LOCK_TIMEOUT = 1;

my $t = Test::Mojo->new('pf::UnifiedApi');

# Another writer holds the lock of the switches config file
pipe(my $ready_r, my $ready_w) or die "pipe: $!";
pipe(my $done_r, my $done_w) or die "pipe: $!";
my $pid = fork();
die "fork: $!" unless defined $pid;
if (!$pid) {
    close($ready_r);
    close($done_w);
    %pf::ConfigStore::LOCKS = ();
    my $cs = pf::ConfigStore::Switch->new;
    my $locked = $cs->lock_config;
    syswrite($ready_w, $locked ? "1" : "0");
    sysread($done_r, my $buf, 1);
    exit(0);
}
close($ready_w);
close($done_r);
sysread($ready_r, my $locked, 1);
is($locked, "1", "Another process holds the lock of the switches config file");

my $start = Time::HiRes::time();
$t->post_ok('/api/v1/config/switches/search' => json => { fields => ['id'], limit => 1 })
  ->status_is(200);
cmp_ok(Time::HiRes::time() - $start, '<', 1, "The search doesn't wait for the lock");

$t->post_ok('/api/v1/config/switches/bulk_delete' => json => { items => ['lock_test_does_not_exist'] })
  ->status_is(503);

syswrite($done_w, "1");
waitpid($pid, 0);

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
