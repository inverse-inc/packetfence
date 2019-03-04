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
use pf::log;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA       = qw(Exporter);
    @EXPORT_OK = qw(reevaluate_access);
}

use pf::constants;
use pf::config qw(
    $INLINE_API_LEVEL
    $ROLE_API_LEVEL
    %Config
    $INLINE
    %connection_type_explained
    $WIRED
    $WIRELESS
    $WEBAUTH
);
use pf::inline::custom $INLINE_API_LEVEL;
use pf::iptables;
use pf::locationlog;
use pf::node;
use pf::SwitchFactory;
use pf::util;
use pf::config::util;
use pf::role::custom $ROLE_API_LEVEL;
use pf::client;
use pf::cluster;
use pf::constants::dhcp qw($DEFAULT_LEASE_LENGTH);
use pf::ip4log;
use pf::Connection::ProfileFactory;

use Readonly;

=head1 SUBROUTINES

=over

=item reevaluate_access

This will check a node's status and perform changes to access control if necessary.

Triggered by pfcmd.

=cut

sub reevaluate_access {
    my ( $mac, $function, %opts ) = @_;
    my $logger = get_logger();

    # Untaint MAC
    $mac = clean_mac($mac);

    $logger->info("re-evaluating access ($function called)");
    $opts{'force'} = '1' if ($function eq 'admin_modify');

    if(isenabled($Config{advanced}{sso_on_access_reevaluation})){
        my $node = node_attributes($mac);
        my $ip = pf::ip4log::mac2ip($mac);
        if($ip){
            my $firewallsso_method = ( $node->{status} eq $STATUS_REGISTERED ) ? "Update" : "Stop";
            my $client = pf::client::getClient();
            $client->notify( 'firewallsso', (method => $firewallsso_method, mac => $mac, ip => $ip, timeout => $DEFAULT_LEASE_LENGTH) );
        }
        else {
            $logger->error("Can't do SSO for $mac because can't find its IP address");
        }
    }

    my $locationlog_entry = locationlog_view_open_mac($mac);
    if ( !$locationlog_entry ) {
        $logger->warn("Can't re-evaluate access because no open locationlog entry was found");
        return;

    }

    my $conn_type = str_to_connection_type( $locationlog_entry->{'connection_type'} );
    if ( $conn_type == $INLINE ) {
        my $client = pf::client::getClient();
        my $inline = new pf::inline::custom();
        my %data = (
            'switch' => '127.0.0.1',
            'mac'    => $mac,
        );
        if ( $inline->isInlineEnforcementRequired($mac) ) {
            $client->notify( 'firewall', %data );
        }
        else {
            $logger->debug("is already properly enforced in firewall, no change required");
        }
        return 1;
    }

    return _vlan_reevaluation( $mac, $locationlog_entry, %opts );
}

=item _vlan_reevaluation

reevaluate the VLAN of a node.

=cut

sub _vlan_reevaluation {
    my ( $mac, $locationlog_entry, %opts ) = @_;
    my $logger = get_logger();

    if ( _should_we_reassign_vlan( $mac, $locationlog_entry, %opts ) ) {

        my $switch_id = $locationlog_entry->{'switch'} || 'unknown';
        my $ifIndex   = $locationlog_entry->{'port'}   || 'unknown';
        my $conn_type = str_to_connection_type( $locationlog_entry->{'connection_type'} );
        $logger->info( "switch port is (".$switch_id.") ifIndex $ifIndex "
                . "connection type: "
                . $connection_type_explained{$conn_type} );

        my $client;
        my $cluster_deauth;
        if ($cluster_enabled && isenabled($Config{active_active}{centralized_deauth})){
            $client = pf::client::getManagementClient();
            $cluster_deauth = 1;
        }
        else {
            $client = pf::api::queue->new(queue => 'priority');
            $cluster_deauth = 0;
        }
        my %data = (
            'switch'           => $switch_id,
            'mac'              => $mac,
            'connection_type'  => $conn_type,
            'ifIndex'          => $ifIndex
        );
        if ( ( $conn_type & $WIRED ) == $WIRED ) {
            $logger->debug("Calling API with ReAssign request on switch (".$switch_id.")");
            if ($cluster_deauth) {
                $client->notify( 'ReAssignVlan_in_queue', %data );
            } else {
                $client->notify( 'ReAssignVlan', %data );
            }
        }
        elsif ( ( ( $conn_type & $WIRELESS ) == $WIRELESS ) || ( ( $conn_type & $WEBAUTH ) == $WEBAUTH ) ) {
            $logger->debug("Calling API with desAssociate request on switch (".$switch_id.")");
            if ($cluster_deauth) {
                $client->notify( 'desAssociate_in_queue', %data );
            } else {
                $client->notify( 'desAssociate', %data );
            }
        }
        else {
            $logger->error("Connection type is neither wired nor wireless. Cannot reevaluate VLAN");
            return 0;
        }

    }
    return 1;
}

