package pf::locationlog;

=head1 NAME

pf::locationlog - module for MAC-Switch-Port-VLAN logging.

=cut

=head1 DESCRIPTION

pf::locationlog contains the functions necessary to manage the
MAC-Switch-Port-VLAN history.

=cut

use strict;
use warnings;
use pf::log;
use pf::floatingdevice::custom;
use pf::StatsD::Timer;
use pf::util::statsd qw(called);
use pf::CHI::Request;
use CHI::Memoize qw(memoize memoized);

use constant LOCATIONLOG => 'locationlog';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        $locationlog_db_prepared
        locationlog_db_prepare

        locationlog_history_mac
        locationlog_history_switchport

        locationlog_view_open
        locationlog_view_open_mac
        locationlog_view_open_switchport
        locationlog_view_open_switchport_no_VoIP
        locationlog_view_open_switchport_only_VoIP

        locationlog_close_all
        locationlog_cleanup

        locationlog_insert_start
        locationlog_update_end
        locationlog_update_end_mac
        locationlog_update_end_switchport_no_VoIP
        locationlog_update_end_switchport_only_VoIP
        locationlog_synchronize

        locationlog_set_session
        locationlog_get_session
        locationlog_last_entry_mac
    );
}

use pf::config qw(
    $WIRED
    $NO_VOIP
);
use pf::db;
use pf::node;
use pf::util;
use pf::config::util;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $locationlog_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $locationlog_statements = {};

=head1 DATA FORMAT

TODO: list incomplete

=over

=item dot1x_username

RADIUS' User-Name attribute only popuplated if connection was EAP (802.1X) and the user successfully authenticated.
Max length is 255 bytes according to RFC2865.

=item ssid (Service Set Identifier)

Identifies the Wireless Network related to the RADIUS Access-Request.
The field is not standardized so depending on your hardware it might not be properly populated.
See our RADIUS' module find_ssid() documentation for more information about this.
Max length is 32 bytes according to IEEE 802.11-1999.

=back

=head1 SUBROUTINES

TODO: list incomplete

=over

=cut

