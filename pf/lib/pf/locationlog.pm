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
use Log::Log4perl;
use Log::Log4perl::Level;
use Net::MAC;

our (
    $locationlog_history_mac_sql,
    $locationlog_history_switchport_sql,

    $locationlog_history_mac_date_sql,
    $locationlog_history_switchport_date_sql,

    $locationlog_view_all_sql,
    $locationlog_view_open_sql,
    $locationlog_view_open_mac_sql,
    $locationlog_view_open_switchport_sql,
    $locationlog_view_open_switchport_no_VoIP_sql,
    $locationlog_view_open_switchport_only_VoIP_sql,

    $locationlog_close_sql,

    $locationlog_cleanup_sql,

    $locationlog_insert_start_with_mac_sql,
    $locationlog_node_update_location_sql,
    $locationlog_insert_start_no_mac_sql,
    $locationlog_update_end_switchport_sql,
    $locationlog_update_end_switchport_no_VoIP_sql,
    $locationlog_update_end_switchport_only_VoIP_sql,
    $locationlog_update_end_mac_sql,

    $locationlog_db_prepared
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        locationlog_db_prepare

        locationlog_history_mac
        locationlog_history_switchport

        locationlog_view_all
        locationlog_view_all_open_mac
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
    );
}

use pf::config;
use pf::db;
use pf::node;
use pf::vlan::custom;
use pf::util;

$locationlog_db_prepared = 0;

#locationlog_db_prepare($dbh) if (!$thread);

=head1 SUBROUTINES

TODO: list incomplete

=over

=cut

sub locationlog_db_prepare {
    my ($dbh) = @_;
    db_connect($dbh);
    my $logger = Log::Log4perl::get_logger('pf::locationlog');
    $logger->debug("Preparing pf::locationlog database queries");
    $locationlog_history_mac_sql
        = $dbh->prepare(
        qq [ select mac,switch,port,vlan,voip,connection_type,start_time,end_time from locationlog where mac=? order by start_time desc, isnull(end_time) desc, end_time desc ]
        );
    $locationlog_history_switchport_sql
        = $dbh->prepare(
        qq [ select mac,switch,port,vlan,voip,connection_type,start_time,end_time from locationlog where switch=? and port=? order by start_time desc, isnull(end_time) desc, end_time desc ]
        );

    $locationlog_history_mac_date_sql
        = $dbh->prepare(
        qq [ select mac,switch,port,vlan,voip,connection_type,start_time,end_time from locationlog where mac=? and start_time < from_unixtime(?) and (end_time > from_unixtime(?) or isnull(end_time)) order by start_time desc, isnull(end_time) desc, end_time desc ]
        );
    $locationlog_history_switchport_date_sql
        = $dbh->prepare(
        qq [ select mac,switch,port,vlan,voip,connection_type,start_time,end_time from locationlog where switch=? and port=? and start_time < from_unixtime(?) and (end_time > from_unixtime(?) or isnull(end_time)) order by start_time desc, isnull(end_time) desc, end_time desc ]
        );

    $locationlog_view_all_sql
        = $dbh->prepare(
        qq [ select mac,switch,port,vlan,voip,connection_type,start_time,end_time from locationlog order by start_time desc, end_time desc]
        );
    $locationlog_view_open_sql
        = $dbh->prepare(
        qq [ select mac,switch,port,vlan,voip,connection_type,start_time,end_time from locationlog where isnull(end_time) or end_time=0 order by start_time desc ]
        );
    $locationlog_view_open_mac_sql
        = $dbh->prepare(
        qq [ select mac,switch,port,vlan,voip,connection_type,start_time,end_time from locationlog where mac=? and (isnull(end_time) or end_time=0) order by start_time desc]
        );
    $locationlog_view_open_switchport_sql
        = $dbh->prepare(
        qq [ select mac,switch,port,vlan,voip,connection_type,start_time,end_time from locationlog where switch=? and port=? and voip=? and (isnull(end_time) or end_time = 0) order by start_time desc]
        );
    $locationlog_view_open_switchport_no_VoIP_sql
        = $dbh->prepare(
        qq [ select mac,switch,port,vlan,voip,connection_type,start_time,end_time from locationlog where switch=? and port=? and (voip='no' or voip='') and (isnull(end_time) or end_time = 0) order by start_time desc]
        );
    $locationlog_view_open_switchport_only_VoIP_sql
        = $dbh->prepare(
        qq [ select mac,switch,port,vlan,voip,connection_type,start_time,end_time from locationlog where switch=? and port=? and voip='yes' and (isnull(end_time) or end_time = 0) order by start_time desc]
        );

    $locationlog_insert_start_no_mac_sql
        = $dbh->prepare(
        qq [ INSERT INTO locationlog (mac, switch, port, vlan, voip, connection_type, start_time) VALUES(NULL,?,?,?,?,?,NOW())]
        );
    $locationlog_insert_start_with_mac_sql
        = $dbh->prepare(
        qq [ INSERT INTO locationlog (mac, switch, port, vlan, voip, connection_type, start_time) VALUES(?,?,?,?,?,?,NOW())]
        );
    $locationlog_update_end_switchport_sql
        = $dbh->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE switch = ? AND port = ? AND (ISNULL(end_time) or end_time = 0) ]
        );
    $locationlog_update_end_switchport_no_VoIP_sql
        = $dbh->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE switch = ? AND port = ? AND (voip='no' or voip='') AND (ISNULL(end_time) or end_time = 0) ]
        );
    $locationlog_update_end_switchport_only_VoIP_sql
        = $dbh->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE switch = ? AND port = ? AND voip='yes' AND (ISNULL(end_time) or end_time = 0) ]
        );
    $locationlog_update_end_mac_sql
        = $dbh->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE mac = ? AND (ISNULL(end_time) or end_time = 0)]
        );

    $locationlog_close_sql
        = $dbh->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE (ISNULL(end_time) or end_time = 0)]
        );

    $locationlog_cleanup_sql
        = $dbh->prepare(
        qq [ delete from locationlog where unix_timestamp(end_time) < (unix_timestamp(now()) - ?) and end_time != 0 ]
        );
    $locationlog_db_prepared = 1;
}

