#!/usr/bin/perl -w

=head1 NAME

flip.pl - send local SNMP traps in order to flip a VLAN assignment

=head1 SYNOPSIS

flip.pl <MAC>

=cut

use strict;
use warnings;
use diagnostics;

use Net::SNMP;
use Log::Log4perl;
use File::Basename qw(basename);

use constant INSTALL_DIR => '/usr/local/pf';

use lib INSTALL_DIR . "/lib";
use pf::util;
use pf::locationlog;
use pf::config;
use pf::SwitchFactory;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

my $mac = $ARGV[0];

if ( $mac
    =~ /^([0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2})$/
    )
{
    $mac = $1;
} else {
    $logger->logdie("Bad MAC $mac");
}

$mac = lc($mac);
$logger->info("flip.pl called with $mac");

my $locationlog_entry = locationlog_view_open_mac($mac);
if ($locationlog_entry) {
    my $switch_ip = $locationlog_entry->{'switch'};
    my $ifIndex   = $locationlog_entry->{'port'};
    $logger->info("switch port for $mac is $switch_ip ifIndex $ifIndex");

    my $switchFactory
        = new pf::SwitchFactory( -configFile => "$conf_dir/switches.conf" );
    my $trapSender = $switchFactory->instantiate('127.0.0.1');

    if ( $ifIndex eq 'WIFI' ) {
        $trapSender->sendLocalDesAssociateTrap( $switch_ip, $mac );
    } else {
        $trapSender->sendLocalReAssignVlanTrap( $switch_ip, $ifIndex );
    }
} else {
    $logger->warn(
        "cannot determine switch port for $mac. Flipping the ports admin status is impossible"
    );
}

exit 1;

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2009 Inverse inc.

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

