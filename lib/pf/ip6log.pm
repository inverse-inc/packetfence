package pf::ip6log;

=head1 NAME

pf::ip6log

=cut

=head1 DESCRIPTION

Class to manage IPv6 address <-> MAC address bindings

=cut

use strict;
use warnings;

# External libs
use Date::Parse;

# Internal libs
use pf::CHI;
use pf::config qw(
    $management_network
    %Config
);
use pf::constants;
use pf::db;
use pf::log;
use pf::node qw(node_add_simple node_exist);
use pf::util;
use pf::util::IP;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        ip6log_db_prepare
        $ip6log_db_prepared
    );
}


use constant IP6LOG                         => 'ip6log';
use constant IP6LOG_DEFAULT_HISTORY_LIMIT   => '25';
use constant IP6LOG_DEFAULT_ARCHIVE_LIMIT   => '18446744073709551615'; # Yeah, that seems odd, but that's the MySQL documented way to use LIMIT with "unlimited"


# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $ip6log_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $ip6log_statements = {};

sub ip6log_db_prepare {
    my $logger = pf::log::get_logger();
    $logger->debug("Preparing pf::ip6log database queries");

    # We could have used the ip6log_list_open_by_ip_sql statement but for performances, we enforce the LIMIT 1
    # We add a 30 seconds grace time for devices that don't actually respect lease times 
    $ip6log_statements->{'ip6log_view_by_ip_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac, ip, type, start_time, end_time FROM ip6log WHERE ip = ? AND (end_time = 0 OR ( end_time + INTERVAL 30 SECOND ) > NOW()) ORDER BY start_time DESC LIMIT 1 ]
    );

    # We could have used the ip6log_list_open_by_mac_sql statement but for performances, we enforce the LIMIT 1
    # We add a 30 seconds grace time for devices that don't actually respect lease times 
    $ip6log_statements->{'ip6log_view_by_mac_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac, ip, type, start_time, end_time FROM ip6log WHERE mac = ? AND (end_time = 0 OR ( end_time + INTERVAL 30 SECOND ) > NOW()) ORDER BY start_time DESC LIMIT 1 ]
    );

    $ip6log_statements->{'ip6log_list_open_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac, ip, type, start_time, end_time FROM ip6log WHERE end_time=0 OR end_time > NOW() ]
    );

    $ip6log_statements->{'ip6log_list_open_by_ip_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac, ip, type, start_time, end_time FROM ip6log WHERE ip = ? AND (end_time = 0 OR end_time > NOW()) ORDER BY start_time DESC ]
    );

    $ip6log_statements->{'ip6log_list_open_by_mac_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac, ip, type, start_time, end_time FROM ip6log WHERE mac = ? AND (end_time = 0 OR end_time > NOW()) ORDER BY start_time DESC ]
    );

    # Using WHERE clause and ORDER BY clause in subqueries to fasten resultset
    # Using UNION ALL rather than UNION to avoid the cost of 'SELECT DISTINCT'
    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $ip6log_statements->{'ip6log_get_history_by_ip_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM
                (SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM ip6log
                WHERE ip = ?
                ORDER BY start_time DESC) AS a
             UNION ALL
             SELECT * FROM
                (SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM ip6log_history
                WHERE ip = ?
                ORDER BY start_time DESC) AS b
             ORDER BY start_time DESC LIMIT ? ]
    );

    # Using WHERE clause and ORDER BY clause in subqueries to fasten resultset
    # Using UNION ALL rather than UNION to avoid the cost of 'SELECT DISTINCT'
    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $ip6log_statements->{'ip6log_get_history_by_ip_with_date_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM
                (SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM ip6log
                WHERE ip = ? AND start_time < FROM_UNIXTIME(?) AND (end_time > FROM_UNIXTIME(?) OR end_time = 0)
                ORDER BY start_time DESC) AS a
             UNION ALL
             SELECT * FROM
                (SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM ip6log_history
                WHERE ip = ? AND start_time < FROM_UNIXTIME(?) AND (end_time > FROM_UNIXTIME(?) OR end_time = 0)
                ORDER BY start_time DESC) AS b
             ORDER BY start_time DESC LIMIT ? ]
    );

    # Using WHERE clause and ORDER BY clause in subqueries to fasten resultset
    # Using UNION ALL rather than UNION to avoid the cost of 'SELECT DISTINCT'
    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $ip6log_statements->{'ip6log_get_history_by_mac_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM
                (SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM ip6log
                WHERE mac = ?
                ORDER BY start_time DESC) AS a
             UNION ALL
             SELECT * FROM
                (SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM ip6log_history
                WHERE mac = ?
                ORDER BY start_time DESC) AS b
             ORDER BY start_time DESC LIMIT ? ]
    );

    # Using WHERE clause and ORDER BY clause in subqueries to fasten resultset
    # Using UNION ALL rather than UNION to avoid the cost of 'SELECT DISTINCT'
    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $ip6log_statements->{'ip6log_get_history_by_mac_with_date_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM
                (SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM ip6log
                WHERE mac = ? AND start_time < FROM_UNIXTIME(?) AND (end_time > FROM_UNIXTIME(?) OR end_time = 0)
                ORDER BY start_time DESC) AS a
             UNION ALL
             SELECT * FROM
                (SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM ip6log_history
                WHERE mac = ? AND start_time < FROM_UNIXTIME(?) AND (end_time > FROM_UNIXTIME(?) OR end_time = 0)
                ORDER BY start_time DESC) AS b
             ORDER BY start_time DESC LIMIT ? ]
    );

    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $ip6log_statements->{'ip6log_get_archive_by_ip_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
             FROM ip6log_archive
             WHERE ip = ?
             ORDER BY start_time DESC LIMIT ? ]
    );

    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $ip6log_statements->{'ip6log_get_archive_by_ip_with_date_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
             FROM ip6log_archive
             WHERE ip = ? AND start_time < FROM_UNIXTIME(?) AND (end_time > FROM_UNIXTIME(?) OR end_time = 0)
             ORDER BY start_time DESC LIMIT ? ]
    );

    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $ip6log_statements->{'ip6log_get_archive_by_mac_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
             FROM ip6log_archive
             WHERE mac = ?
             ORDER BY start_time DESC LIMIT ? ]
    );

    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $ip6log_statements->{'ip6log_get_archive_by_mac_with_date_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac, ip, type, start_time, end_time, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
             FROM ip6log_archive
             WHERE mac = ? AND start_time < FROM_UNIXTIME(?) AND (end_time > FROM_UNIXTIME(?) OR end_time = 0)
             ORDER BY start_time DESC LIMIT ? ]
    );

    $ip6log_statements->{'ip6log_exists_sql'} = get_db_handle()->prepare(
        qq [ SELECT 1 FROM ip6log WHERE ip = ? ]
    );

    $ip6log_statements->{'ip6log_insert_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO ip6log (mac, ip, type, start_time) VALUES (?, ?, ?, NOW()) ]
    );

    $ip6log_statements->{'ip6log_insert_with_lease_length_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO ip6log (mac, ip, type, start_time, end_time) VALUES (?, ?, ?, NOW(), DATE_ADD(NOW(), INTERVAL ? SECOND)) ]
    );

    $ip6log_statements->{'ip6log_update_sql'} = get_db_handle()->prepare(
        qq [ UPDATE ip6log SET mac = ?, type = ?, start_time = NOW(), end_time = "0000-00-00 00:00:00" WHERE ip = ? ]
    );

    $ip6log_statements->{'ip6log_update_with_lease_length_sql'} = get_db_handle()->prepare(
        qq [ UPDATE ip6log SET mac = ?, type = ?, start_time = NOW(), end_time = DATE_ADD(NOW(), INTERVAL ? SECOND) WHERE ip = ? ]
    );

    $ip6log_statements->{'ip6log_close_sql'} = get_db_handle()->prepare(
        qq [ UPDATE ip6log SET end_time = NOW() WHERE ip = ? ]
    );

    $ip6log_statements->{'ip6log_rotate_insert_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO ip6log_archive SELECT mac, ip, type, start_time, end_time FROM ip6log_history WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ? ]
    );
    $ip6log_statements->{'ip6log_rotate_delete_sql'} = get_db_handle()->prepare(
        qq [ DELETE FROM ip6log_history WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ? ]
    );

    $ip6log_statements->{'ip6log_history_cleanup_sql'} = get_db_handle()->prepare(
        qq [ DELETE FROM ip6log_history WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ? ]
    );
    $ip6log_statements->{'ip6log_archive_cleanup_sql'} = get_db_handle()->prepare(
        qq [ DELETE FROM ip6log_archive WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ? ]
    );

    $ip6log_db_prepared = 1;
}