sub locationlog_history_mac {
    my ( $mac, %params ) = @_;
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();
    if ( defined( $params{'date'} ) ) {
        return db_data( $locationlog_history_mac_date_sql,
            $mac, $params{'date'}, $params{'date'} );
    } else {
        $locationlog_history_mac_sql->execute($mac) || return (0);
        return db_data($locationlog_history_mac_sql);
    }
}

sub locationlog_history_switchport {
    my ( $switch, %params ) = @_;
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    if ( defined( $params{'date'} ) ) {
        return db_data( $locationlog_history_switchport_date_sql,
            $switch, $params{'ifIndex'}, $params{'date'}, $params{'date'} );
    } else {
        $locationlog_history_switchport_sql->execute( $switch,
            $params{'ifIndex'} )
            || return (0);
        return db_data($locationlog_history_switchport_sql);
    }
}

sub locationlog_view_all {
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    return db_data($locationlog_view_all_sql);
}

sub locationlog_view_all_open_mac {
    my ($mac) = @_;
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();
    return db_data( $locationlog_view_open_mac_sql, $mac );
}

sub locationlog_view_open {
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    return db_data($locationlog_view_open_sql);
}

sub locationlog_view_open_switchport {
    my ( $switch, $ifIndex, $voip ) = @_;
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    return db_data( $locationlog_view_open_switchport_sql, $switch, $ifIndex, $voip );
}

sub locationlog_view_open_switchport_no_VoIP {
    my ( $switch, $ifIndex ) = @_;
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    return db_data( $locationlog_view_open_switchport_no_VoIP_sql,
        $switch, $ifIndex );
}

