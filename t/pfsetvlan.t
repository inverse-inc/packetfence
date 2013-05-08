#!/usr/bin/perl -w
=head1 NAME

pfsetvlan.t

=head1 DESCRIPTION

pfsetvlan daemon tests

=cut
use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More tests => 5;
use Test::NoWarnings;

use Log::Log4perl;
use File::Basename qw(basename);

Log::Log4perl->init("log.conf");
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
/sx; # s for multiline support (if we encounter an Hex 0a which is encoded as a newline in STRING)

# This was before my time here so I'm not sure if it's v1 or a specific net-snmp version
my $trap = "2010-04-19|21:43:26|192.168.1.61|0.0.0.0|BEGIN TYPE 0 END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.2.1.1.3.0 = Timeticks: (89282331) 10 days, 8:00:23.31|.1.3.6.1.6.3.1.1.4.1.0 = OID: .1.3.6.1.4.1.9.9.315.0.0.1|.1.3.6.1.2.1.2.2.1.1.10003 = Wrong Type (should be INTEGER): Gauge32: 10003|.1.3.6.1.2.1.31.1.1.1.1.10003 = STRING: FastEthernet0/3|.1.3.6.1.4.1.9.9.315.1.2.1.1.10.10003 = Hex-STRING: 90 E6 BA 70 E7 4B  END VARIABLEBINDINGS";
ok($trap =~ /$TRAP_PATTERN/, "Trap pattern matches SNMPv1 traps");

# This was before my time here so I'm not sure if it's v2c or a specific net-snmp version
$trap = "2010-04-19|21:43:26|UDP: [192.168.1.61]:52281|0.0.0.0|BEGIN TYPE 0 END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.2.1.1.3.0 = Timeticks: (89282331) 10 days, 8:00:23.31|.1.3.6.1.6.3.1.1.4.1.0 = OID: .1.3.6.1.4.1.9.9.315.0.0.1|.1.3.6.1.2.1.2.2.1.1.10003 = Wrong Type (should be INTEGER): Gauge32: 10003|.1.3.6.1.2.1.31.1.1.1.1.10003 = STRING: FastEthernet0/3|.1.3.6.1.4.1.9.9.315.1.2.1.1.10.10003 = Hex-STRING: 90 E6 BA 70 E7 4B  END VARIABLEBINDINGS";
ok($trap =~ /$TRAP_PATTERN/, "Trap pattern matches SNMPv2c traps");

# Starting with Net-SNMP v5.4 trap format changed to add the ->[ip] thingy
$trap = "2010-04-01|13:32:16|UDP: [127.0.0.1]:33469->[127.0.0.1]|217.117.225.53|BEGIN TYPE 6 END TYPE BEGIN SUBTYPE .0 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.6.3.1.1.4.1.0 = OID: .1.3.6.1.4.1.29464.1.1|.1.3.6.1.2.1.2.2.1.1.5 = INTEGER: 5 END VARIABLEBINDINGS";
ok($trap =~ /$TRAP_PATTERN/, "Trap pattern matches Net-SNMP v5.4 traps");

# reproducing the newline encoding problem of #1098
$trap = '2011-05-19|19:36:21|UDP: [10.0.0.51]:1025|10.0.0.51|BEGIN TYPE 6 END TYPE BEGIN SUBTYPE .5 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.4.1.45.1.6.5.3.12.1.1.1.24 = INTEGER: 1|.1.3.6.1.4.1.45.1.6.5.3.12.1.2.1.24 = INTEGER: 24|.1.3.6.1.4.1.45.1.6.5.3.12.1.3.1.24 = STRING: "\\\\&
8xG" END VARIABLEBINDINGS';
ok($trap =~ /$TRAP_PATTERN/, "Trap pattern matches multiline trap (issue 1098)");

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

