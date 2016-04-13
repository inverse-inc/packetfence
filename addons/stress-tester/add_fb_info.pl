#!/usr/bin/perl

use DBI;
use File::Slurp;

my $dbh = DBI->connect("dbi:SQLite:dbname=/root/pftester/fingerbank.sqlite3");

my $combinations = $dbh->selectall_hashref("select * from combination", id);

my @combination_ids = keys(%$combinations);
my $count = scalar(@combination_ids);

my $content = read_file("mock_data.csv");

my $new_content = "";
foreach my $line (split("\n", $content)){
    my $combination = $combinations->{$combination_ids[rand($count)]};
    my $dhcp_fingerprint = $dbh->selectrow_hashref("select value from dhcp_fingerprint where id=".$combination->{dhcp_fingerprint_id})->{value};
    my $dhcp_vendor = $dbh->selectrow_hashref("select value from dhcp_vendor where id=".$combination->{dhcp_vendor_id})->{value};
    $new_content .= "$line|$dhcp_fingerprint|$dhcp_vendor\n";
}

write_file("mock_data_with_fingerprinting.csv", $new_content);