sub locationlog_db_prepare {
    my $logger = get_logger();
    $logger->debug("Preparing pf::locationlog database queries");

    $locationlog_statements->{'locationlog_history_mac_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, start_time, end_time, stripped_user_name, realm
        FROM locationlog
        WHERE mac = ?
        ORDER BY start_time DESC, end_time DESC
        LIMIT 25
    ]);

    $locationlog_statements->{'locationlog_history_switchport_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, start_time, end_time, stripped_user_name, realm
        FROM locationlog
        WHERE switch = ? and port = ?
        ORDER BY start_time desc, end_time desc
    ]);

    $locationlog_statements->{'locationlog_history_mac_date_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, start_time, end_time, stripped_user_name, realm,
          UNIX_TIMESTAMP(start_time) AS start_timestamp,
          UNIX_TIMESTAMP(end_time) AS end_timestamp
        FROM locationlog
        WHERE mac = ? AND start_time < from_unixtime(?) AND end_time > from_unixtime(?)
        ORDER BY start_time desc, end_time desc
    ]);

    $locationlog_statements->{'locationlog_history_switchport_date_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, start_time, end_time, stripped_user_name, realm
        FROM locationlog
        WHERE
            switch = ? AND port = ? AND start_time < from_unixtime(?)
            AND end_time > from_unixtime(?)
        ORDER BY start_time desc, end_time desc
    ]);

    $locationlog_statements->{'locationlog_view_open_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, start_time, end_time, stripped_user_name, realm
        FROM locationlog
        WHERE end_time = 0
        ORDER BY start_time desc
    ]);

    $locationlog_statements->{'locationlog_view_open_mac_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, start_time, end_time, stripped_user_name, realm
        FROM locationlog
        WHERE mac = ? AND end_time = 0
        ORDER BY start_time desc
    ]);

    $locationlog_statements->{'locationlog_view_open_switchport_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, start_time, end_time, stripped_user_name, realm
        FROM locationlog
            LEFT JOIN node USING (mac)
        WHERE switch = ? AND port = ? AND node.voip = ? AND end_time = 0
        ORDER BY start_time desc
    ]);

    $locationlog_statements->{'locationlog_view_open_switchport_no_VoIP_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, start_time, end_time, stripped_user_name, realm
        FROM locationlog
            LEFT JOIN node USING (mac)
        WHERE switch = ? AND port = ?
            AND (node.voip = '' OR node.voip = 'no')
            AND end_time = 0
        ORDER BY start_time desc
    ]);

    $locationlog_statements->{'locationlog_view_open_switchport_only_VoIP_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, start_time, end_time, stripped_user_name, realm
        FROM locationlog
            LEFT JOIN node USING (mac)
        WHERE switch = ? AND port = ?
            AND node.voip = 'yes'
            AND end_time = 0
        ORDER BY start_time desc
    ]);

    $locationlog_statements->{'locationlog_insert_start_no_mac_sql'} = get_db_handle()->prepare(qq[
        INSERT INTO locationlog (
            mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, stripped_user_name, realm, start_time
        ) VALUES (
            NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW() )
    ]);

    $locationlog_statements->{'locationlog_insert_start_with_mac_sql'} = get_db_handle()->prepare(qq[
        INSERT INTO locationlog (
            mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, stripped_user_name, realm, start_time
        ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ? ,?, ?, ?, ?, ?, NOW() )
    ]);

    $locationlog_statements->{'locationlog_insert_closed_sql'} = get_db_handle()->prepare(qq[
        INSERT INTO locationlog (
            mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, stripped_user_name, realm, start_time, end_time
        ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW()
        )
    ]);

    $locationlog_statements->{'locationlog_update_end_switchport_sql'} = get_db_handle()->prepare(qq[
        UPDATE locationlog SET end_time = now()
        WHERE switch = ? AND port = ? AND end_time = 0
    ]);

    $locationlog_statements->{'locationlog_update_end_switchport_no_VoIP_sql'} = get_db_handle()->prepare(qq[
        UPDATE locationlog
            INNER JOIN node USING (mac)
        SET end_time = now()
        WHERE switch = ? AND port = ? AND (node.voip = 'no' or node.voip = '') AND end_time = 0
    ]);

    $locationlog_statements->{'locationlog_update_end_switchport_only_VoIP_sql'} = get_db_handle()->prepare(qq[
        UPDATE locationlog
            INNER JOIN node USING (mac)
        SET end_time = now()
        WHERE switch = ? AND port = ? AND node.voip = 'yes' AND end_time = 0
    ]);

    $locationlog_statements->{'locationlog_update_end_mac_sql'} = get_db_handle()->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE mac = ? AND end_time = 0]);

    $locationlog_statements->{'locationlog_close_sql'} = get_db_handle()->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE end_time = 0]);

    $locationlog_statements->{'locationlog_cleanup_sql'} = get_db_handle()->prepare(
        qq [ delete from locationlog where end_time < DATE_SUB(?, INTERVAL ? SECOND) and end_time != 0 LIMIT ?]);

    $locationlog_statements->{'locationlog_set_session_sql'} = get_db_handle()->prepare(
        qq [ UPDATE locationlog SET session_id = ? WHERE mac = ? AND end_time = 0 ]);

    $locationlog_statements->{'locationlog_get_session_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, start_time, end_time, stripped_user_name, realm, session_id from locationlog WHERE session_id = ? AND end_time = 0 order by start_time desc]);

    $locationlog_statements->{'locationlog_last_entry_mac_sql'} = get_db_handle()->prepare(qq [
        SELECT mac, switch, switch_ip, switch_mac, port, vlan, role, connection_type, connection_sub_type, dot1x_username, ssid, start_time, end_time, stripped_user_name, realm
        FROM locationlog
        WHERE mac = ?
        ORDER BY start_time DESC LIMIT 1 ]);

    $locationlog_db_prepared = 1;
}

