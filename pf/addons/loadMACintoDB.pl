#!/usr/bin/perl -w

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
        } else {
            print "$mac\t == Test Mode\n";
        }
    } else {
        print "Invalid !\n";
    }
}

close (MYFILE);


# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
