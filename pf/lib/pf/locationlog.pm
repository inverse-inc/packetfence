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

use pf::db;
use pf::node;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $locationlog_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $locationlog_statements = {};

sub locationlog_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::locationlog');
    $logger->debug("Preparing pf::locationlog database queries");

    $locationlog_statements->{'locationlog_history_mac_sql'} = get_db_handle()->prepare(
        qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where mac=? order by start_time desc, isnull(end_time) desc, end_time desc ]);

    $locationlog_statements->{'locationlog_history_switchport_sql'} = get_db_handle()->prepare(
        qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where switch=? and port=? order by start_time desc, isnull(end_time) desc, end_time desc ]);

    $locationlog_statements->{'locationlog_history_mac_date_sql'} = get_db_handle()->prepare(
        qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where mac=? and start_time < from_unixtime(?) and (end_time > from_unixtime(?) or isnull(end_time)) order by start_time desc, isnull(end_time) desc, end_time desc ]);

    $locationlog_statements->{'locationlog_history_switchport_date_sql'} = get_db_handle()->prepare(
        qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where switch=? and port=? and start_time < from_unixtime(?) and (end_time > from_unixtime(?) or isnull(end_time)) order by start_time desc, isnull(end_time) desc, end_time desc ]);

    $locationlog_statements->{'locationlog_view_all_sql'} = get_db_handle()->prepare(
        qq [ select mac,switch,port,vlan,start_time,end_time from locationlog order by start_time desc, end_time desc]);

    $locationlog_statements->{'locationlog_view_open_sql'} = get_db_handle()->prepare(
        qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where isnull(end_time) or end_time=0 order by start_time desc ]);

    $locationlog_statements->{'locationlog_view_open_mac_sql'} = get_db_handle()->prepare(
        qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where mac=? and (isnull(end_time) or end_time=0) order by start_time desc]);

    $locationlog_statements->{'locationlog_view_open_switchport_sql'} = get_db_handle()->prepare(
        qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where switch=? and port=? and (isnull(end_time) or end_time = 0) order by start_time desc]);

    $locationlog_statements->{'locationlog_view_open_switchport_no_VoIP_sql'} = get_db_handle()->prepare(
        qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where switch=? and port=? and vlan!='VoIP' and (isnull(end_time) or end_time = 0) order by start_time desc]);

    $locationlog_statements->{'locationlog_view_open_switchport_only_VoIP_sql'} = get_db_handle()->prepare(
        qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where switch=? and port=? and vlan='VoIP' and (isnull(end_time) or end_time = 0) order by start_time desc]);

    $locationlog_statements->{'locationlog_insert_start_no_mac_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO locationlog (mac, switch, port, vlan, start_time) VALUES(NULL,?,?,?,NOW())]);

    $locationlog_statements->{'locationlog_insert_start_with_mac_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO locationlog (mac, switch, port, vlan, start_time) VALUES(?,?,?,?,NOW())]);

    $locationlog_statements->{'locationlog_node_update_location_sql'} = get_db_handle()->prepare(
        qq [ UPDATE node SET switch=?, port=? WHERE mac=? ]);

    $locationlog_statements->{'locationlog_update_end_switchport_sql'} = get_db_handle()->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE switch = ? AND port = ? AND (ISNULL(end_time) or end_time = 0)]); 

    $locationlog_statements->{'locationlog_update_end_switchport_no_VoIP_sql'} = get_db_handle()->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE switch = ? AND port = ? AND vlan!='VoIP' AND (ISNULL(end_time) or end_time = 0) ]);

    $locationlog_statements->{'locationlog_update_end_switchport_only_VoIP_sql'} = get_db_handle()->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE switch = ? AND port = ? AND vlan='VoIP' AND (ISNULL(end_time) or end_time = 0) ]);

    $locationlog_statements->{'locationlog_update_end_mac_sql'} = get_db_handle()->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE mac = ? AND (ISNULL(end_time) or end_time = 0)]);

    $locationlog_statements->{'locationlog_close_sql'} = get_db_handle()->prepare(
        qq [ UPDATE locationlog SET end_time = now() WHERE (ISNULL(end_time) or end_time = 0)]);

    $locationlog_statements->{'locationlog_cleanup_sql'} = get_db_handle()->prepare(
        qq [ delete from locationlog where unix_timestamp(end_time) < (unix_timestamp(now()) - ?) and end_time != 0 ]);

    $locationlog_db_prepared = 1;
}

sub locationlog_history_mac {
    my ( $mac, %params ) = @_;

    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();
    if ( defined( $params{'date'} ) ) {
        return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_history_mac_date_sql',
            $mac, $params{'date'}, $params{'date'});
    } else {
        return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_history_mac_sql', $mac);
    }
}

