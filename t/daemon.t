#!/usr/bin/perl
=head1 NAME

daemon

=cut

=head1 DESCRIPTION

daemon

=cut

use strict;
use warnings;
use Time::HiRes qw(sleep);
use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 14;                      # last test to print

use Test::NoWarnings;

use_ok('pf::services::manager');

my $sm = pf::services::manager->new(
    executable => '/usr/local/pf/t/services/dummy',
    launcher => '%1$s',
    name => 'dummy'
);

isa_ok($sm,"pf::services::manager");

$sm->start;

my $pid = $sm->pid;

ok($pid,"Pid return $pid");

ok(isAlive($pid), "Process is running");

kill 9, $pid;
#Give it a little time
waitForPid($pid);

ok(-e $sm->pidFile,"Pidfile there after force kill of process");

$sm->removeStalePid;

ok(!(-e $sm->pidFile),"The stale pid removed");

$sm->watch;

sleep(0.1);

#Give it a little time
$pid = $sm->pid;

ok($pid,"Pid return $pid after watch");

ok(isAlive($pid), "Process is running after watch");

$sm->stop;

ok(!isAlive($pid),"Process is stopped");

ok(!-e $sm->pidFile,"Pidfile is removed after stopping");

$sm->start;

$pid = $sm->pid;

ok($pid,"Pid return $pid");

ok(isAlive($pid), "Process is running");

$sm->restart;

my $newpid = $sm->pid;

ok($pid != $newpid && isAlive($newpid),"Restart is successful");

sub isAlive {
    my ($pid) = @_;
    return kill 0, $pid;
}

sub waitForPid {
    my ($pid) = @_;
    my $count = 0;
    while(isAlive($pid) && $count < 4  ) {
        sleep(0.1);
        $count++;
    }
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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


