#!/usr/bin/perl -w
#
# (c) 2007,2008 Inverse inc., licensed under the GPLv2
#
# Author: Dominik Gehl <dgehl@inverse.ca>
#

=head1 NAME

recovery.pl - recovery and validation of VLAN assignment

=head1 SYNOPSIS

recovery.pl [command] [options]

 Command:
    -help          brief help message
    -man           full documentation
    
 Options:
    -switch        switch description
    -switchRegExp  regular expression for switch description
    -verbose       log verbosity level
                     0 : fatal messages
                     1 : warn messages
                     2 : info messages
                   > 2 : full debug
    -reassign      if set, re-assign switch port VLANs
    -synchronize   if set, synchronize locationlog entries
    -singleThread  if set, run in single thread (for debugging)

=head1 DESCRIPTION

This script validates the current VLAN assignment of all switch ports
in production to the calculated VLAN assignment.

=head1 AUTHOR

=over

=item Dominik Gehl <dgehl@inverse.ca>

=back

=head1 COPYRIGHT

Copyright (c) 2007,2008 Inverse groupe conseil

This program is available under the GPL.

=cut

use strict;
use warnings;
use diagnostics;

use FindBin;
use DBI;
use threads;
use threads::shared;
use Log::Log4perl qw(:easy);
use Getopt::Long;
use Pod::Usage;
use Thread::Pool;

require 5.8.8;

use constant {
    NB_THREADS => 15,
    LIB_DIR    => $FindBin::Bin . "/../lib",
    CONF_FILE  => $FindBin::Bin . "/../conf/switches.conf",
};

use lib LIB_DIR;
use pf::SwitchFactory;
use pf::config;
$thread = 1;
use pf::db;
use pf::node;
use pf::violation;
use pf::locationlog;
use pf::vlan::custom;

my $logLevel = 0;
my $help;
my $man;
my $reassign;
my $synchronize;
my $singleThread;
my $switchDescription       = '';
my $switchDescriptionRegExp = '';

GetOptions(
    "verbose:i"      => \$logLevel,
    "help|?"         => \$help,
    "man"            => \$man,
    "reassign"       => \$reassign,
    "synchronize"    => \$synchronize,
    "singleThread"   => \$singleThread,
    "switch:s"       => \$switchDescription,
    "switchRegExp:s" => \$switchDescriptionRegExp
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
        layout => '%d (%r) %M%n    %m %n'
    }
);
my $logger = Log::Log4perl->get_logger('');

my $switchFactory = new pf::SwitchFactory( -configFile => CONF_FILE );

my @switchDescriptions;
foreach my $key ( sort keys %{ $switchFactory->{_config} } ) {
    if (( $key ne 'default' )
        && ( $switchFactory->{_config}->{$key}->{type} ne
            'Cisco::Aironet_1242' )
        )
    {
        if ((      ( $switchDescription eq '' )
                && ( $switchDescriptionRegExp eq '' )
            )
            || (   ( $switchDescription ne '' )
                && ( $switchDescription eq $key ) )
            || (   ( $switchDescriptionRegExp ne '' )
                && ( $key =~ /$switchDescriptionRegExp/ ) )
            )
        {
            push @switchDescriptions, $key;
        }
    }
}
if ( ( $switchDescription ne '' ) && ( scalar(@switchDescriptions) == 0 ) ) {
    pod2usage("no switch has description $switchDescription");
}
if (   ( $switchDescriptionRegExp ne '' )
    && ( scalar(@switchDescriptions) == 0 ) )
{
    pod2usage("no switch description matches $switchDescriptionRegExp");
}
my %switch_locker : shared;
my $completeMacAddrHashRef = &share( {} );

foreach my $switchDesc ( sort @switchDescriptions ) {
    my $switch_ip = $switchFactory->{_config}{$switchDesc}{'ip'};
    $switch_locker{$switch_ip} = &share( {} );
}

if ($singleThread) {
    foreach my $switchDesc ( sort @switchDescriptions ) {
        print recoverSwitch($switchDesc);
    }
} else {
    my $threadPool = Thread::Pool->new(
        {   do => sub {
                my $switchDesc = shift();
                $logger->debug("starting recoverSwitch($switchDesc)");
                my $txt = '';
                eval { $txt = recoverSwitch($switchDesc); };
                print "$txt\n";
            },
            workers => NB_THREADS
        }
    );
    foreach my $switchDesc ( sort @switchDescriptions ) {
        $threadPool->job($switchDesc);
    }
    $threadPool->shutdown();
}

{
    lock $completeMacAddrHashRef;
    my $format = "%-20.20s %-17.17s %-10.10s\n";
    foreach my $mac ( sort keys %$completeMacAddrHashRef ) {
        my $first = 1;
        foreach my $switch ( keys %{ $completeMacAddrHashRef->{$mac} } ) {
            if ($first) {
                printf( $format,
                    $mac, $switch,
                    $completeMacAddrHashRef->{$mac}->{$switch} );
            } else {
                printf( $format,
                    '', $switch, $completeMacAddrHashRef->{$mac}->{$switch} );
            }
        }
    }
}

