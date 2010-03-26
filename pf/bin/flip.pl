#!/usr/bin/perl -w

=head1 NAME

flip.pl - send local SNMP traps in order to flip a VLAN assignment

=head1 SYNOPSIS

flip.pl <MAC>

=cut

use strict;
use warnings;
use diagnostics;

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
    my $ifIndex   = $locationlog_entry->{'port'};
    my $conn_type = str_to_connection_type($locationlog_entry->{'connection_type'});
    $logger->info("switch port for $mac is $switch_ip ifIndex $ifIndex "
        . "connection type: " . $connection_type_explained{$conn_type});

    # TODO we could try to avoid the need of flip create a switch factory each time..
    # why even bother with a 127.0.0.1 entry in conf/switches.conf and not create a pf::SNMP::PacketFence switch directly
    my $switchFactory = new pf::SwitchFactory( -configFile => "$conf_dir/switches.conf" );
    my $trapSender    = $switchFactory->instantiate('127.0.0.1');

    if ($trapSender) {
        if ($conn_type == WIRED_SNMP_TRAPS) {
            $logger->debug("sending a local reAssignVlan trap to force VLAN change");
            $trapSender->sendLocalReAssignVlanTrap($switch_ip, $ifIndex, $conn_type);

        } elsif ($conn_type == WIRELESS_MAC_AUTH) {
            $logger->debug("sending a local desAssociate trap to force deassociation "
                ."(client will reconnect getting a new VLAN)");
            $trapSender->sendLocalDesAssociateTrap($switch_ip, $mac, $conn_type);

        } elsif ($conn_type == WIRELESS_802_1X) {
            # TODO connection_type should be sent in the trap
            $logger->debug("sending a local desAssociate trap to force deassociation "
                ."(client will reconnect getting a new VLAN)");
            $logger->info("trying to dissociate a wireless 802.1x user, "
                ."this might not work depending on hardware support. If its your case please file a bug");
            $trapSender->sendLocalDesAssociateTrap($switch_ip, $mac, $conn_type)

        } elsif ($conn_type == WIRED_802_1X) {
            $logger->debug("sending a local reAssignVlan trap to force VLAN change");
            $logger->info("trying to re-assign the VLAN of a wired 802.1x user (mac $mac switchport: $switch_ip:$ifIndex"
                . "), right now we shut / no shut the port but we could do something friendlier."); 
            $trapSender->sendLocalReAssignVlanTrap($switch_ip, $ifIndex, $conn_type);

        } elsif ($conn_type == WIRED_MAC_AUTH_BYPASS) {
            $logger->debug("sending a local reAssignVlan trap to force VLAN change");
            $trapSender->sendLocalReAssignVlanTrap($switch_ip, $ifIndex, $conn_type);

        } else {
            $logger->warn("unknown connection type! Will assume wired and send a reAssignVlan trap");
            $trapSender->sendLocalReAssignVlanTrap($switch_ip, $ifIndex);
        }
    } else {
        $logger->error("Can not instantiate switch 127.0.0.1 !");
    }

} else {
    $logger->warn("Can't find status information for $mac. Are you sure this node is connected to the network?");
}

exit 1;

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2010 Inverse inc.

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