# TODO: extract this out of here and into pf::pfcmd::report
# think about web ui and pfcmd
sub locationlog_history_mac {
    my ( $mac, %params ) = @_;
    $mac = clean_mac($mac);

    require pf::pfcmd::report;
    import pf::pfcmd::report;

    if ( defined( $params{'date'} ) ) {
        return translate_connection_type(
            db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_history_mac_date_sql',
                $mac, $params{'date'}, $params{'date'})
        );
    } elsif ( defined( $params{'start_time'} ) && defined( $params{'end_time'} ) ) {
        return translate_connection_type(
            db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_history_mac_date_sql',
                $mac, $params{'end_time'}, $params{'start_time'})
        );
    } else {
        return translate_connection_type(
            db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_history_mac_sql', $mac)
        );
    }
}

# TODO: extract this out of here and into pf::pfcmd::report
# think about web ui and pfcmd
sub locationlog_history_switchport {
    my ( $switch, %params ) = @_;

    require pf::pfcmd::report;
    import pf::pfcmd::report;
    if ( defined( $params{'date'} ) ) {
        return translate_connection_type(db_data(LOCATIONLOG, $locationlog_statements,
            'locationlog_history_switchport_date_sql', $switch, $params{'ifIndex'}, $params{'date'}, $params{'date'}));
    } else {
        return translate_connection_type(db_data(LOCATIONLOG, $locationlog_statements,
            'locationlog_history_switchport_sql', $switch, $params{'ifIndex'}));
    }
}

sub locationlog_view_open {
    return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_view_open_sql');
}

sub locationlog_view_open_switchport {
    my ( $switch, $ifIndex, $voip ) = @_;
    return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_view_open_switchport_sql', $switch, $ifIndex, $voip );
}

sub locationlog_view_open_switchport_no_VoIP {
    my ( $switch, $ifIndex ) = @_;
    return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_view_open_switchport_no_VoIP_sql',
        $switch, $ifIndex);
}

sub locationlog_view_open_switchport_only_VoIP {
    my ( $switch, $ifIndex ) = @_;
    my $query = db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_view_open_switchport_only_VoIP_sql',
        $switch, $ifIndex)
        || return (0);

    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

sub locationlog_view_open_mac {
    my ($mac) = @_;
    $mac = clean_mac($mac);

    my $query = db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_view_open_mac_sql', $mac)
        || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

sub locationlog_insert_start {
    my ( $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, $locationlog_mac ) = @_;
    my $logger = get_logger();

    my $conn_type = connection_type_to_str($connection_type)
        or $logger->info("Asked to insert a locationlog entry with connection type unknown.");

    # warning avoidance
    $user_name = "" if (!defined($user_name));
    $ssid = "" if (!defined($ssid));

    if (!(defined($vlan)) && defined($locationlog_mac->{'vlan'})) {
        $vlan = $locationlog_mac->{'vlan'};
    }
    if (!(defined($role)) && defined($locationlog_mac->{'role'})) {
        $role = $locationlog_mac->{'role'};
    }
    if ( defined($mac) ) {
        db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_insert_start_with_mac_sql',
            lc($mac), $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $role, $conn_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm)
            || return (0);
        node_remove_from_cache($mac);
    } else {
        db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_insert_start_no_mac_sql',
            $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $role, $conn_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm)
            || return (0);
    }
    return (1);
}

sub locationlog_update_end {
    my ( $switch, $ifIndex, $mac ) = @_;

    my $logger = get_logger();
    if ( defined($mac) ) {
        $logger->info("locationlog_update_end called with mac=$mac");
        locationlog_update_end_mac($mac);
    } else {
        $logger->info("locationlog_update_end called without mac");
        db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_update_end_switchport_sql',
            $switch, $ifIndex)
            || return (0);
    }
    return (1);
}

