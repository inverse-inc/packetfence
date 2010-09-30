#!/usr/bin/perl -w

=head1 NAME

loadMACintoDB.pl - load MACs from a flat file into PacketFence's database

TODO doc incomplete

=cut
use strict;
use warnings;
use diagnostics;

use Log::Log4perl qw(:easy);
use Getopt::Long;
use FindBin;
use Data::Dumper;

use constant {
    LIB_DIR   => $FindBin::Bin . "/../lib",
};

use lib LIB_DIR;

require 5.8.5;
use pf::node;
use pf::db;
use pf::util;

my $filename;
my $mode = "test";

GetOptions(
    "mode=s" => \$mode,
    "file:s" => \$filename,
) ;

if (! ($mode =~ /^test|reg$/)) {
    pod2usage("\nthe 'mode' argument must be 'test' or 'reg'\n");
}
if (! defined($filename)) {
    print "The 'file' argument must be specified\n";
    exit 0;
}

if (!(-e $filename)) {
    print "File $filename does not exists !\n";
    exit 0;
}

my $mysql_connection = db_connect();
if (! $mysql_connection) {
    print "coudn't connect to MySQL server: " . DBI->errstr;
    exit 0;
}

my $mac;
my %macHash = (
    'status' => 'reg',
#    'vlan' => '1',
);

open (MYFILE, $filename);
while (<MYFILE>) {
    chomp;
    $mac = $_;
    print "$mac\t==\t";
    if (length($mac) eq 12) {
        if ($mode eq 'reg') {
            print "$mac\n";
            node_modify($mac, %macHash);
            foreach my $field (keys %macHash) {
                print "$field: $macHash{$field}\n";
            }
        } else {
            print "$mac\t == Test Mode\n";
        }
    } else {
        print "Invalid !\n";
    }
}

close (MYFILE);

=head1 AUTHOR

Regis Balzard <rbalzard@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
