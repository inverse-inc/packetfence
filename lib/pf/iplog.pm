package pf::iplog;

=head1 NAME

pf::iplog - Module to manage IP address <-> MAC address bindings

=cut

=head1 DESCRIPTION

pf::iplog contains the functions necessary to read and manage the DHCP
information gathered by PacketFence on the network.

=cut

use strict;
use warnings;

use Date::Parse;
use pf::log;

use constant IPLOG => 'iplog';
use constant IPLOG_CACHE_EXPIRE => 60;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        iplog_db_prepare
        $iplog_db_prepared

        iplog_history
    );
}

use pf::config;
use pf::db;
use pf::node qw(node_add_simple node_exist);
use pf::util;
use pf::CHI;
use pf::OMAPI;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $iplog_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $iplog_statements = {};

sub iplog_db_prepare {
    my $logger = get_logger();
    $logger->debug("Preparing pf::iplog database queries");

    # We could have used the iplog_list_open_by_ip_sql statement but for performances, we enforce the LIMIT 1
    $iplog_statements->{'iplog_view_by_ip_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM iplog WHERE ip = ? AND (end_time = 0 OR end_time > NOW()) ORDER BY start_time DESC LIMIT 1 ]
    );

    # We could have used the iplog_list_open_by_mac_sql statement but for performances, we enforce the LIMIT 1
    $iplog_statements->{'iplog_view_by_mac_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM iplog WHERE mac = ? AND (end_time = 0 OR end_time > NOW()) ORDER BY start_time DESC LIMIT 1 ]
    );

    $iplog_statements->{'iplog_list_open_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM iplog WHERE end_time=0 OR end_time > NOW() ]
    );

    $iplog_statements->{'iplog_list_open_by_ip_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM iplog WHERE ip = ? AND (end_time = 0 OR end_time > NOW()) ORDER BY start_time DESC ]
    );

    $iplog_statements->{'iplog_list_open_by_mac_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM iplog WHERE mac = ? AND (end_time = 0 OR end_time > NOW()) ORDER BY start_time DESC ]
    );

    # Using WHERE clause and ORDER BY clause in subqueries to fasten resultset
    # Using UNION ALL rather than UNION to avoid the cost of 'SELECT DISTINCT'
    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $iplog_statements->{'iplog_history_by_ip_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM
                (SELECT *, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM iplog
                WHERE ip = ?
                ORDER BY start_time DESC) AS a
             UNION ALL
             SELECT * FROM
                (SELECT *, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM iplog_history
                WHERE ip = ?
                ORDER BY start_time DESC) AS b
             ORDER BY start_time DESC LIMIT 25 ]
    );

    # Using WHERE clause and ORDER BY clause in subqueries to fasten resultset
    # Using UNION ALL rather than UNION to avoid the cost of 'SELECT DISTINCT'
    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $iplog_statements->{'iplog_history_by_ip_with_date_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM
                (SELECT *, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM iplog
                WHERE ip = ? AND start_time < FROM_UNIXTIME(?) AND (end_time > FROM_UNIXTIME(?) OR end_time = 0)
                ORDER BY start_time DESC) AS a
             UNION ALL
             SELECT * FROM
                (SELECT *, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM iplog_history
                WHERE ip = ? AND start_time < FROM_UNIXTIME(?) AND (end_time > FROM_UNIXTIME(?) OR end_time = 0)
                ORDER BY start_time DESC) AS b
             ORDER BY start_time DESC LIMIT 25 ]
    );

    # Using WHERE clause and ORDER BY clause in subqueries to fasten resultset
    # Using UNION ALL rather than UNION to avoid the cost of 'SELECT DISTINCT'
    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $iplog_statements->{'iplog_history_by_mac_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM
                (SELECT *, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM iplog
                WHERE mac = ?
                ORDER BY start_time DESC) AS a
             UNION ALL
             SELECT * FROM
                (SELECT *, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM iplog_history
                WHERE mac = ?
                ORDER BY start_time DESC) AS b
             ORDER BY start_time DESC LIMIT 25 ]
    );

    # Using WHERE clause and ORDER BY clause in subqueries to fasten resultset
    # Using UNION ALL rather than UNION to avoid the cost of 'SELECT DISTINCT'
    # UNIX_TIMESTAMPs are used by graphs for dashboard and reports purposes
    $iplog_statements->{'iplog_history_by_mac_with_date_sql'} = get_db_handle()->prepare(
        qq [ SELECT * FROM
                (SELECT *, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM iplog
                WHERE mac = ? AND start_time < FROM_UNIXTIME(?) AND (end_time > FROM_UNIXTIME(?) OR end_time = 0)
                ORDER BY start_time DESC) AS a
             UNION ALL
             SELECT * FROM
                (SELECT *, UNIX_TIMESTAMP(start_time) AS start_timestamp, UNIX_TIMESTAMP(end_time) AS end_timestamp
                FROM iplog_history
                WHERE mac = ? AND start_time < FROM_UNIXTIME(?) AND (end_time > FROM_UNIXTIME(?) OR end_time = 0)
                ORDER BY start_time DESC) AS b
             ORDER BY start_time DESC LIMIT 25 ]
    );

    $iplog_statements->{'iplog_exists_sql'} = get_db_handle()->prepare(
        qq [ SELECT 1 FROM iplog WHERE ip = ? ]
    );

    $iplog_statements->{'iplog_insert_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO iplog (mac, ip, start_time) VALUES (?, ?, NOW()) ]
    );

    $iplog_statements->{'iplog_insert_with_lease_length_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO iplog (mac, ip, start_time, end_time) VALUES (?, ?, NOW(), DATE_ADD(NOW(), INTERVAL ? SECOND)) ]
    );

    $iplog_statements->{'iplog_update_sql'} = get_db_handle()->prepare(
        qq [ UPDATE iplog SET mac = ?, start_time = NOW(), end_time = "0000-00-00 00:00:00" WHERE ip = ? ]
    );

    $iplog_statements->{'iplog_update_with_lease_length_sql'} = get_db_handle()->prepare(
        qq [ UPDATE iplog SET mac = ?, start_time = NOW(), end_time = DATE_ADD(NOW(), INTERVAL ? SECOND) WHERE ip = ? ]
    );

    $iplog_statements->{'iplog_close_sql'} = get_db_handle()->prepare(
        qq [ UPDATE iplog SET end_time = NOW() WHERE ip = ? ]
    );

    $iplog_statements->{'iplog_cleanup_sql'} = get_db_handle()->prepare(
        qq [ delete from iplog where end_time < DATE_SUB(?, INTERVAL ? SECOND) and end_time != 0 LIMIT ?]);

    $iplog_db_prepared = 1;
}