sub locationlog_update_end_switchport_no_VoIP {
    my ( $switch, $ifIndex ) = @_;

    db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_update_end_switchport_no_VoIP_sql',
        $switch, $ifIndex)
        || return (0);
    return (1);
}

sub locationlog_update_end_switchport_only_VoIP {
    my ( $switch, $ifIndex ) = @_;

    db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_update_end_switchport_only_VoIP_sql',
        $switch, $ifIndex)
        || return (0);
    return (1);
}

sub locationlog_update_end_mac {
    my ($mac) = @_;

    db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_update_end_mac_sql', $mac)
        || return (0);
    node_remove_from_cache($mac);
    return (1);
}

=item * locationlog_synchronize

synchronize locationlog to current values if necessary

 $voip_status expects VOIP / NO_VOIP constants

=cut

sub locationlog_synchronize {
    my $timer = pf::StatsD::Timer->new({ sample_rate => 0.2 });
    my ( $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role) = @_;
    my $logger = get_logger();
    $logger->trace("locationlog_synchronize called");

    # flag to determine if we must insert a new record or not
    my $mustInsert = 0;

    if ( defined($mac) ) {

        $mac = lc($mac);

        # grab latest open locationlog entry
        my $locationlog_mac = locationlog_view_open_mac($mac);
        if (defined($locationlog_mac) && ref($locationlog_mac) eq 'HASH') {
            $logger->trace("existing open locationlog entry");

            # did something changed?
            if (!_is_locationlog_accurate($locationlog_mac, $switch, $ifIndex, $vlan,
                $mac, $connection_type, $connection_sub_type, $user_name, $ssid, $role)) {

                #If the last connection was inline then make sure to clean ipset
                if ( ( (str_to_connection_type($locationlog_mac->{connection_type}) & $pf::config::INLINE) == $pf::config::INLINE ) && !($connection_type && ($connection_type & $pf::config::INLINE) == $pf::config::INLINE) ) {
                    $logger->debug("Unmark node in ipset session since the connection type changed from inline to something else");
                    my $inline = new pf::inline::custom();
                    my $mark = $inline->{_technique}->get_mangle_mark_for_mac($mac);
                    $inline->{_technique}->iptables_unmark_node($mac,$mark) if (defined($mark));
                }

                $logger->debug("closing old locationlog entry because something about this node changed");
                db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_update_end_mac_sql', $mac)
                    || return (0);
                locationlog_insert_start($switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, $locationlog_mac);
            }

        } else {
            $mustInsert = 1;
            $logger->debug("no open locationlog entry, we need to insert a new one");
        }

        if ( !node_exist($mac) ) {
            node_add_simple($mac);
        }
    }

    # if we are in a wired environment, close any conflicting switchport entry
    # but paying attention to VoIP vs non-VoIP entries (we close the same type that we are asked to add)
    if ($connection_type && ($connection_type & $WIRED) == $WIRED) {
        my $floatingDeviceManager = new pf::floatingdevice::custom();
        if( $floatingDeviceManager->portHasFloatingDevice($switch_ip, $ifIndex) ){
            $logger->info("Not adding locationlog entry for mac $mac because it's plugged in a floating device enabled port");
            return 1;
        }

        my @locationlog_switchport = locationlog_view_open_switchport($switch, $ifIndex, $voip_status);
        if (!(@locationlog_switchport && scalar(@locationlog_switchport) > 0)) {
            # there was no locationlog open we must insert a new one
            $mustInsert = 1;

        } elsif (($locationlog_switchport[0]->{vlan} ne $vlan) # vlan changed
            || (defined($mac) && (!defined($locationlog_switchport[0]->{mac})))
            || (defined($locationlog_switchport[0]->{role}) && ($locationlog_switchport[0]->{role} ne $role) ) ) { # or Role changed

            # close entries of same voip status
            if ($voip_status eq $NO_VOIP) {
                db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_update_end_switchport_no_VoIP_sql',
                    $switch, $ifIndex);
            } else {
                db_query_execute(LOCATIONLOG, $locationlog_statements,
                    'locationlog_update_end_switchport_only_VoIP_sql', $switch, $ifIndex);
            }
            $mustInsert = 1;
        }
    }

    # we insert a locationlog entry
    if ($mustInsert) {
        locationlog_insert_start($switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role)
            or $logger->warn("Unable to insert a locationlog entry.");
    }
    return 1;
}

