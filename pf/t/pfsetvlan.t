#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 3;
use Log::Log4perl;
use File::Basename qw(basename);
use lib '/usr/local/pf/lib';

Log::Log4perl->init("/usr/local/pf/t/log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

# TODO: copied over here from pfsetvlan for now before we refactor the big blob into manageable (testable) pieces
my $TRAP_PATTERN = qr/
    ^\d{4}-\d{2}-\d{2}\|\d{2}:\d{2}:\d{2}\|             # date|time
    (?:UDP:\ \[)?                                       # Optional "UDP: [" (since v2 traps I think)
    (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})                # network device ip address
    (?:\]:\d+)?                                         # Optional "]:port" (since v2 traps I think)
    (?:\-\>\[\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\])?     # Optional "->[ip address]" (since net-snmp 5.4)
    \|([^|]*)\|                                         # Used to carry network device ip if it's a local trap
    (.+)$                                               # Trap message
/x;

# This was before my time here so I'm not sure if it's v1 or a specific net-snmp version
my $snmpv1_traps = "2010-04-19|21:43:26|192.168.1.61|0.0.0.0|BEGIN TYPE 0 END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.2.1.1.3.0 = Timeticks: (89282331) 10 days, 8:00:23.31|.1.3.6.1.6.3.1.1.4.1.0 = OID: .1.3.6.1.4.1.9.9.315.0.0.1|.1.3.6.1.2.1.2.2.1.1.10003 = Wrong Type (should be INTEGER): Gauge32: 10003|.1.3.6.1.2.1.31.1.1.1.1.10003 = STRING: FastEthernet0/3|.1.3.6.1.4.1.9.9.315.1.2.1.1.10.10003 = Hex-STRING: 90 E6 BA 70 E7 4B  END VARIABLEBINDINGS";

# This was before my time here so I'm not sure if it's v2c or a specific net-snmp version
my $snmpv2c_traps = "2010-04-19|21:43:26|UDP: [192.168.1.61]:52281|0.0.0.0|BEGIN TYPE 0 END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.2.1.1.3.0 = Timeticks: (89282331) 10 days, 8:00:23.31|.1.3.6.1.6.3.1.1.4.1.0 = OID: .1.3.6.1.4.1.9.9.315.0.0.1|.1.3.6.1.2.1.2.2.1.1.10003 = Wrong Type (should be INTEGER): Gauge32: 10003|.1.3.6.1.2.1.31.1.1.1.1.10003 = STRING: FastEthernet0/3|.1.3.6.1.4.1.9.9.315.1.2.1.1.10.10003 = Hex-STRING: 90 E6 BA 70 E7 4B  END VARIABLEBINDINGS";

# Starting with Net-SNMP v5.4 trap format changed to add the ->[ip] thingy
my $netsnmp_5dot4_traps = "2010-04-01|13:32:16|UDP: [127.0.0.1]:33469->[127.0.0.1]|217.117.225.53|BEGIN TYPE 6 END TYPE BEGIN SUBTYPE .0 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.6.3.1.1.4.1.0 = OID: .1.3.6.1.4.1.29464.1.1|.1.3.6.1.2.1.2.2.1.1.5 = INTEGER: 5 END VARIABLEBINDINGS";

ok($snmpv1_traps =~ /$TRAP_PATTERN/, "Trap pattern matches SNMPv1 traps");

ok($snmpv2c_traps =~ /$TRAP_PATTERN/, "Trap pattern matches SNMPv2c traps");

ok($netsnmp_5dot4_traps =~ /$TRAP_PATTERN/, "Trap pattern matches Net-SNMP v5.4 traps");
