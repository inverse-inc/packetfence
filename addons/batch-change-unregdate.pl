#!/usr/bin/perl
=head1 NAME

batch-change-unregdate.pl - Mass modification of unregdate for nodes in a list

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
use pf::db;
use pf::util;

my $filename;
my $unregdate;

GetOptions(
    "file:s" => \$filename,
    "unregdate:s" => \$unregdate,
) ;

if (! defined($filename)) {
    print "The 'file' argument must be specified\n";
    exit 0;
}

if (!(-e $filename)) {
    print "File $filename does not exists !\n";
    exit 0;
}

if ( ! $unregdate =~ /^\d{4}-\d\d-\d\d$/; ) {
    print "Invalid unregdate format $unregdate. Should be of this format YYYY-MM-DD\n";
    exit 0;
}

my $mysql_connection = db_connect();
if (! $mysql_connection) {
    print "Couldn't connect to MySQL server: " . DBI->errstr;
    exit 0;
}

my $mac;
my %macHash = ();

my $csv = Text::CSV->new({ binary => 1 });
open my $io, "<", $filename
    or die("Unable to import from file: $filename. Error: $!");

while (my $row = $csv->getline($io)) {

    my ($mac) = @$row;

    # sanitizing
    $mac = clean_mac($mac);

    if (defined($mac)) {
        print "MAC: $mac\tUnregdate: $unregdate\t - modified in database\n";
        $macHash{'unregdate'} = $unregdate . " 00:00:00";
        node_modify( $mac, %macHash );
    } else {
        print "Invalid !\n";
    }

}

print "End of node bulk modification\n";
close $io;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