sub locationlog_view_open_switchport_only_VoIP {
    my ( $switch, $ifIndex ) = @_;
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    $locationlog_view_open_switchport_only_VoIP_sql->execute( $switch,
        $ifIndex )
        || return (0);
    my $ref
        = $locationlog_view_open_switchport_only_VoIP_sql->fetchrow_hashref();

    # just get one row and finish
    $locationlog_view_open_switchport_only_VoIP_sql->finish();
    return ($ref);
}

sub locationlog_view_open_mac {
    my ($mac) = @_;
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();
    $locationlog_view_open_mac_sql->execute($mac) || return (0);
    my $ref = $locationlog_view_open_mac_sql->fetchrow_hashref();

    # just get one row and finish
    $locationlog_view_open_mac_sql->finish();
    return ($ref);
}

sub locationlog_insert_start {
    my ( $switch, $ifIndex, $vlan, $mac, $voip, $connection_type ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::locationlog');

    my $conn_type = connection_type_to_str($connection_type)
        or $logger->info("Asked to insert a locationlog entry with connection type unknown.");
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    if ( defined($mac) ) {
        $locationlog_insert_start_with_mac_sql->execute(lc($mac), $switch, $ifIndex, $vlan, $voip, $conn_type)
            || return (0);
    } else {
        $locationlog_insert_start_no_mac_sql->execute($switch, $ifIndex, $vlan, $voip, $conn_type) || return (0);
    }
    return (1);
}

sub locationlog_update_end {
    my ( $switch, $ifIndex, $mac ) = @_;
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::locationlog');
    if ( defined($mac) ) {
        $logger->info("locationlog_update_end called with mac=$mac");
        locationlog_update_end_mac($mac);
    } else {
        $logger->info("locationlog_update_end called without mac");
        $locationlog_update_end_switchport_sql->execute( $switch, $ifIndex )
            || return (0);
    }
    return (1);
}

sub locationlog_update_end_switchport_no_VoIP {
    my ( $switch, $ifIndex ) = @_;
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    $locationlog_update_end_switchport_no_VoIP_sql->execute( $switch,
        $ifIndex )
        || return (0);
    return (1);
}

sub locationlog_update_end_switchport_only_VoIP {
    my ( $switch, $ifIndex ) = @_;
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    $locationlog_update_end_switchport_only_VoIP_sql->execute( $switch,
        $ifIndex )
        || return (0);
    return (1);
}

sub locationlog_update_end_mac {
    my ($mac) = @_;
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    $locationlog_update_end_mac_sql->execute($mac) || return (0);
    return (1);
}

=item * locationlog_synchronize 

synchronize locationlog to current values if necessary

=cut
sub locationlog_synchronize {
    my ( $switch, $ifIndex, $vlan, $mac, $voip_status, $connection_type ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::locationlog');
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
                $mac, $voip_status, $connection_type)) {

                $logger->debug("closing old locationlog entry because something about this node changed");
                $locationlog_update_end_mac_sql->execute($mac) || return (0);
                $mustInsert = 1;
            }

        } else {
            $mustInsert = 1;
            $logger->debug("no open locationlog entry, we need to insert a new one");
        }

        if ( !node_exist($mac) ) {
            node_add_simple($mac);
        }

        _update_node_if_not_accurate($switch, $ifIndex, $vlan, $mac, $voip_status, $connection_type);
    }

    # if we are in a wired environment, close any conflicting switchport entry
    # but paying attention to VoIP vs non-VoIP entries (we close the same type that we are asked to add)
    if (($connection_type & WIRED) == WIRED) {

        my @locationlog_switchport = locationlog_view_open_switchport($switch, $ifIndex, $voip_status);
        if (!(@locationlog_switchport && scalar(@locationlog_switchport) > 0)) {
            # there was no locationlog open we must insert a new one
            $mustInsert = 1;

        } elsif (($locationlog_switchport[0]->{vlan} != $vlan) # vlan changed
            || (defined($mac) && (!defined($locationlog_switchport[0]->{mac})))) { # or MAC changed 

            # close entries of same voip status
            if ($locationlog_switchport[0]->{voip} eq NO_VOIP) {
                $locationlog_update_end_switchport_no_VoIP_sql->execute($switch, $ifIndex);
            } else {
                $locationlog_update_end_switchport_only_VoIP_sql->execute($switch, $ifIndex);
            }
            $mustInsert = 1;
        }
    }

    # we insert a locationlog entry
    if ($mustInsert) {
        locationlog_insert_start($switch, $ifIndex, $vlan, $mac, $voip_status, $connection_type)
            or $logger->warn("Unable to insert a locationlog entry.");
    }
    return 1;
}

