#!/usr/bin/perl -w

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

=cut
# TODO make it work with most switches then call it pfdiag and place in bin/
use strict;
use warnings;
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
use Log::Log4perl qw(:easy);

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
        if (!$switch) {
            print "Can not instantiate switch $switch_ip ! See log for details\n";
        } else {
            print "$switch_ip\n";
            next if (ref($switch) =~ /Aironet/);
            print " - sysUptime: " . $switch->getSysUptime() . "\n";
            my $vlanHashRef = $switch->getVlans();
            print " - nb Vlans : " . scalar( keys %$vlanHashRef ) . "\n";
            my @upLinks = $switch->getUpLinks();
            print " - Uplinks: " . join( ", ", @upLinks ) . "\n";
            my %macVlan = $switch->getMacAddrVlan();

            foreach my $mac ( keys %macVlan ) {
                print " - $mac\tvlan: $macVlan{$mac}{'vlan'}\tport: $macVlan{$mac}{'ifIndex'}\n";
            }
        }
    }
}

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