=head2 ip2mac

Lookup for the MAC address of a given IP address

Returns '0' if no match

=cut

sub ip2mac {
    my ( $ip ) = @_;
    my $logger = pf::log::get_logger;

    unless ( pf::util::IP::is_ipv6($ip) ) {
        $logger->warn("Trying to match MAC address with an invalid IP address '" . ($ip // "undef") . "'");
        return (0);
    }

    my $mac;

    $logger->debug("Trying to match MAC address to IP '$ip' using SQL 'ip6log' table");
    $mac = _ip2mac_sql($ip);
    $logger->debug("Matched IP '$ip' to MAC address '$mac' using SQL 'ip6log' table") if $mac;

    if ( !$mac ) {
        $logger->warn("Unable to match MAC address to IP '$ip'");
        return (0);
    }

    return pf::util::clean_mac($mac);
}


=head2 _ip2mac_sql

Look for the MAC address of a given IP address using the SQL 'ip6log' table

Not meant to be used outside of this class. Refer to L<pf::ip6log::ip2mac>

=cut

sub _ip2mac_sql {
    my ( $ip ) = @_;
    my $ip6log = _view_by_ip($ip);
    return $ip6log->{'mac'};
}

=head2 mac2ip

Lookup for the IP address of a given MAC address

Returns '0' if no match

=cut

sub mac2ip {
    my ( $mac ) = @_;
    my $logger = pf::log::get_logger;

    unless (pf::util::valid_mac($mac)) {
        $logger->warn("Trying to match IP address with an invalid MAC address '" . ($mac // "undef") . "'");
        return (0);
    }

    my $ip;

    $logger->debug("Trying to match IP address to MAC '$mac' using SQL 'ip6log' table");
    $ip = _mac2ip_sql($mac);
    $logger->debug("Matched MAC '$mac' to IP address '$ip' using SQL 'ip6log' table") if $ip;

    if ( !$ip ) {
        $logger->trace("Unable to match IP address to MAC '$mac'");
        return (0);
    }

    return $ip;
}


=head2 _mac2ip_sql

Look for the IP address of a given MAC address using the SQL 'ip6log' table

Not meant to be used outside of this class. Refer to L<pf::ip6log::mac2ip>

=cut

sub _mac2ip_sql {
    my ( $mac ) = @_;
    my $ip6log = _view_by_mac($mac);
    return $ip6log->{'ip'};
}

=head2 get_history

Get the full ip6log history for a given IP address or MAC address.

=cut

sub get_history {
    my ( $search_by, %params ) = @_;
    my $logger = pf::log::get_logger;

    $params{'limit'} = defined $params{'limit'} ? $params{'limit'} : IP6LOG_DEFAULT_HISTORY_LIMIT;

    return _history_by_mac($search_by, %params) if ( pf::util::valid_mac($search_by) );

    return _history_by_ip($search_by, %params) if ( pf::util::IP::is_ipv6($search_by) );
}

=head2 get_archive

Get the full ip6log archive along with the history for a given IP address or MAC address.

=cut

sub get_archive {
    my ( $search_by, %params ) = @_;
    my $logger = pf::log::get_logger;

    $params{'with_archive'} = $TRUE;
    $params{'limit'} = defined $params{'limit'} ? $params{'limit'} : IP6LOG_DEFAULT_ARCHIVE_LIMIT;

    return get_history( $search_by, %params );
}

=head2 _history_by_ip

Get the full ip6log for a given IP address.

Not meant to be used outside of this class. Refer to L<pf::ip6log::get_history> or L<pf::ip6log::get_archive>

=cut

sub _history_by_ip {
    my ( $ip, %params ) = @_;
    my $logger = pf::log::get_logger;

    my @history = ();

    if ( defined($params{'start_time'}) && defined($params{'end_time'}) ) {
        # We are passing the arguments twice to match the prepare statement of the query
        @history = db_data(IP6LOG, $ip6log_statements, 'ip6log_get_history_by_ip_with_date_sql',
            $ip, $params{'end_time'}, $params{'start_time'}, $ip, $params{'end_time'}, $params{'start_time'}, $params{'limit'}
        );
        # Handling archive
        if ( $params{'with_archive'} ) {
            my $number_of_results = @history;
            my $limit = $params{'limit'} - $number_of_results;
            push ( @history,
                db_data(IP6LOG, $ip6log_statements, 'ip6log_get_archive_by_ip_with_date_sql',
                $ip, $params{'end_time'}, $params{'start_time'}, $limit)
            ) if $limit > 0;
        }
    }

    elsif ( defined($params{'date'}) ) {
        # We are passing the arguments twice to match the prepare statement of the query
        @history = db_data(IP6LOG, $ip6log_statements, 'ip6log_get_history_by_ip_with_date_sql',
            $ip, $params{'date'}, $params{'date'}, $ip, $params{'date'}, $params{'date'}, $params{'limit'}
        );
        # Handling archive
        if ( $params{'with_archive'} ) {
            my $number_of_results = @history;
            my $limit = $params{'limit'} - $number_of_results;
            push ( @history,
                db_data(IP6LOG, $ip6log_statements, 'ip6log_get_archive_by_ip_with_date_sql',
                $ip, $params{'date'}, $params{'date'}, $limit)
            ) if $limit > 0;
        }
    }

    else {
        # We are passing the arguments twice to match the prepare statement of the query
        @history = db_data(IP6LOG, $ip6log_statements, 'ip6log_get_history_by_ip_sql', $ip, $ip, $params{'limit'});
        # Handling archive
        if ( $params{'with_archive'} ) {
            my $number_of_results = @history;
            my $limit = $params{'limit'} - $number_of_results;
            push ( @history,
                db_data(IP6LOG, $ip6log_statements, 'ip6log_get_archive_by_ip_sql', $ip, $limit)
            ) if $limit > 0;
        }
    }

    return @history;
}

=head2 _history_by_mac

Get the full ip6log for a given MAC address.

Not meant to be used outside of this class. Refer to L<pf::ip6log::get_history> or L<pf::ip6log::get_archive>

=cut

sub _history_by_mac {
    my ( $mac, %params ) = @_;
    my $logger = pf::log::get_logger;

    my @history = ();

    if ( defined($params{'start_time'}) && defined($params{'end_time'}) ) {
        # We are passing the arguments twice to match the prepare statement of the query
        @history = db_data(IP6LOG, $ip6log_statements, 'ip6log_get_history_by_mac_with_date_sql',
            $mac, $params{'end_time'}, $params{'start_time'}, $mac, $params{'end_time'}, $params{'start_time'}, $params{'limit'}
        );
        # Handling archive
        if ( $params{'with_archive'} ) {
            my $number_of_results = @history;
            my $limit = $params{'limit'} - $number_of_results;
            push ( @history,
                db_data(IP6LOG, $ip6log_statements, 'ip6log_get_archive_by_mac_with_date_sql',
                $mac, $params{'end_time'}, $params{'start_time'}, $limit)
            ) if $limit > 0;
        }
    }

    elsif ( defined($params{'date'}) ) {
        # We are passing the arguments twice to match the prepare statement of the query
        @history = db_data(IP6LOG, $ip6log_statements, 'ip6log_get_history_by_mac_with_date_sql',
            $mac, $params{'date'}, $params{'date'}, $mac, $params{'date'}, $params{'date'}, $params{'limit'}
        );
        # Handling archive
        if ( $params{'with_archive'} ) {
            my $number_of_results = @history;
            my $limit = $params{'limit'} - $number_of_results;
            push ( @history,
                db_data(IP6LOG, $ip6log_statements, 'ip6log_get_archive_by_mac_with_date_sql',
                $mac, $params{'date'}, $params{'date'}, $limit)
            ) if $limit > 0;
        }
    }

    else {
        # We are passing the arguments twice to match the prepare statement of the query
        @history = db_data(IP6LOG, $ip6log_statements, 'ip6log_get_history_by_mac_sql', $mac, $mac, $params{'limit'});
        # Handling archive
        if ( $params{'with_archive'} ) {
            my $number_of_results = @history;
            my $limit = $params{'limit'} - $number_of_results;
            push ( @history,
                db_data(IP6LOG, $ip6log_statements, 'ip6log_get_archive_by_mac_sql', $mac, $limit)
            ) if $limit > 0;
        }
    }

    return @history;
}

=head2 view

Consult the 'ip6log' SQL table for a given IP address or MAC address.

Returns a single row for the given parameter.

=cut

sub view {
    my ( $search_by ) = @_;
    my $logger = pf::log::get_logger;

    return _view_by_mac($search_by) if ( defined($search_by) && pf::util::valid_mac($search_by) );

    return _view_by_ip($search_by) if ( defined($search_by) && pf::util::IP::is_ipv6($search_by) );

    # Nothing has been returned due to invalid "search" parameter
    $logger->warn("Trying to view an 'ip6log' table entry without a valid parameter '" . ($search_by // "undef") . "'");
}

=head2 _view_by_ip

Consult the 'ip6log' SQL table for a given IP address.

Not meant to be used outside of this class. Refer to L<pf::ip6log::view>

=cut

sub _view_by_ip {
    my ( $ip ) = @_;
    my $logger = pf::log::get_logger;

    $logger->debug("Viewing an 'ip6log' table entry for the following IP address '$ip'");

    my $query = db_query_execute(IP6LOG, $ip6log_statements, 'ip6log_view_by_ip_sql', $ip) || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();

    return ($ref);
}

=head2 _view_by_mac

Consult the 'ip6log' SQL table for a given MAC address.

Not meant to be used outside of this class. Refer to L<pf::ip6log::view>

=cut

sub _view_by_mac {
    my ( $mac ) = @_;
    my $logger = pf::log::get_logger;

    $logger->debug("Viewing an 'ip6log' table entry for the following MAC address '$mac'");

    my $query = db_query_execute(IP6LOG, $ip6log_statements, 'ip6log_view_by_mac_sql', $mac) || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();

    return ($ref);
}

=head2 list_open

List all the current open 'ip6log' SQL table entries (either for a given IP address, MAC address of both)

=cut

sub list_open {
    my ( $search_by ) = @_;
    my $logger = pf::log::get_logger;

    return _list_open_by_mac($search_by) if ( defined($search_by) && pf::util::valid_mac($search_by) );

    return _list_open_by_ip($search_by) if ( defined($search_by) && pf::util::IP::is_ipv6($search_by) );

    # We are either trying to list all the currently open 'ip6log' table entries or the given parameter was not valid.
    # Either way, we return the complete list
    $logger->debug("Listing all currently open 'ip6log' table entries");
    $logger->debug("For debugging purposes, here's the given parameter if any: '" . ($search_by // "undef") . "'");
    return db_data(IP6LOG, $ip6log_statements, 'ip6log_list_open_sql') if ( !defined($search_by) );
}

=head2 _list_open_by_ip

List all the current open 'ip6log' SQL table entries for a given IP address

Not meant to be used outside of this class. Refer to L<pf::ip6log::list_open>

=cut

sub _list_open_by_ip {
    my ( $ip ) = @_;
    my $logger = pf::log::get_logger;

    $logger->debug("Listing all currently open 'ip6log' table entries for the following IP address '$ip'");

    return db_data(IP6LOG, $ip6log_statements, 'ip6log_list_open_by_ip_sql', $ip);
}

=head2 _list_open_by_mac

List all the current open 'ip6log' SQL table entries for a given MAC address

Not meant to be used outside of this class. Refer to L<pf::ip6log::list_open>

=cut

sub _list_open_by_mac {
    my ( $mac ) = @_;
    my $logger = pf::log::get_logger;

    $logger->debug("Listing all currently open 'ip6log' table entries for the following MAC address '$mac'");

    return db_data(IP6LOG, $ip6log_statements, 'ip6log_list_open_by_mac_sql', $mac);
}

=head2 _exists

Check if there is an existing 'ip6log' table entry for the IP address.

Not meant to be used outside of this class.

=cut

sub _exists {
    my ( $ip ) = @_;
    return db_data(IP6LOG, $ip6log_statements, 'ip6log_exists_sql', $ip);
}

=head2 open

Handle 'ip6log' table "new" entries. Will take care of either adding or updating an entry.

=cut

sub open {
    my ( $ip, $mac, $type, $lease_length ) = @_;
    my $logger = pf::log::get_logger;

    # TODO: Should this really belong here ? Is it part of the responsability of ip6log to check that ?
    if ( !pf::node::node_exist($mac) ) {
        pf::node::node_add_simple($mac);
    }

    unless ( pf::util::IP::is_ipv6($ip) ) {
        $logger->warn("Trying to open an 'ip6log' table entry with an invalid IP address '" . ($ip // "undef") . "'");
        return;
    }

    unless ( pf::util::valid_mac($mac) ) {
        $logger->warn("Trying to open an 'ip6log' table entry with an invalid MAC address '" . ($mac // "undef") . "'");
        return;
    }

    if ( _exists($ip) ) {
        $logger->debug("An 'ip6log' table entry already exists for that IP ($ip). Proceed with updating it");
        _update($ip, $mac, $type, $lease_length);
    } else {
        $logger->debug("No 'ip6log' table entry found for that IP ($ip). Creating a new one");
        _insert($ip, $mac, $type, $lease_length);
    }

    return (0);
}

=head2 _insert

Insert a new 'ip6log' table entry.

Not meant to be used outside of this class. Refer to L<pf::ip6log::open>

=cut

sub _insert {
    my ( $ip, $mac, $type, $lease_length ) = @_;
    my $logger = pf::log::get_logger;

    if ( $lease_length ) {
        $logger->debug("Adding a new 'ip6log' table entry for IP address '$ip' with MAC address '$mac' (Lease length: $lease_length secs)");
        db_query_execute(IP6LOG, $ip6log_statements, 'ip6log_insert_with_lease_length_sql', $mac, $ip, $type, $lease_length);
    } else {
        $logger->debug("Adding a new 'ip6log' table entry for IP address '$ip' with MAC address '$mac' (No lease provided)");
        db_query_execute(IP6LOG, $ip6log_statements, 'ip6log_insert_sql', $mac, $ip, $type);
    }
}

=head2 _update

Update an existing 'ip6log' table entry.

Please note that a trigger (ip6log_insert_in_ip6log_history_before_update_trigger) exists in the database schema to copy the old existing record into the 'ip6log_history' table and adjust the end_time accordingly.

Not meant to be used outside of this class. Refer to L<pf::ip6log::open>

=cut

sub _update {
    my ( $ip, $mac, $type, $lease_length ) = @_;
    my $logger = pf::log::get_logger;

    if ( $lease_length ) {
        $logger->debug("Updating an existing 'ip6log' table entry for IP address '$ip' with MAC address '$mac' (Lease length: $lease_length secs)");
        db_query_execute(IP6LOG, $ip6log_statements, 'ip6log_update_with_lease_length_sql', $mac, $type, $lease_length, $ip);
    } else {
        $logger->debug("Updating an existing 'ip6log' table entry for IP address '$ip' with MAC address '$mac' (No lease provided)");
        db_query_execute(IP6LOG, $ip6log_statements, 'ip6log_update_sql', $mac, $type, $ip);
    }
}

=head2 close

Close (update the end_time as of now) an existing 'ip6log' table entry.

=cut

sub close {
    my ( $ip ) = @_;
    my $logger = pf::log::get_logger;

    unless ( pf::util::IP::is_ipv6($ip) ) {
        $logger->warn("Trying to close an 'ip6log' table entry with an invalid IP address '" . ($ip // "undef") . "'");
        return (0);
    }

    $logger->debug("Closing existing 'ip6log' table entry for IP address '$ip' as of now");
    db_query_execute(IP6LOG, $ip6log_statements, 'ip6log_close_sql', $ip);

    return (0);
}

sub rotate {
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.2});
    my ( $window_seconds, $batch, $time_limit ) = @_;
    my $logger = pf::log::get_logger();

    $logger->debug("Calling rotate with window='$window_seconds' seconds, batch='$batch', timelimit='$time_limit'");
    my $now = pf::db::db_now();
    my $start_time = time;
    my $end_time;
    my $rows_rotated = 0;

    while (1) {
        my $query;
        my ( $rows_inserted, $rows_deleted );
        pf::db::db_transaction_execute( sub{
            $query = db_query_execute(IP6LOG, $ip6log_statements, 'ip6log_rotate_insert_sql', $now, $window_seconds, $batch) || return (0);
            $rows_inserted = $query->rows;
            $query->finish;
            if ($rows_inserted > 0 ) {
                $logger->debug("Inserted '$rows_inserted' entries from ip6log_history to ip6log_archive while rotating");
                $query = db_query_execute(IP6LOG, $ip6log_statements, 'ip6log_rotate_delete_sql', $now, $window_seconds, $batch) || return (0);
                $rows_deleted = $query->rows;
                $query->finish;
                $logger->debug("Deleted '$rows_deleted' entries from ip6log_history while rotating");
            } else {
                $rows_deleted = 0;
            }
        } );
        $end_time = time;
        $logger->info("Inserted '$rows_inserted' entries and deleted '$rows_deleted' entries while rotating ip6log_history") if $rows_inserted != $rows_deleted;
        $rows_rotated += $rows_inserted if $rows_inserted > 0;
        $logger->trace("Rotated '$rows_rotated' entries from ip6log_history to ip6log_archive (start: '$start_time', end: '$end_time')");
        last if $rows_inserted <= 0 || ( ( $end_time - $start_time ) > $time_limit );
    }

    $logger->info("Rotated '$rows_rotated' entries from ip6log_history to ip6log_archive (start: '$start_time', end: '$end_time')");
    return (0);
}

sub cleanup {
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.2});
    my ( $window_seconds, $batch, $time_limit, $table ) = @_;
    my $logger = pf::log::get_logger();
    $logger->debug("Calling cleanup with window='$window_seconds' seconds, batch='$batch', timelimit='$time_limit'");

    if ( $window_seconds eq "0" ) {
        $logger->debug("Not deleting because the window is 0");
        return;
    }

    my $now = pf::db::db_now();
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    $table ||= 'ip6log_archive';

    my $query_name = $table eq 'ip6log_history' ? 'ip6log_history_cleanup_sql' : 'ip6log_archive_cleanup_sql';

    while (1) {
        my $query = db_query_execute(IP6LOG, $ip6log_statements, $query_name, $now, $window_seconds, $batch) || return (0);
        my $rows = $query->rows;
        $query->finish;
        $end_time = time;
        $rows_deleted += $rows if $rows > 0;
        $logger->trace("Deleted '$rows_deleted' entries from $table (start: '$start_time', end: '$end_time')");
        last if $rows <= 0 || ( ( $end_time - $start_time ) > $time_limit );
    }

    $logger->info("Deleted '$rows_deleted' entries from $table (start: '$start_time', end: '$end_time')");
    return (0);
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
