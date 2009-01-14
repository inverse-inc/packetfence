#!/usr/bin/perl -w

# Copyright 2007-2008 Inverse groupe conseil
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

my %switchConfig;
tie %switchConfig, 'Config::IniFiles', (-file => "$conf_dir/switches.conf");
my @errors = @Config::IniFiles::errors;
if (scalar(@errors)) {
    $logger->error("Error reading config file: " . join("\n", @errors));
    return 0;
}

#remove trailing spaces..
my $SNMPCommunityTrap = ($switchConfig{'default'}{'SNMPCommunityTrap'} || $switchConfig{'default'}{'communityTrap'});
$SNMPCommunityTrap =~ s/\s+$//;


my $locationlog_entry = locationlog_view_open_mac($mac);
if ($locationlog_entry) {
    my $switch_ip = $locationlog_entry->{'switch'};
    my $ifIndex = $locationlog_entry->{'port'};
    $logger->info("switch port for $mac is $switch_ip ifIndex $ifIndex");
    if ($ifIndex eq 'WIFI') {
        my ($session,$err) = Net::SNMP->session(
            -hostname => '127.0.0.1',
            -port => '162',
            -version => '1',
            -community => $SNMPCommunityTrap);
        if (! defined($session)) {
            $logger->error("error creation SNMP connection: " . $err);
        } else {

            my $result = $session->trap(
                -genericTrap => Net::SNMP::ENTERPRISE_SPECIFIC,
                -agentaddr => $switch_ip,
                -varbindlist => [
                    '1.3.6.1.6.3.1.1.4.1.0', Net::SNMP::OBJECT_IDENTIFIER, '1.3.6.1.4.1.29464.1.2',
                    "1.3.6.1.4.1.29464.1.3", Net::SNMP::OCTET_STRING, $mac,
                ]
            );
            if (! $result) {
                $logger->error("error sending SNMP trap: " . $session->error());
            }
        }

    } else {
        my ($session,$err) = Net::SNMP->session(
            -hostname => '127.0.0.1',
            -port => '162',
            -version => '1',
            -community => $SNMPCommunityTrap);
        if (! defined($session)) {
            $logger->error("error creation SNMP connection: " . $err);
        } else {

            my $result = $session->trap(
                -genericTrap => Net::SNMP::ENTERPRISE_SPECIFIC,
                -agentaddr => $switch_ip,
                -varbindlist => [
                    '1.3.6.1.6.3.1.1.4.1.0', Net::SNMP::OBJECT_IDENTIFIER, '1.3.6.1.4.1.29464.1.1',
                    "1.3.6.1.2.1.2.2.1.1.$ifIndex", Net::SNMP::INTEGER, $ifIndex,
                ]
            );
            if (! $result) {
                $logger->error("error sending SNMP trap: " . $session->error());
            }
        }
    }
} else {
    $logger->warn("cannot determine switch port for $mac. Flipping the ports admin status is impossible");
}


exit 1;
# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