sub locationlog_history_switchport {
    my ( $switch, %params ) = @_;

    if ( defined( $params{'date'} ) ) {
        return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_history_switchport_date_sql',
            $switch, $params{'ifIndex'}, $params{'date'}, $params{'date'});
    } else {
        return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_history_switchport_sql', 
            $switch, $params{'ifIndex'});
    }
}

sub locationlog_view_all {
    return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_view_all_sql');
}

sub locationlog_view_all_open_mac {
    my ($mac) = @_;

    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();

    return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_view_open_mac_sql', $mac);
}

sub locationlog_view_open {
    return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_view_open_sql');
}

sub locationlog_view_open_switchport {
    my ( $switch, $ifIndex ) = @_;
    return db_data(LOCATIONLOG, $locationlog_statements, 'locationlog_view_open_switchport_sql', $switch, $ifIndex);
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

    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();

    my $query = db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_view_open_mac_sql', $mac)
        || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

sub locationlog_insert_start {
    my ( $switch, $ifIndex, $vlan, $mac ) = @_;

    if ( defined($mac) ) {
        db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_insert_start_with_mac_sql', 
            lc($mac), $switch, $ifIndex, $vlan)
            || return (0);
        db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_node_update_location_sql', 
            $switch, $ifIndex, lc($mac));
    } else {
        db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_insert_start_no_mac_sql', 
            $switch, $ifIndex, $vlan)
            || return (0);
    }
    return (1);
}

sub locationlog_update_end {
    my ( $switch, $ifIndex, $mac ) = @_;

    my $logger = Log::Log4perl::get_logger('pf::locationlog');
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
    return (1);
}

#synchronize locationlog to current values if necessary
#if locationlog table contains an open entry for $switch, $ifIndex, $vlan, $mac
#and no other open entry for $mac
#and the node table contains $switch, $ifIndex for $mac
#then do nothing
sub locationlog_synchronize {
    my ( $switch, $ifIndex, $vlan, $mac ) = @_;

    if ( defined($mac) ) {
        $mac = lc($mac);
        my $locationlog_mac = locationlog_view_open_mac($mac);
        if (( defined($locationlog_mac) )
            && (   ( $locationlog_mac->{vlan} != $vlan )
                || ( $locationlog_mac->{switch} ne $switch )
                || ( $locationlog_mac->{port} != $ifIndex ) )
            )
        {
            db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_update_end_mac_sql', $mac) 
                || return (0);
        }
        if ( !node_exist($mac) ) {
            node_add_simple($mac);
        }
        my $node_data = node_view($mac);
        if (   ( $node_data->{'switch'} ne $switch )
            || ( $node_data->{'port'} ne $ifIndex ) )
        {
            node_modify( $mac, ( 'switch' => $switch, 'port' => $ifIndex ) );

       #$locationlog_node_update_location_sql->execute($switch,$ifIndex,$mac);
        }
    }
    my $mustInsert = 0;
    my @locationlog_switchport
        = locationlog_view_open_switchport_no_VoIP( $switch, $ifIndex );
    if ( !( @locationlog_switchport && scalar(@locationlog_switchport) > 0 ) )
    {
        $mustInsert = 1;
    } elsif (
        ( $locationlog_switchport[0]->{vlan} != $vlan )
        || ( defined($mac)
            && ( !defined( $locationlog_switchport[0]->{mac} ) ) )
        )
    {
        db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_update_end_switchport_no_VoIP_sql', 
            $switch, $ifIndex);
        $mustInsert = 1;
    }
    if ($mustInsert) {
        if ( defined($mac) ) {
            db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_insert_start_with_mac_sql', 
                $mac, $switch, $ifIndex, $vlan)
                || return (0);
        } else {
            db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_insert_start_no_mac_sql', 
                $switch, $ifIndex, $vlan)
                || return (0);
        }
    }
    return 1;
}

sub locationlog_close_all {
    db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_close_sql');
    return (0);
}

sub locationlog_cleanup {
    my ($time) = @_;
    my $logger = Log::Log4perl::get_logger('pf::locationlog');

    $logger->debug("calling locationlog_cleanup with time=$time");
    my $query = db_query_execute(LOCATIONLOG, $locationlog_statements, 'locationlog_cleanup_sql', $time)
        || return (0);

    my $rows = $query->rows;
    $logger->log( ( ( $rows > 0 ) ? $INFO : $DEBUG ),
        "deleted $rows entries from locationlog during locationlog cleanup" );
    return (0);
}

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
