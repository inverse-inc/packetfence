#!/usr/bin/perl
=head1 NAME

import-node-csv.pl - Mass importation of nodes

=head1 DESCRIPTION

Rough script for bulk importation of nodes. 
Use at your own risks.
One day L<pf::import> will support what we need and this script will be removed.

=head1 EXAMPLE

./import-node-csv.pl -mode=reg -file=/root/file.csv

=cut

require 5.8.5;
use strict;
use warnings;

use Data::Dumper;
use FindBin;
use Getopt::Long;
use Pod::Usage;
use Text::CSV;

use constant {
    LIB_DIR   => $FindBin::Bin . "/../lib",
};

use lib LIB_DIR;

use pf::node;
use pf::constants qw($ZERO_DATE);
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
my $now = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time) );
my %macHash = (
    'status' => 'reg',
    'regdate' => "$now",
    'notes' => 'Imported by script'
);

my $csv = Text::CSV->new({ binary => 1 });
open my $io, "<", $filename
    or die("Unable to import from file: $filename. Error: $!");

while (my $row = $csv->getline($io)) {

    my ($mac, $pid, $category) = @$row;

    # sanitizing
    $mac = clean_mac($mac);

    # providing defaults
    $pid = 'pf' if (!defined($pid));

    if (defined($mac) && defined($pid) && defined($category)) {
        if ($mode eq 'reg') {
            print "MAC: $mac\tCategory: $category\tPID: $pid\t - added to database\n";
            $macHash{'pid'} = $pid;
            $macHash{'category'} = $category;
            $macHash{'unregdate'} = $ZERO_DATE;
            node_add_simple($mac);
            node_modify( $mac, %macHash );
        } else {
            print "MAC: $mac\tCategory: $category\tPID: $pid\t == Test Mode\n";
        }
    } else {
        print "Invalid !\n";
    }
}

print "End of node bulk importation\n";
close $io;

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
