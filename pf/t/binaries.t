#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 20;

my @binaries = (
    '/usr/local/pf/addons/autodiscover.pl',
    '/usr/local/pf/addons/convertToPortSecurity.pl',
    '/usr/local/pf/addons/monitorpfsetvlan.pl',
    '/usr/local/pf/addons/recovery.pl',
    '/usr/local/pf/bin/accounting.pl',
    '/usr/local/pf/bin/flip.pl',
    '/usr/local/pf/bin/pfcmd_vlan',
    '/usr/local/pf/cgi-bin/redir.cgi',
    '/usr/local/pf/cgi-bin/register.cgi',
    '/usr/local/pf/cgi-bin/release.cgi',
    '/usr/local/pf/contrib/802.1X/pfcmd_ap.pl',
    '/usr/local/pf/contrib/802.1X/rlm_perl_packetfence.pl',
    '/usr/local/pf/contrib/mrtg/mrtg-wrapper.pl',
    '/usr/local/pf/sbin/pfdetect',
    '/usr/local/pf/sbin/pfdhcplistener',
    '/usr/local/pf/sbin/pfmon',
    '/usr/local/pf/sbin/pfredirect',
    '/usr/local/pf/sbin/pfsetvlan',
    '/usr/local/pf/test/connect_and_read.pl',
    '/usr/local/pf/test/dhcp_dumper'
);

foreach my $currentBinary (@binaries) {
    ok( system("/usr/bin/perl -c $currentBinary 2&>1") == 0,
        "$currentBinary compiles" );
}
