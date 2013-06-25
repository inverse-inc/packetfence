package pf::enforcement;

=head1 NAME

pf::enforcement - taking security decisions

=cut

=head1 DESCRIPTION

pf::enforcement provides the means to re-evaluate the security posture of a node
and trigger the appropriate required changes.

=head1 DEVELOPER NOTES

Notice that this module doesn't export all its subs like our other modules do.
This is an attempt to shift our paradigm towards calling with package names
and avoid the double naming.

Remove this note when it will be no longer relevant. ;)

=cut

use strict;
use warnings;

use List::MoreUtils qw(none);
use Log::Log4perl;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw();
    @EXPORT_OK = qw(reevaluate_access);
}

use pf::config;
use pf::inline::custom $INLINE_API_LEVEL;
use pf::iptables;
use pf::locationlog;
use pf::node;
use pf::SwitchFactory;
use pf::util;
use pf::vlan::custom $VLAN_API_LEVEL;

=head1 SUBROUTINES

=over

=item reevaluate_access

This will check a node's status and perform changes to access control if necessary.

Triggered by pfcmd.

=cut

sub reevaluate_access {
    my ( $mac, $function, %opts ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::enforcement');

    # Untaint MAC
    $mac = clean_mac($mac);

    # function must be in advanced.reevaluate_access_reasons list otherwise bail out
    if ( none { $_ eq $function } split(/\s*,\s*/, $Config{'advanced'}{'reevaluate_access_reasons'}) ) {
        $logger->info("access re-evaluation requested but denied by configuration");
        return $FALSE;
    }

    $logger->info("re-evaluating access for node $mac ($function called)");
    my $locationlog_entry = locationlog_view_open_mac($mac);
    if (!$locationlog_entry) {
        $logger->warn("Can't re-evaluate access for mac $mac because no open locationlog entry was found");
        return;

    } else {

        my $conn_type = str_to_connection_type($locationlog_entry->{'connection_type'});
        if ($conn_type == $INLINE) {

            my $inline = new pf::inline::custom();
            if ($inline->isInlineEnforcementRequired($mac)) {

                # TODO avoidable load?
                my $trapSender = pf::SwitchFactory->getInstance()->instantiate('127.0.0.1');
                if ($trapSender) {
                    $logger->debug("sending a local firewallRequest trap to force firewall change");
                    $trapSender->sendLocalFirewallRequestTrap($trapSender, $mac);
                } else {
                    $logger->error("Can't instantiate switch 127.0.0.1! It's critical for internal messages!");
                }

            } else {
                $logger->debug("MAC: $mac is already properly enforced in firewall, no change required");
            }

        } else {
            return _vlan_reevaluation($mac, $locationlog_entry, %opts);
        }

    }
}

=item _vlan_reevaluation

Sends local SNMP traps to pfsetvlan if we should reevaluate the VLAN of a node.

=cut

sub _vlan_reevaluation {
    my ($mac, $locationlog_entry, %opts) = @_;
    my $logger = Log::Log4perl::get_logger('pf::enforcement');

    if ( _should_we_reassign_vlan($mac, $locationlog_entry, %opts) ) {

        my $switch_id = $locationlog_entry->{'switch'} || 'unknown';
        my $ifIndex = $locationlog_entry->{'port'} || 'unknown';
        my $conn_type = str_to_connection_type($locationlog_entry->{'connection_type'});
        $logger->info(
            "switch port for $mac is $switch_id ifIndex $ifIndex "
            . "connection type: " . $connection_type_explained{$conn_type}
        );

        # TODO avoidable load?
        my $trapSender = pf::SwitchFactory->getInstance()->instantiate('127.0.0.1');
        my $switch = pf::SwitchFactory->getInstance()->instantiate($switch_id);
        if ($trapSender) {
            if ($conn_type == $UNKNOWN) {
                $logger->warn("Unknown connection type! We won't perform VLAN reassignment since node never connected");

            } elsif ($conn_type == $WIRED_SNMP_TRAPS) {
                $logger->debug("sending a local reAssignVlan trap to force VLAN change");
                $trapSender->sendLocalReAssignVlanTrap($switch, $ifIndex, $conn_type);

            } elsif ($conn_type == $WIRELESS_MAC_AUTH) {
                $logger->debug("sending a local desAssociate trap to force deassociation "
                    . "(client will reconnect getting a new VLAN)");
                $trapSender->sendLocalDesAssociateTrap($switch, $mac, $conn_type);

            } elsif ($conn_type == $WIRELESS_802_1X) {
                $logger->debug(
                    "sending a local desAssociate trap to force deassociation. Client will reconnect getting a new VLAN"
                );
                $logger->info(
                    "trying to dissociate a wireless 802.1x user, this might not work depending on hardware support. "
                    . "If its your case please file a bug"
                );
                $trapSender->sendLocalDesAssociateTrap($switch, $mac, $conn_type)

            } elsif ($conn_type == $WIRED_802_1X) {
                $logger->debug("sending a local reAssignVlan trap to force VLAN change");
                $trapSender->sendLocalReAssignVlanTrap($switch, $ifIndex, $conn_type);

            } elsif ($conn_type == $WIRED_MAC_AUTH) {
                $logger->debug("sending a local reAssignVlan trap to force VLAN change");
                $trapSender->sendLocalReAssignVlanTrap($switch, $ifIndex, $conn_type);
            }
        } else {
            $logger->error("Can't instantiate switch 127.0.0.1! Check your configuration!");
        }

    }
    return 1;
}

=item _should_we_reassign_vlan

Returns true or false whether or not we should request vlan adjustment

Evaluates node's VLAN through L<pf::vlan>'s fetchVlanForNode (which can be redefined by L<pf::vlan::custom>)

=cut

sub _should_we_reassign_vlan {
    my ($mac, $locationlog_entry, %opts) = @_;
    my $logger = Log::Log4perl::get_logger('pf::enforcement');

    if ($opts{'force'}) {
        $logger->info("$mac VLAN reassignment is forced.");
        return $TRUE;
    }

    my $switch_ip = $locationlog_entry->{'switch'};
    my $switch_mac = $locationlog_entry->{'switch_mac'};
    my $ifIndex = $locationlog_entry->{'port'};
    my $currentVlan = $locationlog_entry->{'vlan'};
    my $connection_type = str_to_connection_type($locationlog_entry->{'connection_type'});
    my $user_name = $locationlog_entry->{'dot1x_username'};
    my $ssid = $locationlog_entry->{'ssid'};

    $logger->info( "$mac is currentlog connected at $switch_ip ifIndex $ifIndex in VLAN $currentVlan" );

    my $vlan_obj = new pf::vlan::custom();
    # TODO avoidable load?
    my $switch = pf::SwitchFactory->getInstance()->instantiate($switch_mac,$switch_ip);
    if (!$switch) {
        $logger->error("Can't instantiate switch $switch_ip! Check your configuration!");
        return $FALSE;
    }

    my ($newCorrectVlan,$wasInline) = $vlan_obj->fetchVlanForNode($mac, $switch, $ifIndex, $connection_type, $user_name, $ssid);
    if ( $newCorrectVlan eq '-1' ) {
        $logger->info(
            "VLAN reassignment required for $mac (current VLAN = $currentVlan but should be in VLAN $newCorrectVlan)"
        );
        return $TRUE;
    } elsif ( $newCorrectVlan ne $currentVlan ) {
        $logger->info(
            "VLAN reassignment required for $mac (current VLAN = $currentVlan but should be in VLAN $newCorrectVlan)"
        );
        return $TRUE;
    }
    $logger->debug("No VLAN reassignment required for $mac.");
    return $FALSE;
}

=back

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

1;
