#!/usr/bin/perl -w
#
# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

use strict;
use warnings;
use diagnostics;

use File::Tail;
use threads;
use threads::shared;
use FindBin;
use Log::Log4perl qw(:easy);
use Log::Log4perl::Appender;
use Log::Log4perl::Appender::File;
use Data::Dumper;

use constant {
    SNMPLOG_FILE => $FindBin::Bin . "/../logs/snmptrapd.log",
    LOG_FILE     => $FindBin::Bin . "/../logs/pfsetvlan.log",
};

print "SNMP : " . SNMPLOG_FILE . "\n";
print "LOG  : " . LOG_FILE . "\n";

my %trapsReceivedSNMP : shared;
my %trapsReceivedSetVlan : shared;

my $monitorSnmpThread        = threads->new("monitorSnmp");
my $monitorSetVlanThread     = threads->new("monitorSetVlan");
my $monitorConcurrencyThread = threads->new("monitorConcurrency");

sub monitorSnmp {
    my $fh = new File::Tail(
        'name'        => SNMPLOG_FILE,
        'interval'    => 2,
        'maxinterval' => 2
    );

    my $currentTrapLine;
    my $completeTrapLine;
    my $inMultiLineTrap = 0;
    while ( defined( $currentTrapLine = $fh->read ) ) {
        $currentTrapLine =~ s/\r\n/\n/;
        chomp($currentTrapLine);
        if ( $currentTrapLine =~ m/BEGIN VARIABLEBINDINGS/ ) {
            if ( $currentTrapLine =~ m/END VARIABLEBINDINGS$/ ) {
                {
                    lock %trapsReceivedSNMP;
                    $trapsReceivedSNMP{$currentTrapLine} = time();
                }
            } else {

                #start multiLine read
                $inMultiLineTrap  = 1;
                $completeTrapLine = $currentTrapLine;
            }
        } else {
            if ($inMultiLineTrap) {
                $completeTrapLine .= " $currentTrapLine";
                if ( $currentTrapLine =~ m/END VARIABLEBINDINGS$/ ) {

                    #end multiLine read
                    $inMultiLineTrap = 0;
                    {
                        lock %trapsReceivedSNMP;
                        $trapsReceivedSNMP{$completeTrapLine} = time();
                    }
                }
            } else {
                print "ignoring non trap line $currentTrapLine\n";
            }
        }
    }
}

sub monitorSetVlan {
    my $fh = new File::Tail(
        'name'        => LOG_FILE,
        'interval'    => 2,
        'maxinterval' => 2
    );

    my $currentTrapLine;
    while ( defined( $currentTrapLine = $fh->read ) ) {
        if ( $currentTrapLine =~ /parsing trap (.+END VARIABLEBINDINGS)/ ) {
            {
                lock %trapsReceivedSetVlan;
                $trapsReceivedSetVlan{$1} = time();
            }
        }
    }
}

#check every second for received traps
sub monitorConcurrency {
    while (1) {
        {
            lock %trapsReceivedSNMP;
            lock %trapsReceivedSetVlan;
            foreach my $trap ( keys %trapsReceivedSNMP ) {
                if ( exists( $trapsReceivedSetVlan{$trap} ) ) {
                    my $timeDiff = $trapsReceivedSetVlan{$trap}
                        - $trapsReceivedSNMP{$trap};

#                    print "found trap in both with time diff of $timeDiff\n";
                    delete( $trapsReceivedSNMP{$trap} );
                    delete( $trapsReceivedSetVlan{$trap} );
                } else {

                    #                    print time() . "\n";
                    my $trapAge = time() - $trapsReceivedSNMP{$trap};
                    print
                        "cannot find trap $trap, $trapAge seconds old, in pfsetvlan\n";
                    if ( $trapAge > 120 ) {
                        print
                            "pfsetvlan does not seem to respond any more.\n";
                        print "problematic trap is $trap\n";

                #                        print time() . "RESTARTING IT NOW\n";
                #                        `/etc/rc.d/init.d/pfsetvlan restart`;
                #re-initialize hashes and wait for 5 seconds
                        %trapsReceivedSNMP    = ();
                        %trapsReceivedSetVlan = ();
                        sleep(5);

                        #                        return;
                    }
                }
            }

            #            print time() . "\n" . "-"x60 . "\n";
            #            print Dumper(%trapsReceivedSNMP);
            #            print Dumper(%trapsReceivedSetVlan);
        }
        sleep(1);
    }
}

$monitorSnmpThread->join();
$monitorSetVlanThread->join();
$monitorConcurrencyThread->join();

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
