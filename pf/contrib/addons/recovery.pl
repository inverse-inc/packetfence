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
use Log::Log4perl qw(:easy);
use Getopt::Long;
use Pod::Usage;
use Thread::Pool;
use Data::Dumper;

require 5.8.8;

use constant {
    NB_THREADS => 15,
    LIB_DIR => $FindBin::Bin . "/../../lib",
    CONF_FILE => $FindBin::Bin . "/../../conf/switches.conf",
};


use lib LIB_DIR;
use pf::SwitchFactory;
require $FindBin::Bin . "/../../conf/pfsetvlan.pm";
use pf::config;
$thread = 1;
use pf::db;
use pf::node;
use pf::violation;
use pf::locationlog;
use pf::vlan;

my $logLevel = 0;
my $help;
my $man;
my $reassign;
my $switchDescription = '';
my $switchDescriptionRegExp = '';

GetOptions("verbose:i" => \$logLevel,
    "help|?" => \$help,
    "man" => \$man,
    "reassign" => \$reassign,
    "switch:s" => \$switchDescription,
    "switchRegExp:s" => \$switchDescriptionRegExp
) or pod2usage ( -verbose => 1);

pod2usage( -verbose => 2) if $man;
pod2usage( -verbose => 1) if $help;

if ($logLevel == 0) {
    $logLevel = $FATAL;
} elsif ($logLevel == 1) {
    $logLevel = $WARN;
} elsif ($logLevel == 2) {
    $logLevel = $INFO;
} else {
    $logLevel = $DEBUG;
}

Log::Log4perl->easy_init(
    {
        level => $logLevel,
        layout => '%d (%r) %M%n    %m %n'
    }
);
my $logger = Log::Log4perl->get_logger('');

my $switchFactory = new pf::SwitchFactory(
        -configFile => CONF_FILE
    );

my @switchDescriptions; 
foreach my $key (sort keys %{$switchFactory->{_config}}) {
    if (($key ne 'default') && ($switchFactory->{_config}->{$key}->{type} ne 'Cisco::Aironet_1242')) {
        if ((($switchDescription eq '') && ($switchDescriptionRegExp eq '')) ||
            (($switchDescription ne '') && ($switchDescription eq $key)) ||
            (($switchDescriptionRegExp ne '') && ($key =~ /$switchDescriptionRegExp/))) {
            push @switchDescriptions, $key;
        }
    }
}
if (($switchDescription ne '') && (scalar(@switchDescriptions) == 0)) {
    pod2usage("no switch has description $switchDescription");
}
if (($switchDescriptionRegExp ne '') && (scalar(@switchDescriptions) == 0)) {
    pod2usage("no switch description matches $switchDescriptionRegExp");
}

my %switch_locker : shared;
foreach my $switchDesc (sort @switchDescriptions) {
    my $switch_ip = $switchFactory->{_config}{$switchDesc}{'ip'};
    $switch_locker{$switch_ip}  = &share({});
}

my $threadPool = Thread::Pool->new(
    {
        do => sub {
            my $switchDesc = shift();
            $logger->debug("starting recoverSwitch($switchDesc)");
            my $txt = '';
            eval {
                $txt = recoverSwitch($switchDesc);
            };
            print "$txt\n";
        },
        workers => NB_THREADS
    }
);
foreach my $switchDesc (sort @switchDescriptions) {
    $threadPool->job($switchDesc);
}
$threadPool->shutdown();

sub recoverSwitch {
    my $switchDesc = shift();
    my $txt = '';
    my $mysql_connection = db_connect();
    if (! $mysql_connection) {
        return "unable to connect to database\n";
    }
    node_db_prepare($mysql_connection);
    locationlog_db_prepare($mysql_connection);
    violation_db_prepare($mysql_connection);
    my $switch = $switchFactory->instantiate($switchDesc);
    if ($switch->isProductionMode()) {
        $txt .= "$switchDesc\n";
        my @managedIfIndexes = $switch->getManagedIfIndexes();
        my $allMacs = $switch->getAllMacs(@managedIfIndexes);
        my $vlanHashRef = $switch->getAllVlans(@managedIfIndexes);
        foreach my $currentIfIndex (sort @managedIfIndexes) {
            my $currentVlan = $vlanHashRef->{$currentIfIndex};
            my $correctVlan = 0;
            my $ifOperStatus = ($switch->getIfOperStatus($currentIfIndex) == 1 ? 'up' : 'down');
            my @currentPcs;
            my $currentPcStatus;
            my $currentPcViolationCount = 0;
            my @currentPhones;
            if ($ifOperStatus eq 'up') {
                my @currentMacs;
                foreach my $vlan (keys %{$allMacs->{$currentIfIndex}}) {
                    foreach my $mac (@{$allMacs->{$currentIfIndex}->{$vlan}}) {
                        if (grep(/^$mac$/,@currentMacs) == 0) {
                            push @currentMacs, $mac;
                        }
                    }
                }
                @currentPhones = $switch->getPhonesAtIfIndex($currentIfIndex);
                print Dumper(@currentPhones);
                foreach my $mac (@currentMacs) {
                    my $node_info = node_view_with_fingerprint($mac);
                    my $isPhone = ((grep(/^$mac$/i, @currentPhones) != 0) || (defined($node_info) && $node_info->{dhcp_fingerprint} =~ /VoIP Phone/));
                    if (! $isPhone) {
                        push @currentPcs, $mac;
                    }
                }
                if (scalar(@currentPcs) > 1) {
                    $correctVlan = $switch->{_isolationVlan};
                } elsif (scalar(@currentPcs) == 1) {
                    $correctVlan = vlan_determine_for_node($currentPcs[0], $switch->{_ip}, $currentIfIndex);
                } else {
                    $correctVlan = $switch->{_macDetectionVlan};
                }
            } else {
                $correctVlan = $switch->{_macDetectionVlan};
            }
            if ($correctVlan != $currentVlan) {
                $txt .= "->";
                if ($reassign) {
                    $switch->setVlan($currentIfIndex, $correctVlan, \%switch_locker);
                }
            } else {
                $txt .= "- ";
            }
            $txt .= "$currentIfIndex\t$ifOperStatus\t" . join(",", @currentPcs) . "\t$currentVlan\t$correctVlan\n";
        }
        $txt .= "\n";
    }
    return $txt;
}

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