sub locationlog_close_all {
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    $locationlog_close_sql->execute() || return (0);
    return (0);
}

sub locationlog_cleanup {
    my ($time) = @_;
    my $logger = Log::Log4perl::get_logger('pf::locationlog');
    locationlog_db_prepare($dbh) if ( !$locationlog_db_prepared );
    $logger->debug("calling locationlog_cleanup with time=$time");
    $locationlog_cleanup_sql->execute($time) || return (0);
    my $rows = $locationlog_cleanup_sql->rows;
    $logger->log( ( ( $rows > 0 ) ? $INFO : $DEBUG ),
        "deleted $rows entries from locationlog during locationlog cleanup" );
    return (0);
}

=item * _is_locationlog_accurate 

return 1 if locationlog entry is accurate, 0 otherwise

=cut
sub _is_locationlog_accurate {
    my ( $locationlog_mac, $switch, $ifIndex, $vlan, $mac, $voip_status, $connection_type ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::locationlog');
    $logger->trace("verifying if locationlog is accurate called");

    # did something changed
    my $vlanChanged        = ($locationlog_mac->{vlan} != $vlan);
    my $switchChanged      = ($locationlog_mac->{switch} ne $switch);
    my $voip_statusChanged = ($locationlog_mac->{voip} ne $voip_status);
    my $conn_typeChanged   = ($locationlog_mac->{connection_type} ne connection_type_to_str($connection_type));
    # ifIndex on wireless is not important
    my $ifIndexChanged = 0;
    if (($connection_type & WIRED) == WIRED) {
        $ifIndexChanged = ($locationlog_mac->{port} != $ifIndex);
    }

    if ($vlanChanged || $switchChanged || $voip_statusChanged || $conn_typeChanged || $ifIndexChanged) {
        $logger->trace("latest locationlog entry is not accurate");
        return 0;
    } else {
        $logger->debug("latest locationlog entry is still accurate");
        return 1;
    }
}

=item * _update_node_if_not_accurate 

Updates the node entry if node position changed. 
Uses vlan extension point to determine what to update.

=cut
sub _update_node_if_not_accurate {
    my ($switch, $ifIndex, $vlan, $mac, $voip_status, $connection_type) = @_;
    my $logger = Log::Log4perl::get_logger('pf::locationlog');

    # is node entry accurate?
    # TODO: refactor into it's own sub
    my $node_data          = node_view($mac);
    my $vlanChanged        = ($node_data->{vlan} != $vlan);
    my $switchChanged      = ($node_data->{switch} ne $switch);
    my $voip_statusChanged = ($node_data->{voip} ne $voip_status);
    my $conn_typeChanged   = ($node_data->{connection_type} ne connection_type_to_str($connection_type));
    # ifIndex on wireless is not important
    my $ifIndexChanged = 0;
    if (($connection_type & WIRED) == WIRED) {
        $ifIndexChanged = ($node_data->{port} != $ifIndex);
    }

    if ($vlanChanged || $switchChanged || $voip_statusChanged || $conn_typeChanged || $ifIndexChanged) {

        $logger->debug("calling node_modify with vlan getNodeUpdatedInfo's answers");
        # node_modiify (we redirect node update to vlan extension point)
        my $vlan_obj = new pf::vlan::custom();
        node_modify( $mac,
            $vlan_obj->getNodeUpdatedInfo($mac, $switch, $ifIndex, $vlan, $voip_status, $connection_type));
    }
    return 1;
}

=back

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2007-2008,2010 Inverse inc.

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
