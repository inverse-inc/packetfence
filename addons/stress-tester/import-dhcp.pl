#!/usr/bin/perl

use strict;
use warnings;

use Text::CSV;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::api;

my $csv = Text::CSV->new ( { binary => 1, sep_char => '|' } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

open my $fh, "<:encoding(utf8)", "/usr/local/pf/addons/stress-tester/mock_data.csv" or die "$!";

# username|password|mac_address|ip_address|dhcp_fingerprint|dhcp_vendor
my $first = 1;
while ( my $row = $csv->getline( $fh ) ) {
    # skip first line (header)
    if($first) {
        $first = 0;
        next;
    }
    my $mac = $row->[2];
    my $ip = $row->[3];
    print "Processing $mac/$ip \n";
    pf::api->update_ip4log(mac => $mac, ip => $ip);
}


