#!/usr/bin/perl -w

=head1 NAME

autodiscover.pl - autodiscovery of nodes

=head1 SYNOPSIS

./autodiscover.pl

 Options:
 -help           brief help message
 -man            full documentation


=head1 DESCRIPTION

autodiscovert of nodes

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

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use Getopt::Long;
use Pod::Usage;
use FindBin;
use Net::SNMP;
use Data::Dumper;

use constant {
    LIB_DIR   => $FindBin::Bin . "/../lib",
    CONF_FILE => $FindBin::Bin . "/../conf/switches.conf",
};

use lib LIB_DIR;
use pf::SwitchFactory;

require 5.8.5;
use pf::config;
use pf::node;
use pf::locationlog;
use pf::util;

my $help;
my $man;
my $logLevel = 0;
GetOptions(
    "help|?"    => \$help,
    "man"       => \$man,
    "verbose:i" => \$logLevel,
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $man;
pod2usage( -verbose => 1 ) if $help;

if ( $logLevel == 0 ) {
    $logLevel = $FATAL;
} elsif ( $logLevel == 1 ) {
    $logLevel = $WARN;
} elsif ( $logLevel == 2 ) {
    $logLevel = $INFO;
} else {
    $logLevel = $DEBUG;
}
Log::Log4perl->easy_init(
    {   level  => $logLevel,
        layout => '%d (%r) %M  %m %n'
    }
);
my $logger = Log::Log4perl->get_logger('');

my $switchFactory = new pf::SwitchFactory( -configFile => CONF_FILE );

foreach my $switchDesc ( sort keys %{ $switchFactory->{'_config'} } ) {
    if (( $switchDesc ne 'default' )
        && ( $switchDesc ne '127.0.0.1' )
        && ( $switchFactory->{'_config'}->{$switchDesc}->{'mode'}
            =~ /^discovery/ )
        )
    {
        my $switch = $switchFactory->instantiate($switchDesc);
        if (!$switch) {
            print "Can not instantiate switch $switchDesc\n";
            next;
        }

        print "$switchDesc\n";
        my $allMacs = $switch->getAllMacs();
        foreach my $ifIndex ( sort keys %$allMacs ) {
            print "ifIndex $ifIndex\n";
            my $nbPhones = 0;
            my $nbPCs    = 0;
            foreach my $vlan ( sort keys %{ $allMacs->{$ifIndex} } ) {
                print " -> vlan $vlan\n";
                foreach my $mac ( @{ $allMacs->{$ifIndex}->{$vlan} } ) {
                    print "    - MAC: $mac";
                    my $isPhone = $NO_VOIP;
                    my $isFake = 0;
                    if ( $switch->isFakeMac($mac) ) {
                        print " (fake PC MAC)";
                        $isFake = 1;
                    }
                    if ( $switch->isFakeVoIPMac($mac) ) {
                        print " (fake VoIP MAC)";
                        $isFake = 1;
                    }
                    if ( !$isFake ) {
                        if ( $switch->isPhoneAtIfIndex( $mac, $ifIndex ) ) {
                            print " (real VoIP MAC)";
                            $isPhone = $VOIP;
                            $nbPhones++;
                        } else {
                            $nbPCs++;
                            print " (real PC MAC)";
                        }
                        if ( node_exist($mac) ) {
                            my $node_info = node_view($mac);
                            if ( ( $node_info->{'last_switch'} ne $switch->{_ip} )
                                || ( $node_info->{'last_port'} ne $ifIndex )
                                || ($node_info->{'voip'} ne $isPhone)) 
                            {
                                print
                                    "\n       node switch and port not up2date (old info is "
                                    . "switch " . $node_info->{'last_switch'} . " "
                                    . "ifIndex " . $node_info->{'last_port'} . " "
                                    . "VoIP: " . $node_info->{'voip'} 
                                    . ")\n";
                                locationlog_synchronize($switch->{_ip}, $ifIndex, $vlan, $mac, $isPhone, '');
                                print "switch: " . $switch->{_ip} . "\n";
                                print "port: $ifIndex\n";
                            }
                        } else {
                            print
                                "\n       node $mac doesn't exist in node table\n";
                            node_add_simple($mac);
                            locationlog_synchronize($switch->{_ip}, $ifIndex, $vlan, $mac, $isPhone, '');
                            print "switch: " . $switch->{_ip} . "\n";
                            print "port: $ifIndex\n";
                        }
                    }
                    print "\n";
                }
            }
            if ( $nbPhones > 1 ) {
                print "found more than 1 phone on this switchport\n";
            }
            if ( $nbPCs > 1 ) {
                print "found more than 1 PC on this switchport\n";
            }
        }
        print "\n";
    }
}

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
