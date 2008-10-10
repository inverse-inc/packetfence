#!/usr/bin/perl -w

# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
# 

=head1 NAME

testSecureMACs.pl - try to connect to all switches and check 
     if every secure MAC appears more than once

=head1 SYNOPSIS

testSecureMACs.pl [options]

 Command:
   -help           brief help message
   -man            full documentation

 Options:
   -verbose        log verbosity level
                     0 : fatal messages
                     1 : warn messages
                     2 : info messages
                   > 2 : full debug
                 

=head1 DESCRIPTION

This script tries to connect to all switches configured in the
switches.conf file and to check if there are secure MACs which
appear on more than one switchport.

=head1 AUTHOR

=over

=item Dominik Gehl <dgehl@inverse.ca>

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
    LIB_DIR => $FindBin::Bin . "/../lib",
    CONF_FILE => $FindBin::Bin . "/../conf/switches.conf",
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
    "help|?" => \$help,
    "man" => \$man,
    "verbose:i" => \$logLevel
) or pod2usage( -verbose => 1);

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

my %Config = %{$switchFactory->{_config}};

my $switch_ip = undef;

my $completeSecureMacAddrHashRef;
foreach my $key (sort keys %Config) {
  if ($key ne 'default') {
    $switch_ip = $Config{$key}{'ip'};
    my $switch = $switchFactory->instantiate($switch_ip);
    $logger->info("starting to obtain secure MACs from $switch_ip");
    my $secureMacAddrHashRef = $switch->getAllSecureMacAddresses();
    $logger->debug("secure MACs on $switch_ip: " . join(", ", sort keys %$secureMacAddrHashRef));
    foreach my $mac (keys %$secureMacAddrHashRef) {
      if (! $switch->isFakeMac($mac)) {
        $completeSecureMacAddrHashRef->{$mac}->{$switch_ip} = $secureMacAddrHashRef->{$mac};
      }
    }
  }
}

$logger->info("total number of secure MACs: " . scalar(keys %$completeSecureMacAddrHashRef));
foreach my $mac (keys %$completeSecureMacAddrHashRef) {
  $logger->debug ("MAC $mac: " . join(", ", keys %{$completeSecureMacAddrHashRef->{$mac}}));
  if (scalar(keys %{$completeSecureMacAddrHashRef->{$mac}}) > 1) {
    print "$mac\n";
    foreach my $switch (keys %{$completeSecureMacAddrHashRef->{$mac}}) {
      print "- $switch ifIndex" . join(", ", keys %{$completeSecureMacAddrHashRef->{$mac}->{$switch}}) . "\n";
    }
  }
}

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