sub recoverSwitch {
    my $switchDesc = shift();
    my $txt        = '';
    my $format     = "%-2.2s %7.7s %-7.7s %-7.7s %-7.7s %-20.20s %-20.20s\n";
    my $mysql_connection = db_connect();
    if ( !$mysql_connection ) {
        return "unable to connect to database\n";
    }
    node_db_prepare($mysql_connection);
    locationlog_db_prepare($mysql_connection);
    violation_db_prepare($mysql_connection);
    my $switch = $switchFactory->instantiate($switchDesc);
    if ( $switch->isProductionMode() ) {
        $txt .= "------------------------------\n";
        $txt .= "$switchDesc\n";
        $txt .= "------------------------------\n";
        $txt .= sprintf( $format,
            '', 'ifIndex', 'oper', 'cur', 'cor', 'MAC(s)', 'locationlog' );
        my @managedIfIndexes = $switch->getManagedIfIndexes();
        my $allMacs          = $switch->getAllMacs(@managedIfIndexes);
        my $allSecMacs       = $switch->getAllSecureMacAddresses();
        my $vlanHashRef      = $switch->getAllVlans(@managedIfIndexes);

        foreach my $currentIfIndex ( sort { $a <=> $b } @managedIfIndexes ) {
            my $currentVlan = $vlanHashRef->{$currentIfIndex};
            my $correctVlan = 0;
            my $locationLog = '';
            my $status      = '';
            my $ifOperStatus
                = ( $switch->getIfOperStatus($currentIfIndex) == 1
                ? 'up'
                : 'down' );
            my @currentPcs;
            my $currentPcStatus;
            my $currentPcViolationCount = 0;
            my @currentPhones;

            if (   ( $ifOperStatus eq 'up' )
                || ( $switch->isPortSecurityEnabled($currentIfIndex) ) )
            {
                my @currentMacs;
                foreach my $vlan ( keys %{ $allMacs->{$currentIfIndex} } ) {
                    foreach
                        my $mac ( @{ $allMacs->{$currentIfIndex}->{$vlan} } )
                    {
                        if (   ( !$switch->isFakeMac($mac) )
                            && ( !$switch->isFakeVoIPMac($mac) )
                            && ( grep( {/^$mac$/} @currentMacs ) == 0 ) )
                        {
                            push @currentMacs, $mac;
                        }
                    }
                }
                foreach my $mac ( keys %{$allSecMacs} ) {
                    if ( exists( $allSecMacs->{$mac}->{$currentIfIndex} ) ) {
                        $mac = uc($mac);
                        if (   ( !$switch->isFakeMac($mac) )
                            && ( !$switch->isFakeVoIPMac($mac) )
                            && ( grep( {/^$mac$/} @currentMacs ) == 0 ) )
                        {
                            push @currentMacs, $mac;
                        }
                    }
                }
                @currentPhones
                    = $switch->getPhonesDPAtIfIndex($currentIfIndex);
                foreach my $mac (@currentMacs) {
                    my $node_info = node_view_with_fingerprint($mac);
                    my $isPhone   = (
                        ( grep( {/^$mac$/i} @currentPhones ) != 0 )
                            || ( defined($node_info)
                            && $node_info->{dhcp_fingerprint}
                            =~ /VoIP Phone/ )
                    );
                    if ( !$isPhone ) {
                        push @currentPcs, $mac;
                    }
                }
                $logger->trace(
                    "locking - trying to lock completeMacAddrHashRef");
                {
                    lock $completeMacAddrHashRef;
                    foreach my $mac (@currentPcs) {
                        $completeMacAddrHashRef->{$mac} = &share( {} );
                        $completeMacAddrHashRef->{$mac}->{ $switch->{_ip} }
                            = $currentIfIndex;
                    }
                }
                $logger->trace("locking - unlocked completeMacAddrHashRef");
                my $vlan_obj = new pf::vlan::custom();
                if ( scalar(@currentPcs) > 1 ) {
                    $correctVlan = $switch->{_isolationVlan};
                } elsif ( scalar(@currentPcs) == 1 ) {
                    $correctVlan
                        = $vlan_obj->vlan_determine_for_node( $currentPcs[0],
                        $switch->{_ip}, $currentIfIndex );
                    my $locationlog_entry
                        = locationlog_view_open_mac( $currentPcs[0] );
                    if ( !$locationlog_entry ) {
                        $locationLog = 'no open entry';
                        $status      = '*';
                        if ($synchronize) {
                            locationlog_synchronize(
                                $switch->{_ip}, $currentIfIndex,
                                $currentVlan,   $currentPcs[0],
                            );
                        }
                    } else {
                        if (( $currentVlan == $locationlog_entry->{'vlan'} )
                            && ( $switch->{_ip} eq
                                $locationlog_entry->{'switch'} )
                            && ( $currentIfIndex
                                == $locationlog_entry->{'port'} )
                            )
                        {
                            $locationLog = 'ok';
                        } else {
                            $locationLog
                                = $locationlog_entry->{'switch'}
                                . ' ifIndex '
                                . $locationlog_entry->{'port'};
                            $status = '*';
                            if ($synchronize) {
                                locationlog_synchronize(
                                    $switch->{_ip}, $currentIfIndex,
                                    $currentVlan,   $currentPcs[0],
                                );
                            }
                        }
                    }
                } else {
                    $correctVlan = $switch->{_macDetectionVlan};
                }
            } else {
                $correctVlan = $switch->{_macDetectionVlan};
            }
            if ( $correctVlan != $currentVlan ) {
                $status = "->";
                if ($reassign) {
                    $switch->setVlan( $currentIfIndex, $correctVlan,
                        \%switch_locker );
                }
            }
            $txt .= sprintf( $format,
                $status, $currentIfIndex, $ifOperStatus, $currentVlan,
                $correctVlan, join( ",", @currentPcs ), $locationLog );
        }
        $txt .= "\n";
    }
    return $txt;
}

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

