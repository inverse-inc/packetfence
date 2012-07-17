package pfappserver::Model::Node;

=head1 NAME

pfappserver::Model::Node - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;
use Readonly;

use pf::config;
use pf::db;
use pf::error qw(is_error is_success);
use pf::nodecategory;
use pf::scan qw($SCAN_VID);
use pf::util;
use pf::violation;

use constant NODE => 'node';

extends 'Catalyst::Model';

# Node status constants
# FIXME port all hard-coded strings to these constants
Readonly::Scalar our $STATUS_REGISTERED => 'reg';
Readonly::Scalar our $STATUS_UNREGISTERED => 'unreg';
Readonly::Scalar our $STATUS_PENDING => 'pending';
Readonly::Scalar our $STATUS_GRACE => 'grace';

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $node_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $node_statements = {};

=head1 METHODS

=over

=head2 _node_db_prepare

From pf::node::node_db_prepare

=cut
sub _node_db_prepare {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->debug("Preparing ".__PACKAGE__." database queries");

    $node_statements->{'node_exist_sql'} = get_db_handle()->prepare(qq[ select mac from node where mac=? ]);

    $node_statements->{'node_pid_sql'} = get_db_handle()->prepare( qq[ select count(*) from node where status='reg' and pid=? ]);

    $node_statements->{'node_add_sql'} = get_db_handle()->prepare(qq[
        INSERT INTO node (
            mac, pid, category_id, status, voip, bypass_vlan,
            detect_date, regdate, unregdate, lastskip, 
            user_agent, computername, dhcp_fingerprint,
            last_arp, last_dhcp,
            notes
        ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
    ]);

    $node_statements->{'node_delete_sql'} = get_db_handle()->prepare(qq[ delete from node where mac=? ]);

    $node_statements->{'node_modify_sql'} = get_db_handle()->prepare(qq[
        UPDATE node SET 
            mac=?, pid=?, category_id=?, status=?, voip=?, bypass_vlan=?,
            detect_date=?, regdate=?, unregdate=?, lastskip=?, 
            user_agent=?, computername=?, dhcp_fingerprint=?, 
            last_arp=?, last_dhcp=?,
            notes=?
        WHERE mac=?
    ]);
 
    $node_statements->{'node_attributes_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, pid, voip, status, bypass_vlan, 
            IF(ISNULL(node_category.name), '', node_category.name) as category, 
            detect_date, regdate, unregdate, lastskip, 
            user_agent, computername, dhcp_fingerprint, 
            last_arp, last_dhcp,
            node.notes
        FROM node
            LEFT JOIN node_category USING (category_id)
        WHERE mac = ?
    ]);

    # DEPRECATED see _node_view_old()
    $node_statements->{'node_view_old_sql'} = get_db_handle()->prepare(qq[
        SELECT node.mac, node.pid, node.voip, node.bypass_vlan, node.status,
            IF(ISNULL(node_category.name), '', node_category.name) as category,
            node.detect_date, node.regdate, node.unregdate, node.lastskip,
            node.user_agent, node.computername, node.dhcp_fingerprint,
            node.last_arp, node.last_dhcp, 
            locationlog.switch as last_switch, locationlog.port as last_port, locationlog.vlan as last_vlan,
            IF(ISNULL(locationlog.connection_type), '', locationlog.connection_type) as last_connection_type,
            locationlog.dot1x_username as last_dot1x_username, locationlog.ssid as last_ssid,
            COUNT(DISTINCT violation.id) as nbopenviolations,
            node.notes
        FROM node
            LEFT JOIN node_category USING (category_id)
            LEFT JOIN violation ON node.mac=violation.mac AND violation.status = 'open'
            LEFT JOIN locationlog ON node.mac=locationlog.mac AND end_time IS NULL
        GROUP BY node.mac
        HAVING node.mac=?
    ]);

    $node_statements->{'node_view_sql'} = get_db_handle()->prepare(<<'    SQL');
        SELECT node.mac, node.pid, node.voip, node.bypass_vlan, node.status,
            IF(ISNULL(node_category.name), '', node_category.name) as category,
            node.detect_date, node.regdate, node.unregdate, node.lastskip,
            node.user_agent, node.computername, node.dhcp_fingerprint,
            node.last_arp, node.last_dhcp,
            node.notes
        FROM node
            LEFT JOIN node_category USING (category_id)
        WHERE node.mac=?
    SQL

    $node_statements->{'node_last_locationlog_sql'} = get_db_handle()->prepare(<<'    SQL');
       SELECT 
           locationlog.switch as last_switch, locationlog.port as last_port, locationlog.vlan as last_vlan,
           IF(ISNULL(locationlog.connection_type), '', locationlog.connection_type) as last_connection_type,
           locationlog.dot1x_username as last_dot1x_username, locationlog.ssid as last_ssid
       FROM locationlog 
       WHERE mac = ? AND end_time IS NULL
    SQL

    $node_statements->{'node_view_with_fingerprint_sql'} = get_db_handle()->prepare(qq[
        SELECT node.mac, node.pid, node.voip, node.bypass_vlan, node.status, 
            IF(ISNULL(node_category.name), '', node_category.name) as category,
            node.detect_date, node.regdate, node.unregdate, node.lastskip, 
            node.user_agent, node.computername, IFNULL(os_class.description, ' ') as dhcp_fingerprint, 
            node.last_arp, node.last_dhcp, 
            locationlog.switch as last_switch, locationlog.port as last_port, locationlog.vlan as last_vlan,
            IF(ISNULL(locationlog.connection_type), '', locationlog.connection_type) as last_connection_type,
            locationlog.dot1x_username as last_dot1x_username, locationlog.ssid as last_ssid,
            COUNT(DISTINCT violation.id) as nbopenviolations,
            node.notes
        FROM node 
            LEFT JOIN node_category USING (category_id) 
            LEFT JOIN dhcp_fingerprint ON node.dhcp_fingerprint=dhcp_fingerprint.fingerprint 
            LEFT JOIN os_mapping ON dhcp_fingerprint.os_id=os_mapping.os_type 
            LEFT JOIN os_class ON os_mapping.os_class=os_class.class_id 
            LEFT JOIN violation ON node.mac=violation.mac AND violation.status = 'open'
            LEFT JOIN locationlog ON node.mac=locationlog.mac AND end_time IS NULL
        GROUP BY node.mac
        HAVING node.mac=?
    ]);

    # This guy here is not in a prepared statement yet, have a look in node_view_all to see why
    $node_statements->{'node_view_all_sql'} = qq[
        SELECT node.mac, node.pid, node.voip, node.bypass_vlan, node.status,
            IF(ISNULL(node_category.name), '', node_category.name) as category,
            node.detect_date, node.regdate, node.unregdate, node.lastskip,
            node.user_agent, node.computername, node.dhcp_fingerprint,
            node.last_arp, node.last_dhcp,
            locationlog.switch as last_switch, locationlog.port as last_port, locationlog.vlan as last_vlan,
            IF(ISNULL(locationlog.connection_type), '', locationlog.connection_type) as last_connection_type,
            locationlog.dot1x_username as last_dot1x_username, locationlog.ssid as last_ssid,
            COUNT(DISTINCT violation.id) as nbopenviolations,
            node.notes
        FROM node
            LEFT JOIN node_category USING (category_id)
            LEFT JOIN violation ON node.mac=violation.mac AND violation.status = 'open'
            LEFT JOIN locationlog ON node.mac=locationlog.mac AND end_time IS NULL
        GROUP BY node.mac
    ];

    # This guy here is special, have a look in node_count_all to see why
    $node_statements->{'node_count_all_sql'} = "select count(*) as nb from node";

    $node_statements->{'node_ungrace_sql'} = get_db_handle()->prepare(
        qq [ select mac from node where status="grace" and unix_timestamp(now())-unix_timestamp(lastskip) > ]
            . $Config{'registration'}{'skip_reminder'});

    $node_statements->{'node_expire_unreg_field_sql'} = get_db_handle()->prepare(
        qq [ select mac from node where status="reg" and unregdate != 0 and unregdate < now() ]);

    $node_statements->{'node_expire_window_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac FROM node WHERE status="reg" AND unix_timestamp(regdate) + ? < unix_timestamp(now()) ]
    );

    $node_statements->{'node_expire_deadline_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac FROM node WHERE status="reg" AND unix_timestamp(regdate) <  ? ]
    );

    $node_statements->{'node_expire_session_sql'} = get_db_handle()->prepare(qq[
        UPDATE node n SET n.status="unreg" 
        WHERE n.status="reg" 
            AND n.mac NOT IN (SELECT i.mac FROM iplog i WHERE (i.end_time=0 OR i.end_time > now()))
            AND n.mac NOT IN (
                SELECT i.mac FROM iplog i WHERE end_time!=0 AND unix_timestamp(now()) - unix_timestamp(i.end_time) < ?
            )
    ]);

    $node_statements->{'node_expire_lastarp_sql'} = get_db_handle()->prepare(
        qq [ select mac from node where unix_timestamp(last_arp) < (unix_timestamp(now()) - ?) and last_arp!=0 ]);

    $node_statements->{'node_unregistered_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, pid, voip, bypass_vlan, status,
            detect_date, regdate, unregdate, lastskip, 
            user_agent, computername, dhcp_fingerprint, 
            last_arp, last_dhcp,
            notes
        FROM node
        WHERE status = "$STATUS_UNREGISTERED" AND mac = ?
    ]);

    $node_statements->{'nodes_unregistered_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, pid, voip, bypass_vlan, status,
            detect_date, regdate, unregdate, lastskip, 
            user_agent, computername, dhcp_fingerprint, 
            last_arp, last_dhcp,
            notes
        FROM node
        WHERE status = "$STATUS_UNREGISTERED"
    ]);

    $node_statements->{'nodes_registered_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, pid, voip, bypass_vlan, status,
            detect_date, regdate, unregdate, lastskip, 
            user_agent, computername, dhcp_fingerprint, 
            last_arp, last_dhcp,
            notes
        FROM node
        WHERE status = "$STATUS_REGISTERED"
    ]);

    $node_statements->{'nodes_registered_not_violators_sql'} = get_db_handle()->prepare(qq[
        SELECT node.mac FROM node 
            LEFT JOIN violation ON node.mac=violation.mac AND violation.status='open' 
        WHERE node.status='reg' GROUP BY node.mac HAVING count(violation.mac)=0
    ]);

    $node_statements->{'nodes_active_unregistered_sql'} = get_db_handle()->prepare(
        qq [ select n.mac,n.pid,n.detect_date,n.regdate,n.unregdate,n.lastskip,n.status,n.user_agent,n.computername,n.notes,i.ip,i.start_time,i.end_time,n.last_arp from node n left join iplog i on n.mac=i.mac where n.status="unreg" and (i.end_time=0 or i.end_time > now()) ]);

    $node_statements->{'nodes_active_sql'} = get_db_handle()->prepare(
        qq [ select n.mac,n.pid,n.detect_date,n.regdate,n.unregdate,n.lastskip,n.status,n.user_agent,n.computername,n.notes,n.dhcp_fingerprint,i.ip,i.start_time,i.end_time,n.last_arp from node n, iplog i where n.mac=i.mac and (i.end_time=0 or i.end_time > now()) ]);

    $node_statements->{'node_update_lastarp_sql'} = get_db_handle()->prepare(qq [ update node set last_arp=now() where mac=? ]);

    $node_db_prepared = 1;
    return 1;
}

