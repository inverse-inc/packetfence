#!/usr/bin/perl

use lib '/usr/local/pf/lib';

use strict;
use warnings;

use pf::db;

if(my $dbh = db_connect()) {
    my $sth = $dbh->prepare("select * from information_schema.processlist;");
    $sth->execute() or die "Can't list the connections";
    my $count = $sth->rows;
    
    $sth = $dbh->prepare("show variables like 'max_connections';");
    $sth->execute() or die "Can't find the max connections";
    my $max = $sth->fetchrow_hashref()->{Value};

    print "Max connections is: $max \n";

    # If we go over 90% of the max connections, then we're in trouble
    my $threshold = int($max * 0.9);

    print "Alert threshold is: $threshold \n";
    print "Active connections: $count \n";

    if(($count - 1) > $threshold) {
        die "Too many connections to the database: $count. Consider raising the connections limit or investigate the high amount of connections. \n"
    }
}
