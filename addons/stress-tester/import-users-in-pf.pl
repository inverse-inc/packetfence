#!/usr/bin/perl

use strict;
use warnings;

use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use Text::CSV;
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
    my $user = $row->[0];
    my $pass = $row->[1];
    print "Processing $user/$pass\n";
    my @actions = (
	pf::Authentication::Action->new(class => "authentication", type => "expiration", value => "2038-01-01 00:00:00"),
	pf::Authentication::Action->new(class => "authentication", type => "set_unreg_date", value => "2038-01-01 00:00:00"),
	pf::Authentication::Action->new(class => "authentication", type => "set_role", value => "default"),
    );
    pf::password::generate($user, \@actions, $pass, undef);
}