=head2 countAll

From pf::node::node_count_all

=cut
sub countAll {
    my ( $self, %params ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg);

    # Hack! we prepare the statement here so that $node_count_all_sql is pre-filled
    if (!$node_db_prepared) {
        eval { _node_db_prepare() };
        if ($@) {
            $status_msg = "Can't prepare database statements. Is the database accessible?";
            $logger->error($status_msg);
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
    }
    my $node_count_all_sql = $node_statements->{'node_count_all_sql'};

    if ( defined( $params{'where'} ) ) {
        if ( $params{'where'}{'type'} eq 'pid' ) {
            $node_count_all_sql
                .= " WHERE node.pid='" . $params{'where'}{'value'} . "'";
        } elsif ( $params{'where'}{'type'} eq 'category' ) {

            my $cat_id = nodecategory_lookup($params{'where'}{'value'});
            if (!defined($cat_id)) {
                # lets be nice and issue a warning if the category doesn't exist
                $logger->warn("there was a problem looking up category ".$params{'where'}{'value'});
                # put cat_id to 0 so it'll return 0 results (achieving the count ok)
                $cat_id = 0;
            }
            $node_count_all_sql .= " WHERE category_id =" . $cat_id;
        }
    }

    # Hack! Because of the nature of the query built here (we cannot prepare it), we construct it as a string
    # and pf::db will recognize it and prepare it as such
    $node_statements->{'node_count_all_sql_custom'} = $node_count_all_sql;
    my $count;
    eval {
        my @result = db_data(NODE, $node_statements, 'node_count_all_sql_custom');
        $count = pop @result;
    };
    if ($@) {
        $status_msg = "Can't count nodes from database.";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, $count->{nb});
}

=head2 search

From pf::node::node_view_all()

=cut
sub search {
    my ( $self, %params ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg);

    # Hack! we prepare the statement here so that $node_view_all_sql is pre-filled
    if (!$node_db_prepared) {
        eval { _node_db_prepare() };
        if ($@) {
            $status_msg = "Can't prepare database statements. Is the database accessible?";
            $logger->error($status_msg);
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
    }
    my $node_view_all_sql = $node_statements->{'node_view_all_sql'};

    if ( defined( $params{'where'} ) ) {
        if ( $params{'where'}{'type'} eq 'pid' ) {
            $node_view_all_sql
                .= " HAVING node.pid='" . $params{'where'}{'value'} . "'";

        } elsif ( $params{'where'}{'type'} eq 'category' ) {

            if (!nodecategory_lookup($params{'where'}{'value'})) {
                # lets be nice and issue a warning if the category doesn't exist
                $logger->warn("there was a problem looking up category ".$params{'where'}{'value'});
            }
            $node_view_all_sql .= " HAVING category='" . $params{'where'}{'value'} . "'";

        }
    }
    if ( defined( $params{'orderby'} ) ) {
        $node_view_all_sql .= " " . $params{'orderby'};
    }
    if ( defined( $params{'limit'} ) ) {
        $node_view_all_sql .= " " . $params{'limit'};
    }

    # Hack! Because of the nature of the query built here (we cannot prepare it), we construct it as a string
    # and pf::db will recognize it and prepare it as such
    $node_statements->{'node_view_all_sql_custom'} = $node_view_all_sql;

    require pf::pfcmd::report;
    import pf::pfcmd::report;

    # Catch errors?
    my @nodes;
    eval {
        @nodes = translate_connection_type(db_data(NODE, $node_statements, 'node_view_all_sql_custom'));
    };
    if ($@) {
        $status_msg = "Can't fetch nodes from database.";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, \@nodes);
}

=back

=head1 AUTHOR

Francis Lachapelle <flachapelle@inverse.ca>

=head1 COPYRIGHT

Copyright 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
