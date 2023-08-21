#!/usr/bin/perl

=head1 NAME

pfqueue_check -

=head1 DESCRIPTION

pfqueue_check

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::file_paths qw($var_dir);
my $pfqueue_id = do {
    open(my $fh, "$var_dir/run/pfqueue.pid") or exit 0;
    my $f = '';
    {
        local $/ = undef;
        $f = <$fh>;
    }
    chomp($f);
    $f
};

unless ($pfqueue_id) {
    print "Cannot get the pfqueue pid\n";
    exit 0;
}

my $pfqueue_kids = qx/ps --no-headers --ppid ${pfqueue_id} -o ppid,pid,pcpu,etimes/;
my @kids = split(/\n/, $pfqueue_kids);
my @pids;
for my $kid (@kids) {
    $kid =~ s/^ *//;
    $kid =~ s/ *$//;
    next if $kid eq '';
    my ($parent, $pid, $cpu, $etimes) = split(/ +/, $kid);
    if (defined $etimes && $etimes > 30 && $cpu == 0) {
        push @pids, $pid;
    }
}

if (@pids) {
    print STDERR "pfqueue children are stuck ", join(" ", @pids), "\n";
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

