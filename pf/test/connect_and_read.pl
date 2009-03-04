#!/usr/bin/perl -w

# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

=head1 NAME

connect_and_read.pl - try to connect to all switches and execute
                      some simple read commands

=head1 SYNOPSIS

connect_and_read.pl [options]

 Command:
   -help           brief help message
   -man            full documentation

 Options:
   -verbose        log verbosity level
                     0 : fatal messages
                     1 : warn messages
                     2 : info messages
                     3 : debug
                    >3 : trace
                 

=head1 DESCRIPTION

This script tries to connect to all switches configured in the
switches.conf file and to execute some simple SNMP reads.

=head1 AUTHOR

=over

=item Dominik Gehl <dgehl@inverse.ca>

=back

=head1 COPYRIGHT

Copyright (c) 2006-2008 Inverse groupe conseil

This program is available under the GPL.

=cut

use strict;
use warnings;
use diagnostics;
use threads;

use FindBin;

use constant {
    INSTALL_DIR => '/usr/local/pf',
    LIB_DIR     => $FindBin::Bin . "/../lib",
    CONF_FILE   => $FindBin::Bin . "/../conf/switches.conf",
};

use lib LIB_DIR;

use Getopt::Long;
use Pod::Usage;
use Net::MAC::Vendor;
use Log::Log4perl qw(:easy);
use Data::Dumper;

use pf::SwitchFactory;

my $help;
my $man;
my $logLevel = 2;

GetOptions(
    "help|?"    => \$help,
    "man"       => \$man,
    "verbose:i" => \$logLevel
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $man;
pod2usage( -verbose => 1 ) if $help;

if ( $logLevel == 0 ) {
    $logLevel = $FATAL;
} elsif ( $logLevel == 1 ) {
    $logLevel = $WARN;
} elsif ( $logLevel == 2 ) {
    $logLevel = $INFO;
} elsif ( $logLevel == 3 ) {
    $logLevel = $DEBUG;
} else {
    $logLevel = $TRACE;
}
Log::Log4perl->easy_init(
    {   level  => $logLevel,
        layout => '%d (%r) %M%n    %m %n'
    }
);
my $logger = Log::Log4perl->get_logger('');

my $switchFactory = new pf::SwitchFactory( -configFile => CONF_FILE );

my %Config = %{ $switchFactory->{_config} };

foreach my $switch_ip ( sort keys %Config ) {
    if ( ( $switch_ip ne '127.0.0.1' ) && ( $switch_ip ne 'default' ) ) {
        my $switch = $switchFactory->instantiate($switch_ip);
        print "$switch_ip\n";
        print " - sysUptime: " . $switch->getSysUptime() . "\n";
        my $vlanHashRef = $switch->getVlans();
        print " - nb Vlans : " . scalar( keys %$vlanHashRef ) . "\n";
        my @upLinks = $switch->getUpLinks();
        print " - Uplinks: " . join( ", ", @upLinks ) . "\n";
        my %macVlan = $switch->getMacAddrVlan();

        foreach my $mac ( keys %macVlan ) {
            print
                " - $mac\tvlan: $macVlan{$mac}{'vlan'}\tport: $macVlan{$mac}{'ifIndex'}\n";
        }
    }
}

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

