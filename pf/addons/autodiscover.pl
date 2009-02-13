#!/usr/bin/perl -w

#
# (c) 2007-2008 Inverse inc., licensed under the GPLv2
#

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

=over

=item Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (c) 2007-2008 Inverse groupe conseil

This program is available under the GPL.

=cut

use strict;
use warnings;
use diagnostics;

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
        && ( $switchFactory->{'_config'}->{$switchDesc}->{'mode'}
            =~ /^discovery/ )
        )
    {
        my $switch = $switchFactory->instantiate($switchDesc);
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
                            $nbPhones++;
                        } else {
                            $nbPCs++;
                            print " (real PC MAC)";
                        }
                        if ( node_exist($mac) ) {
                            my $node_info = node_view($mac);
                            if ( ( $node_info->{'switch'} ne $switch->{_ip} )
                                || ( $node_info->{'port'} ne $ifIndex ) )
                            {
                                print
                                    "\n       node switch and port not up2date (old info is "
                                    . $node_info->{'switch'}
                                    . " ifIndex "
                                    . $node_info->{'port'} . ")\n";
                                node_modify(
                                    $mac,
                                    (   switch => $switch->{_ip},
                                        port   => $ifIndex
                                    )
                                );
                            }
                        } else {
                            print
                                "\n       node $mac doesn't exist in node table\n";
                            node_add_simple($mac);
                            node_modify(
                                $mac,
                                (   switch => $switch->{_ip},
                                    port   => $ifIndex
                                )
                            );
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