=head2 omapiCache

Get the OMAPI cache

=cut

sub omapiCache { pf::CHI->new(namespace => 'omapi') }

=head2 ip2mac

Lookup for the MAC address of a given IP address

Returns '0' if no match

=cut

sub ip2mac {
    my ( $ip ) = @_;
    my $logger = pf::log::get_logger;

    unless (valid_ip($ip)) {
        $logger->warn("Trying to match MAC address with an invalid IP address '" . ($ip // "undef") . "'");
        return (0);
    }

    my $mac;

    # TODO: Special case that need to be documented
    if (ref($management_network) && $management_network->{'Tip'} eq $ip) {
        return ( clean_mac("00:11:22:33:44:55") );
    }

    # We first query OMAPI since it is the fastest way and more reliable source of info in most cases
    if ( isenabled($Config{omapi}{ip2mac_lookup}) ) {
        $logger->debug("Trying to match MAC address to IP '$ip' using OMAPI");
        $mac = _ip2mac_omapi($ip);
        $logger->debug("Matched IP '$ip' to MAC address '$mac' using OMAPI") if $mac;
    }

    # If we don't have a result from OMAPI, we use the SQL 'iplog' table
    unless ($mac) {
        $logger->debug("Trying to match MAC address to IP '$ip' using SQL 'iplog' table");
        $mac = _ip2mac_sql($ip);
        $logger->debug("Matched IP '$ip' to MAC address '$mac' using SQL 'iplog' table") if $mac;
    }

    if ( !$mac ) {
        $logger->warn("Unable to match MAC address to IP '$ip'");
        return (0);
    }

    return clean_mac($mac);
}

=head2 _ip2mac_omapi

Look for the MAC address of a given IP address in the DHCP leases using OMAPI

Not meant to be used outside of this class. Refer to L<pf::iplog::ip2mac>

=cut

sub _ip2mac_omapi {
    my ( $ip ) = @_;
    my $data = _lookup_cached_omapi('ip-address' => $ip);
    return $data->{'obj'}{'hardware-address'} if defined $data;
}

=head2 _ip2mac_sql

Look for the MAC address of a given IP address using the SQL 'iplog' table

Not meant to be used outside of this class. Refer to L<pf::iplog::ip2mac>

=cut

sub _ip2mac_sql {
    my ( $ip ) = @_;
    my $iplog = _view_by_ip($ip);
    return $iplog->{'mac'};
}

=head2 mac2ip

Lookup for the IP address of a given MAC address

Returns '0' if no match

=cut

sub mac2ip {
    my ( $mac ) = @_;
    my $logger = pf::log::get_logger;

    unless (valid_mac($mac)) {
        $logger->warn("Trying to match IP address with an invalid MAC address '" . ($mac // "undef") . "'");
        return (0);
    }

    my $ip;

    # We first query OMAPI since it is the fastest way and more reliable source of info in most cases
    if ( isenabled($Config{omapi}{mac2ip_lookup}) ) {
        $logger->debug("Trying to match IP address to MAC '$mac' using OMAPI");
        $ip = _mac2ip_omapi($mac);
        $logger->debug("Matched MAC '$mac' to IP address '$ip' using OMAPI") if $ip;
    }

    # If we don't have a result from OMAPI, we use the SQL 'iplog' table
    unless ($ip) {
        $logger->debug("Trying to match IP address to MAC '$mac' using SQL 'iplog' table");
        $ip = _mac2ip_sql($mac);
        $logger->debug("Matched MAC '$mac' to IP address '$ip' using SQL 'iplog' table") if $ip;
    }

    if ( !$ip ) {
        $logger->trace("Unable to match IP address to MAC '$mac'");
        return (0);
    }

    return $ip;
}

=head2 _mac2ip_omapi

Look for the IP address of a given MAC address in the DHCP leases using OMAPI

Not meant to be used outside of this class. Refer to L<pf::iplog::mac2ip>

=cut

sub _mac2ip_omapi {
    my ( $mac ) = @_;
    my $data = _lookup_cached_omapi('hardware-address' => $mac);
    return $data->{'obj'}{'ip-address'} if defined $data;
}

=head2 _mac2ip_sql

Look for the IP address of a given MAC address using the SQL 'iplog' table

Not meant to be used outside of this class. Refer to L<pf::iplog::mac2ip>

=cut

sub _mac2ip_sql {
    my ( $mac ) = @_;
    my $iplog = _view_by_mac($mac);
    return $iplog->{'ip'};
}

=head2 iplog_history

Get the full iplog for a given IP address or MAC address.

TODO: Rename to 'history' once the "issue" with pfcmd is resolved. Also remove from the export...

=cut

sub iplog_history {
    my ( $search_by, %params ) = @_;
    my $logger = pf::log::get_logger;

    return _history_by_mac($search_by, %params) if ( valid_mac($search_by) );

    return _history_by_ip($search_by, %params) if ( valid_ip($search_by) );
}

=head2 _history_by_ip

Get the full iplog for a given IP address.

Not meant to be used outside of this class. Refer to L<pf::iplog::iplog_history>

=cut

sub _history_by_ip {
    my ( $ip, %params ) = @_;
    my $logger = pf::log::get_logger;

    if ( defined($params{'start_time'}) && defined($params{'end_time'}) ) {
        # We are passing the arguments twice to match the prepare statement of the query
        return db_data(IPLOG, $iplog_statements, 'iplog_history_by_ip_with_date_sql',
            $ip, $params{'end_time'}, $params{'start_time'}, $ip, $params{'end_time'}, $params{'start_time'}
        );
    }

    elsif ( defined($params{'date'}) ) {
        # We are passing the arguments twice to match the prepare statement of the query
        return db_data(IPLOG, $iplog_statements, 'iplog_history_by_ip_with_date_sql',
            $ip, $params{'date'}, $params{'date'}, $ip, $params{'date'}, $params{'date'}
        );
    }

    else {
        # We are passing the arguments twice to match the prepare statement of the query
        return db_data(IPLOG, $iplog_statements, 'iplog_history_by_ip_sql', $ip, $ip);
    }
}

=head2 _history_by_mac

Get the full iplog for a given MAC address.

Not meant to be used outside of this class. Refer to L<pf::iplog::iplog_history>

=cut

sub _history_by_mac {
    my ( $mac, %params ) = @_;
    my $logger = pf::log::get_logger;

    if ( defined($params{'start_time'}) && defined($params{'end_time'}) ) {
        # We are passing the arguments twice to match the prepare statement of the query
        return db_data(IPLOG, $iplog_statements, 'iplog_history_by_mac_with_date_sql',
            $mac, $params{'end_time'}, $params{'start_time'}, $mac, $params{'end_time'}, $params{'start_time'}
        );
    }

    elsif ( defined($params{'date'}) ) {
        # We are passing the arguments twice to match the prepare statement of the query
        return db_data(IPLOG, $iplog_statements, 'iplog_history_by_mac_with_date_sql',
            $mac, $params{'date'}, $params{'date'}, $mac, $params{'date'}, $params{'date'}
        );
    }

    else {
        # We are passing the arguments twice to match the prepare statement of the query
        return db_data(IPLOG, $iplog_statements, 'iplog_history_by_mac_sql', $mac, $mac);
    }
}

=head2 view

Consult the 'iplog' SQL table for a given IP address or MAC address.

Returns a single row for the given parameter.

=cut

sub view {
    my ( $search_by ) = @_;
    my $logger = pf::log::get_logger;

    return _view_by_mac($search_by) if ( defined($search_by) && valid_mac($search_by) );

    return _view_by_ip($search_by) if ( defined($search_by) && valid_ip($search_by) );

    # Nothing has been returned due to invalid "search" parameter
    $logger->warn("Trying to view an 'iplog' table entry without a valid parameter '" . ($search_by // "undef") . "'");
}

=head2 _view_by_ip

Consult the 'iplog' SQL table for a given IP address.

Not meant to be used outside of this class. Refer to L<pf::iplog::view>

=cut

sub _view_by_ip {
    my ( $ip ) = @_;
    my $logger = pf::log::get_logger;

    $logger->debug("Viewing an 'iplog' table entry for the following IP address '$ip'");

    my $query = db_query_execute(IPLOG, $iplog_statements, 'iplog_view_by_ip_sql', $ip) || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();

    return ($ref);
}

=head2 _view_by_mac

Consult the 'iplog' SQL table for a given MAC address.

Not meant to be used outside of this class. Refer to L<pf::iplog::view>

=cut

sub _view_by_mac {
    my ( $mac ) = @_;
    my $logger = pf::log::get_logger;

    $logger->debug("Viewing an 'iplog' table entry for the following MAC address '$mac'");

    my $query = db_query_execute(IPLOG, $iplog_statements, 'iplog_view_by_mac_sql', $mac) || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();

    return ($ref);
}

=head2 list_open

List all the current open 'iplog' SQL table entries (either for a given IP address, MAC address of both)

=cut

sub list_open {
    my ( $search_by ) = @_;
    my $logger = pf::log::get_logger;

    return _list_open_by_mac($search_by) if ( defined($search_by) && valid_mac($search_by) );

    return _list_open_by_ip($search_by) if ( defined($search_by) && valid_ip($search_by) );

    # We are either trying to list all the currently open 'iplog' table entries or the given parameter was not valid.
    # Either way, we return the complete list
    $logger->debug("Listing all currently open 'iplog' table entries");
    $logger->debug("For debugging purposes, here's the given parameter if any: '" . ($search_by // "undef") . "'");
    return db_data(IPLOG, $iplog_statements, 'iplog_list_open_sql') if ( !defined($search_by) );
}

=head2 _list_open_by_ip

List all the current open 'iplog' SQL table entries for a given IP address

Not meant to be used outside of this class. Refer to L<pf::iplog::list_open>

=cut

sub _list_open_by_ip {
    my ( $ip ) = @_;
    my $logger = pf::log::get_logger;

    $logger->debug("Listing all currently open 'iplog' table entries for the following IP address '$ip'");

    return db_data(IPLOG, $iplog_statements, 'iplog_list_open_by_ip_sql', $ip);
}

=head2 _list_open_by_mac

List all the current open 'iplog' SQL table entries for a given MAC address

Not meant to be used outside of this class. Refer to L<pf::iplog::list_open>

=cut

sub _list_open_by_mac {
    my ( $mac ) = @_;
    my $logger = pf::log::get_logger;

    $logger->debug("Listing all currently open 'iplog' table entries for the following MAC address '$mac'");

    return db_data(IPLOG, $iplog_statements, 'iplog_list_open_by_mac_sql', $mac);
}

=head2 _exists

Check if there is an existing 'iplog' table entry for the IP address.

Not meant to be used outside of this class.

=cut

sub _exists {
    my ( $ip ) = @_;
    return db_data(IPLOG, $iplog_statements, 'iplog_exists_sql', $ip);
}

=head2 open

Handle 'iplog' table "new" entries. Will take care of either adding or updating an entry.

=cut

sub open {
    my ( $ip, $mac, $lease_length ) = @_;
    my $logger = pf::log::get_logger;

    # TODO: Should this really belong here ? Is it part of the responsability of iplog to check that ?
    if ( !node_exist($mac) ) {
        node_add_simple($mac);
    }

    unless ( valid_ip($ip) ) {
        $logger->warn("Trying to open an 'iplog' table entry with an invalid IP address '" . ($ip // "undef") . "'");
        return;
    }

    unless ( valid_mac($mac) ) {
        $logger->warn("Trying to open an 'iplog' table entry with an invalid MAC address '" . ($mac // "undef") . "'");
        return;
    }

    if ( _exists($ip) ) {
        $logger->debug("An 'iplog' table entry already exists for that IP ($ip). Proceed with updating it");
        _update($ip, $mac, $lease_length);
    } else {
        $logger->debug("No 'iplog' table entry found for that IP ($ip). Creating a new one");
        _insert($ip, $mac, $lease_length);
    }

    return (0);
}

=head2 _insert

Insert a new 'iplog' table entry.

Not meant to be used outside of this class. Refer to L<pf::iplog::open>

=cut

sub _insert {
    my ( $ip, $mac, $lease_length ) = @_;
    my $logger = pf::log::get_logger;

    if ( $lease_length ) {
        $logger->debug("Adding a new 'iplog' table entry for IP address '$ip' with MAC address '$mac' (Lease length: $lease_length secs)");
        db_query_execute(IPLOG, $iplog_statements, 'iplog_insert_with_lease_length_sql', $mac, $ip, $lease_length);
    } else {
        $logger->debug("Adding a new 'iplog' table entry for IP address '$ip' with MAC address '$mac' (No lease provided)");
        db_query_execute(IPLOG, $iplog_statements, 'iplog_insert_sql', $mac, $ip);
    }
}

=head2 _update

Update an existing 'iplog' table entry.

Please note that a trigger (iplog_insert_in_iplog_history_before_update_trigger) exists in the database schema to copy the old existing record into the 'iplog_history' table and adjust the end_time accordingly.

Not meant to be used outside of this class. Refer to L<pf::iplog::open>

=cut

sub _update {
    my ( $ip, $mac, $lease_length ) = @_;
    my $logger = pf::log::get_logger;

    if ( $lease_length ) {
        $logger->debug("Updating an existing 'iplog' table entry for IP address '$ip' with MAC address '$mac' (Lease length: $lease_length secs)");
        db_query_execute(IPLOG, $iplog_statements, 'iplog_update_with_lease_length_sql', $mac, $lease_length, $ip);
    } else {
        $logger->debug("Updating an existing 'iplog' table entry for IP address '$ip' with MAC address '$mac' (No lease provided)");
        db_query_execute(IPLOG, $iplog_statements, 'iplog_update_sql', $mac, $ip);
    }
}

=head2 close

Close (update the end_time as of now) an existing 'iplog' table entry.

=cut

sub close {
    my ( $ip ) = @_;
    my $logger = pf::log::get_logger;

    unless ( valid_ip($ip) ) {
        $logger->warn("Trying to close an 'iplog' table entry with an invalid IP address '" . ($ip // "undef") . "'");
        return (0);
    }

    $logger->debug("Closing existing 'iplog' table entry for IP address '$ip' as of now");
    db_query_execute(IPLOG, $iplog_statements, 'iplog_close_sql', $ip);

    return (0);
}

sub cleanup {
    my ($expire_seconds, $batch, $time_limit) = @_;
    my $logger = get_logger();
    $logger->debug("calling iplog_cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit");
    my $now = db_now();
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $query = db_query_execute(IPLOG, $iplog_statements, 'iplog_cleanup_sql', $now, $expire_seconds, $batch) || return (0);
        my $rows = $query->rows;
        $query->finish;
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        $logger->trace( sub { "deleted $rows_deleted entries from iplog during iplog cleanup ($start_time $end_time) " });
        last if $rows == 0 || (( $end_time - $start_time) > $time_limit );
    }
    $logger->info( "deleted $rows_deleted entries from iplog during iplog cleanup ($start_time $end_time) ");
    return (0);
}

=head2 _get_omapi_client

Get the omapi client
return undef if omapi is disabled

=cut

sub _get_omapi_client {
    my ($self) = @_;
    return unless pf::config::is_omapi_lookup_enabled;

    return pf::OMAPI->get_client();
}

=head2 _lookup_cached_omapi

Will retrieve the lease from the cache or from the dhcpd server using omapi

=cut

sub _lookup_cached_omapi {
    my ($type, $id) = @_;
    my $cache = omapiCache();
    return $cache->compute(
        $id,
        {expire_if => \&_expire_lease, expires_in => IPLOG_CACHE_EXPIRE},
        sub {
            my $data = _get_lease_from_omapi($type, $id);
            return unless $data && $data->{op} == 3;
            #Do not return if the lease is expired
            return if $data->{obj}->{ends} < time;
            return $data;
        }
    );
}

=head2 _get_lease_from_omapi

Get the lease information using omapi

=cut

sub _get_lease_from_omapi {
    my ($type,$id) = @_;
    my $omapi = _get_omapi_client();
    return unless $omapi;
    my $data;
    eval {
        $data = $omapi->lookup({type => 'lease'}, { $type => $id});
    };
    if($@) {
        get_logger->error("$@");
    }
    return $data;
}

=head2 _expire_lease

Check if the lease has expired

=cut

sub _expire_lease {
    my ($cache_object) = @_;
    my $lease = $cache_object->value;
    return 1 unless defined $lease && defined $lease->{obj}->{ends};
    return $lease->{obj}->{ends} < time;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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
