#!/usr/bin/perl
=head1 NAME

overload add documentation

=cut

=head1 DESCRIPTION

overload

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::ConfigStore::Switch;
use pf::ConfigStore::SwitchOverlay;
use pf::SwitchFactory;
use pf::log;
use Time::HiRes qw(sleep);
use POSIX qw(:sys_wait_h pause);
my @switchIds = grep { defined $SwitchConfig{$_}{radiusSecret} && $SwitchConfig{$_}{radiusSecret} !~ /^\s+$/ } keys %SwitchConfig;

my $DEFAULT_CHILDREN_COUNT = $ARGV[0] || 10;

our %CHILDREN;
our $childPid;
our $currentCount = 0;
our $amountOfInteration;

our $running = 1;
our $childDied = 0;

$SIG{INT} = $SIG{TERM} = sub {
    $running = 0;
};

$SIG{CHLD} = sub {
    $childDied = 1;
};

sub startChildren {
    while ( $currentCount < $DEFAULT_CHILDREN_COUNT ) {
        my $childPid = fork();
        if($childPid > 0) {
            $currentCount++;
            print "$childPid\n";
            $CHILDREN{$childPid} = undef;
        } elsif($childPid == 0) {
            overloadPf();
            exit 0;
        } else {
            killChildren();
            exit 1;
        }
    }
}

startChildren();

while($running) {
    pause;
    if($childDied) {
        reapChildren();
        startChildren();
        $childDied = 0;
    }
}

killChildren();
while ($currentCount) {
#    print "$currentCount\n";
    reapChildren();
}

sub killChildren {
    my @kids = keys %CHILDREN;
    print "killing ",join(' ',@kids),"\n";
    my $cnt = kill 'TERM', @kids;
    print "$cnt Got it\n";
}

sub reapChildren {
    my $child;
    my $count = 0;
    while(1) {
        $child = waitpid(-1, &POSIX::WNOHANG);
        last unless $child > 0;
        $currentCount--;
        delete $CHILDREN{$child};
    }
}


sub overloadPf {
    my $amountOfInteration = int(rand(50)) + 51;
    my $logger = get_logger();
    RUNNING: while($running && $amountOfInteration) {
        foreach my $switchId (@switchIds) {
            last RUNNING unless $running;
            my $randomNameByte = int(rand(253)) + 1;
            my $controllerIp = "192.0.2.$randomNameByte";
            $randomNameByte = int(rand(253)) + 1;
            my $switchIp = "192.0.1.$randomNameByte";
            my $switch = pf::SwitchFactory->getInstance()->instantiate({ switch_mac => $switchId, switch_ip => $switchIp, controllerIp => $controllerIp });
            my $sleepTime = int(rand(10)) + 3;
            sleep($sleepTime);
            pf::config::cached::ReloadConfigs();
            $logger->info("Finsih reloading configs");
        }
        $amountOfInteration--;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