=item _should_we_reassign_vlan

Returns true or false whether or not we should request vlan adjustment

Evaluates node's VLAN through L<pf::role>'s fetchRoleForNode (which can be redefined by L<pf::role::custom>)

=cut

sub _should_we_reassign_vlan {
    my ( $mac, $locationlog_entry, %opts ) = @_;
    my $logger = get_logger();
    if ( $opts{'force'} ) {
        $logger->info("VLAN reassignment is forced.");
        return $TRUE;
    }

    my $switch_id       = $locationlog_entry->{'switch'};
    my $switch_ip       = $locationlog_entry->{'switch_ip'};
    my $switch_mac      = $locationlog_entry->{'switch_mac'};
    my $ifIndex         = $locationlog_entry->{'port'};
    my $currentVlan     = $locationlog_entry->{'vlan'};
    my $connection_type = str_to_connection_type( $locationlog_entry->{'connection_type'} );
    my $user_name       = $locationlog_entry->{'dot1x_username'};
    my $ssid            = $locationlog_entry->{'ssid'};
    my $role            = $locationlog_entry->{'role'};

    $logger->info("is currentlog connected at (".$switch_ip.") ifIndex $ifIndex ".(defined $role ? "${role}" : "(undefined)"));

    my $role_obj = new pf::role::custom();

    # TODO avoidable load?
    my $switch = pf::SwitchFactory->instantiate( { switch_mac => $switch_mac, switch_ip => $switch_ip } );
    if ( !$switch ) {
        $logger->error("Can't instantiate switch (".$switch_ip.")! Check your configuration!");
        return $FALSE;
    }

    my $args = {
        mac => $mac,
        switch => $switch,
        ifIndex => $ifIndex,
        connection_type => $connection_type,
        user_name => $user_name,
        ssid => $ssid,
        node_info => pf::node::node_attributes($mac),
        profile => pf::Connection::ProfileFactory->instantiate($mac),
    };

    my $newRole = $role_obj->fetchRoleForNode( $args );
    my $newCorrectVlan = $newRole->{vlan} || $switch->getVlanByName($newRole->{role});

    if (defined($newCorrectVlan)) {
        if ( $newCorrectVlan eq '-1' ) {
            $logger->info(
                "VLAN reassignment required (current VLAN = $currentVlan but should be in VLAN $newCorrectVlan)"
            );
            return $TRUE;
        } elsif (defined($currentVlan)) {
            if ( $newCorrectVlan ne $currentVlan ) {
                $logger->info(
                    "VLAN reassignment required (current VLAN = $currentVlan but should be in VLAN $newCorrectVlan)"
                );
                return $TRUE;
            }
        }
    }

    # If the role in the locationlog is not defined and the new one is, then we reevaluate access
    if (!defined($role) && defined($newRole->{role})) {
        $logger->info(
            "Reassignment required (current Role is undefined and should be in Role $newRole->{role})"
        );
        return $TRUE;
    }
    elsif ($role ne $newRole->{role}) {
        $logger->info(
            "Reassignment required (current Role = $role but should be in Role $newRole->{role})"
        );
        return $TRUE;
    }

    $logger->debug("No reassignment required.");
    return $FALSE;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
