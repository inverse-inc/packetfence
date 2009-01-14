#!/usr/bin/perl -w

# Copyright 2007-2009 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

use strict;
use warnings;
use diagnostics;

use Net::SNMP;
use Log::Log4perl;
use Config::IniFiles;
use File::Basename qw(basename);

use constant INSTALL_DIR => '/usr/local/pf';

use lib INSTALL_DIR . "/lib";
use pf::util;
use pf::locationlog;
use pf::config;
use pf::SwitchFactory;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger(basename($0));
Log::Log4perl::MDC->put('proc', basename($0));
Log::Log4perl::MDC->put('tid', 0);

my $mac = $ARGV[0];

if ($mac =~ /^([0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2})$/) {
    $mac = $1;
} else {
    $logger->logdie("Bad MAC $mac");
}

$mac = lc($mac);
$logger->info("flip.pl called with $mac");

my $locationlog_entry = locationlog_view_open_mac($mac);
if ($locationlog_entry) {
    my $switch_ip = $locationlog_entry->{'switch'};
    my $ifIndex = $locationlog_entry->{'port'};
    $logger->info("switch port for $mac is $switch_ip ifIndex $ifIndex");

    my $switchFactory = new pf::SwitchFactory(
        -configFile => "$conf_dir/switches.conf"
    );
    my $trapSender = $switchFactory->instantiate('127.0.0.1');

    if ($ifIndex eq 'WIFI') {
        $trapSender->sendLocalDesAssociateTrap($switch_ip, $mac);
    } else {
        $trapSender->sendLocalReAssignVlanTrap($switch_ip, $ifIndex);
    }
} else {
    $logger->warn("cannot determine switch port for $mac. Flipping the ports admin status is impossible");
}


exit 1;
# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

