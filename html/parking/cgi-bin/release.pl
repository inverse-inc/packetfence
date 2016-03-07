#!/usr/bin/perl
use strict;
use warnings;
use lib '/usr/local/pf/lib';

use CGI qw(:standard);

use pf::parking;

my $ip = $ENV{REMOTE_ADDR};
my $mac = pf::iplog::ip2mac($ip);

if(pf::parking::unpark($mac, $ip)){
    print redirect("/back-on-network.html");
}
else {
    print redirect("/max-attempts.html");
}

 