sub locationlog_close_all {
    db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_close_sql');
    return (0);
}

sub locationlog_cleanup {
    my $timer = pf::StatsD::Timer->new({ sample_rate => 0.2 });
    my ($expire_seconds, $batch, $time_limit) = @_;
    my $logger = get_logger();
    $logger->debug("calling locationlog_cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit");
    my $now = db_now();
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $query = db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_cleanup_sql', $now, $expire_seconds, $batch)
        || return (0);
        my $rows = $query->rows;
        $query->finish;
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        $logger->trace( sub { "deleted $rows_deleted entries from locationlog during locationlog cleanup ($start_time $end_time) " });
        last if $rows <= 0 || (( $end_time - $start_time) > $time_limit );
    }
    $logger->trace( "deleted $rows_deleted entries from locationlog during locationlog cleanup ($start_time $end_time) " );
    return (0);
}

=item * _is_locationlog_accurate

return 1 if locationlog entry is accurate, 0 otherwise

=cut

# Note: voip_status was removed from the accuracy check, feel free to revisit this assumption if we face VoIP problems
sub _is_locationlog_accurate {
    my $timer = pf::StatsD::Timer->new({ sample_rate => 0.05, level => 7 });
    my ( $locationlog_mac, $switch, $ifIndex, $vlan, $mac, $connection_type, $connection_sub_type, $user_name, $ssid, $role ) = @_;
    my $logger = get_logger();
    $logger->trace("verifying if locationlog is accurate called");

    # avoid undef warnings during tests by setting undef values to empty string
    $user_name = '' if (!defined($user_name));
    $ssid = '' if (!defined($ssid));

    # did something changed
    my $vlanChanged = '0';
    if (defined($vlan)) {
        $vlanChanged = (exists($locationlog_mac->{'vlan'}) && defined($locationlog_mac->{'vlan'}) &&  $locationlog_mac->{'vlan'} ne $vlan);
    }
    my $switchChanged = ($locationlog_mac->{'switch'} ne $switch);
    my $conn_typeChanged = ($locationlog_mac->{connection_type} ne connection_type_to_str($connection_type));
    my $userChanged = ($locationlog_mac->{'dot1x_username'} ne $user_name);
    my $ssidChanged = ($locationlog_mac->{'ssid'} ne $ssid);
    my $roleChanged = '0';
    if (defined($role)) {
        my $old_role = $locationlog_mac->{'role'};
        $roleChanged = ( defined ($old_role) && $old_role ne $role);
    }
    # ifIndex on wireless is not important
    my $ifIndexChanged = 0;
    if (($connection_type & $WIRED) == $WIRED) {
        $ifIndexChanged = ($locationlog_mac->{port} ne $ifIndex);
    }

    if ($vlanChanged || $switchChanged || $conn_typeChanged || $ifIndexChanged || $userChanged || $ssidChanged || $roleChanged) {
        $logger->trace("latest locationlog entry is not accurate");
        return 0;
    } else {
        $logger->debug("latest locationlog entry is still accurate");
        return 1;
    }
}

sub locationlog_get_session {
    my ( $session_id ) = @_;
    my @entries = db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_get_session_sql', $session_id );
    return $entries[0];
}

sub locationlog_set_session {
    my ( $mac, $session_id ) = @_;
    return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_set_session_sql', $session_id, $mac );
}

=item locationlog_last_entry_mac

Return the last locationlog entry for a mac even if it's open or close.

=cut

sub locationlog_last_entry_mac {
    my ($mac) = @_;
    $mac = clean_mac($mac);
    my $query =  db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_last_entry_mac_sql', $mac) || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
