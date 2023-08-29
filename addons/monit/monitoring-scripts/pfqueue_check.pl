#!/usr/bin/perl

=head1 NAME

pfqueue_check -

=head1 DESCRIPTION

pfqueue_check

=cut

use strict;
use warnings;
use POSIX ":sys_wait_h";
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::file_paths qw($var_dir);
my $pfqueue_id = do {
    my $f = slurp( "$var_dir/run/pfqueue.pid");
    exit 0 unless defined $f;
    chomp($f);
    $f
};

sub slurp {
    my ($file) = @_;
    open(my $fh, $file) or return undef;
    my $f = '';
    {
        local $/ = undef;
        $f = <$fh>;
    }

    return $f;
}

unless ($pfqueue_id) {
    print "Cannot get the pfqueue pid\n";
    exit 0;
}

my $pfqueue_kids = qx/ps --no-headers --ppid ${pfqueue_id} -o pid,pcpu,etimes/;
my @kids = map {s/^ +//;s/ +$//;$_} grep { /\d+/ } split(/\n/, $pfqueue_kids);
my @pids;
for my $kid (@kids) {
    my ($pid, $cpu, $etimes) = split(/ +/, $kid);
    if (defined $etimes && $etimes > 60 && $cpu == 0) {
        push @pids, $pid;
    }
}

unless (@pids) {
    exit 0;
}

my %pids = map { $_ => 1 } @pids;
my $start = time();
while (keys %pids) {
    my $pid_list = join(",", keys %pids);
    my $info_list = qx/ps --no-headers --pid ${pid_list} -o pid,pcpu/;
    $info_list =~ s/^ *//mg;
    $info_list =~ s/ *$//mg;
    next if $info_list eq '';
    for my $info (split(/\n/, $info_list)) {
        my ($pid, $cpu) = split(/ +/, $info);
        if ($cpu != 0) {
            delete $pids{$pid};
        }
    }
} continue {
    last if (time() - $start) >= 2;
}

my @stucked_pids = keys %pids;
if (@stucked_pids) {
    print STDERR "pfqueue children are stuck ", join(" ", @stucked_pids), "\n";
}

if (@stucked_pids == @kids) {
    if (-e '/usr/bin/gcore') {
        open(my $null_fh, '>', '/dev/null');
        my @forks;
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        $mon++;
        $year+=1900;
        my $prefix = sprintf("/usr/local/pf/logs/pfqueue-%02d%02d%02d%02d%02d%02d-", $year, $mon, $mday, $hour, $min, $sec);
        local $SIG{CHLD} = sub {};
        my $nums = scalar @stucked_pids;
        for my $pid (@stucked_pids) {
            $nums--;
            my $fork = fork();
            if (!defined $fork) {
                next;
            }

            if ($fork == 0) {
                #gcore [-a] [-o filename] pid
                open(STDERR, ">", "/dev/null");
                open(STDOUT, ">", "/dev/null");
                exec('/usr/bin/gcore', '-o', "${prefix}${pid}.core", $pid);
            } else {
                push @forks, $fork;
            }

            if (@forks == 4 || $nums == 0) {
                for my $f (@forks) {
                    waitpid($f, 0);
                }
                @forks = ();
            }
        }
    }

    print STDERR "All children are stuck\n";
    exit 1;
}

=end

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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

