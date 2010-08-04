#!/usr/bin/perl

=head1 NAME

replay-snmptrapd-logs.pl - replay an snmptrapd log into snmptrapd in real time

=head1 SYNOPSIS

TODO
replay-snmptrapd-logs.pl [fh_logreplay] [command] [options]

 Command:
    -help          brief help message
    -man           full documentation

 Options:
    -switch        switch description
    -switchRegExp  regular expression for switch description
    -verbose       log verbosity level
                     0 : fatal messages
                     1 : warn messages
                     2 : info messages
                   > 2 : full debug
    -reassign      if set, re-assign switch port VLANs
    -synchronize   if set, synchronize locationlog entries
    -singleThread  if set, run in single thread (for debugging)

=head1 DESCRIPTION

replay an snmptrapd log into snmptrapd in real time

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010 Inverse inc.

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

use strict;
use warnings;
use diagnostics;

use Time::Local;
use IO::Handle;

#TODO put in arg
my $log_to_replay = "test.log";
open(my $fh_logreplay, "<", "$log_to_replay")
    or die $!;

#TODO put in arg
#my $snmptrapdlog = "/usr/local/pf/logs/snmptrapd.log";
my $snmptrapdlog = "out.log";
open(my $fh_snmptrapdlog, ">>", "$snmptrapdlog")
    or die $!;

# forces autoflush so each print won't be buffered
$fh_snmptrapdlog->autoflush(1);

# Operate on the file one line at a time
my $prev_time;
while (my $line = <$fh_logreplay>) { 

    if ($line =~ /(\d{4})-(\d{2})-(\d{2})\|(\d{2}):(\d{2}):(\d{2})\|  # YYYY-MM-DD|HH:MM:SS| matching each subelement
        /x) {

        # some date adjustments are made to fit timelocal format (thus the minuses)
        my $cur_time = timelocal($6, $5, $4, $3, $2-1, $1);
        if (defined($prev_time)) {

            my $delta_secs = $cur_time - $prev_time;

            # if time elapsed between current entry and previous one is negative then log is corrupted
            if ($delta_secs < 0) {

                warn("Skipping entry $1-$2-$3 $4:$5:$6 because time elapsed since previous entry is negative");

            } else {
                print "Pushed a line to the snmptrapd log and waiting for $delta_secs seconds\n";
                sleep($delta_secs);
                push_logline($line);
            }

        } else {

            # we are in our first pass
            push_logline($line);
        }

        $prev_time = $cur_time;
    }
}

close $fh_logreplay;
close $fh_snmptrapdlog;

sub push_logline {
    my $logline = shift;

    # append the logfile
    print $fh_snmptrapdlog "$logline";
}

# vim: set autoindent:
# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set tabstop=4:
# vim: set backspace=indent,eol,start:
