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
use pf::dal;
use pf::dal::ip6log;
use pf::dal::ip6log_archive;
use pf::dal::ip6log_history;
use pf::error qw(is_error is_success);
use pf::log;
use pf::node qw(node_add_simple node_exist);
use pf::util;
use pf::util::IP;

use constant IP6LOG                         => 'ip6log';
use constant IP6LOG_DEFAULT_HISTORY_LIMIT   => '25';
use constant IP6LOG_DEFAULT_ARCHIVE_LIMIT   => '18446744073709551615'; # Yeah, that seems odd, but that's the MySQL documented way to use LIMIT with "unlimited"
use constant IP6LOG_FLOORED_LEASE_LENGTH    => '120';  # In seconds. Default to 2 minutes

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

    return _history_by({ mac => $search_by} , %params) if ( pf::util::valid_mac($search_by) );

    return _history_by({ip => $search_by}, %params) if ( pf::util::IP::is_ipv6($search_by) );
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

=head2 _history_by

Get the full ip6log for a given search.

Not meant to be used outside of this class. Refer to L<pf::ip6log::get_history> or L<pf::ip6log::get_archive>

=cut

sub _history_by {
    my ( $where, %params ) = @_;
    my $logger = pf::log::get_logger;
    my $start_time;
    my $end_time;
    my $limit = $params{'limit'};
    my @columns = qw(mac ip type start_time end_time unix_timestamp(start_time)|start_timestamp unix_timestamp(end_time)|end_timestamp);

    my %select_args = (
            -from => 'ip6log',
            -columns => \@columns,
            -where => $where,
            -union_all => [
                -from => 'ip6log_history',
                -columns => \@columns,
                -where => $where,
            ],
            -order_by => { -desc => 'start_time'},
            -limit => $limit,
    );

    if ( defined($params{'start_time'}) && defined($params{'end_time'}) ) {
        $start_time = $params{'start_time'};
        $end_time = $params{'end_time'};
    }

    elsif ( defined($params{'date'}) ) {
        $start_time = $params{'date'};
        $end_time = $params{'date'};
    }

    if ($start_time && $end_time) {
        $where->{start_time} = {"<" => \['from_unixtime(?)', $end_time]};
        $where->{end_time} = [{">" => \['from_unixtime(?)', $start_time]}, $ZERO_DATE];
    }
    if ( $params{'with_archive'} ) {
        push @{$select_args{-union_all}}, -union_all => [
            -from => 'ip6log_archive',
            -columns => \@columns,
            -where => $where,
        ];
    }
    return _db_list(\%select_args);
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

    my ($status, $iter) = pf::dal::ip6log->search(
        -where => {
            ip => $ip,
            -or => [
                end_time => $ZERO_DATE,
                \'(end_time + INTERVAL 30 SECOND) > NOW()'
            ],
        },
        -order_by => {-desc => 'start_time'},
        -limit => 1,
        -columns => [qw(mac ip type start_time end_time)],
    );

    if (is_error($status)) {
        return (0);
    }
    my $ref = $iter->next(undef);

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

    my ($status, $iter) = pf::dal::ip6log->search(
        -where => {
            mac => $mac,
            -or => [
                end_time => $ZERO_DATE,
                \'(end_time + INTERVAL 30 SECOND) > NOW()'
            ],
        },
        -order_by => { -desc => 'start_time' },
        -limit => 1,
        -columns => [qw(mac ip type start_time end_time)],
    );

    if (is_error($status)) {
        return (0);
    }
    my $ref = $iter->next(undef);
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
    return _db_list(
        {
            -where => {
                end_time => [$ZERO_DATE, {">" => \'NOW()'}],
            },
            -columns => [qw(mac ip type start_time end_time)],
        }
    ) if !defined($search_by);;
}

sub _db_list {
    my ($args) = @_;
    my ($status, $iter) = pf::dal::ip6log->search(%$args);

    if (is_error($status)) {
        return;
    }
    return @{$iter->all(undef) // []};
}

=head2 _list_open_by_ip

List all the current open 'ip6log' SQL table entries for a given IP address

Not meant to be used outside of this class. Refer to L<pf::ip6log::list_open>

=cut

sub _list_open_by_ip {
    my ( $ip ) = @_;
    my $logger = pf::log::get_logger;

    $logger->debug("Listing all currently open 'ip6log' table entries for the following IP address '$ip'");
    return _db_list(
        {
            -where => {
                ip => $ip,
                -or => [
                    end_time => $ZERO_DATE,
                    \'end_time > NOW()'
                ],
            },
            -order_by => { -desc => 'start_time' },
            -columns => [qw(mac ip type start_time end_time)],
        }
    );
}

=head2 _list_open_by_mac

List all the current open 'ip6log' SQL table entries for a given MAC address

Not meant to be used outside of this class. Refer to L<pf::ip6log::list_open>

=cut

sub _list_open_by_mac {
    my ( $mac ) = @_;
    my $logger = pf::log::get_logger;

    $logger->debug("Listing all currently open 'ip6log' table entries for the following MAC address '$mac'");

    return _db_list(
        {
            -where => {
                mac => $mac,
                -or => [
                    end_time => $ZERO_DATE,
                    \'end_time > NOW()'
                ],
            },
            -order_by => { -desc => 'start_time' },
            -columns => [qw(mac ip type start_time end_time)],
        }
    );
}

=head2 _exists

Check if there is an existing 'ip6log' table entry for the IP address.

Not meant to be used outside of this class.

=cut

sub _exists {
    my ( $ip ) = @_;
    return (is_success(pf::dal::ip6log->exists({ip => $ip})));
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

    # Floor lease time to a "minimum" value to avoid some devices bad behaviors with DHCP standards
    # ie. Do not set an end_time too low for an ip6log record
    if ( $lease_length && ($lease_length < IP6LOG_FLOORED_LEASE_LENGTH) ) {
        $logger->debug("Lease length '$lease_length' is below the minimal lease length '" . IP6LOG_FLOORED_LEASE_LENGTH . "'. Flooring it.");
        $lease_length = IP6LOG_FLOORED_LEASE_LENGTH;
    }

    unless ( pf::util::IP::is_ipv6($ip) ) {
        $logger->warn("Trying to open an 'ip6log' table entry with an invalid IP address '" . ($ip // "undef") . "'");
        return;
    }

    unless ( pf::util::valid_mac($mac) ) {
        $logger->warn("Trying to open an 'ip6log' table entry with an invalid MAC address '" . ($mac // "undef") . "'");
        return;
    }
    my %args = (
        mac => $mac,
        ip => $ip,
        type => $type,
        start_time => \"NOW()",
        end_time => $ZERO_DATE,
    );

    if ($lease_length) {
        $args{end_time} = \['DATE_ADD(NOW(), INTERVAL ? SECOND)', $lease_length],
    }
    my $item = pf::dal::ip6log->new(\%args);
    #does an upsert of the ip4log
    my $status = $item->save();

    return if is_error($status);
    if ($STATUS::CREATED == $status) {
        $logger->debug("No 'ip6log' table entry found for that IP ($ip). Creating a new one");
    } else {
        $logger->debug("An 'ip6log' table entry already exists for that IP ($ip). Proceed with updating it");
    }
    return (1);
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

    my ($status, $rows) = pf::dal::ip6log->update_items(
        -set => {
            end_time => \'NOW()',
        },
        -where => {
            ip => $ip,
        }
    );

    return ($rows);
}


=head2 rotate

Rotate ip6log_history table old entries to ip6log_archive table

=cut

sub rotate {
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.2});
    my ( $window_seconds, $batch, $time_limit ) = @_;
    my $logger = pf::log::get_logger();
    $logger->debug("Calling rotate with window='$window_seconds' seconds, batch='$batch', timelimit='$time_limit'");
    my $now = pf::dal->now();
    my $start_time = time;
    my $end_time;
    my $rows_rotated = 0;
    my $where = {
        end_time => {
            "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $window_seconds ]
        },
    };

    my ( $subsql, @bind ) = pf::dal::ip6log_history->select(
        -columns => [qw(mac ip type start_time end_time)],
        -where => $where,
        -limit => $batch,
        -from => pf::dal::ip6log_history->table,
    );

    my %rotate_search = (
        -where => $where,    
        -limit => $batch,
    );

    my $sql = "INSERT INTO ip6log_archive (mac, ip, type, start_time, end_time) $subsql;";

    while (1) {
        my $query;
        my ( $rows_inserted, $rows_deleted );
        pf::db::db_transaction_execute( sub{
            my ($status, $sth) = pf::dal::ip6log_archive->db_execute($sql, @bind);
            $rows_inserted = $sth->rows;
            $sth->finish;
            if ($rows_inserted > 0 ) {
                my ($status, $rows) = pf::dal::ip6log_history->remove_items(%rotate_search);
                $rows_deleted = $rows // 0;
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

=head2 cleanup_archive

Cleanup the ip6log_archive table

=cut

sub cleanup_archive {
    my ( $window_seconds, $batch, $time_limit ) = @_;
    return _cleanup($window_seconds, $batch, $time_limit, "pf::dal::ip6log_archive");
}

=head2 cleanup_history

Cleanup the ip6log_history table

=cut

sub cleanup_history {
    my ( $window_seconds, $batch, $time_limit ) = @_;
    return _cleanup($window_seconds, $batch, $time_limit, "pf::dal::ip6log_history");
}


=head2 _cleanup

The generic cleanup for ip6log tables

=cut

sub _cleanup {
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.2});
    my ( $window_seconds, $batch, $time_limit, $dal ) = @_;
    my $logger = pf::log::get_logger();
    $logger->debug("Calling cleanup with for $dal window='$window_seconds' seconds, batch='$batch', timelimit='$time_limit'");
    if ( $window_seconds eq "0" ) {
        $logger->debug("Not deleting because the window is 0");
        return;
    }

    my $now = pf::dal->now();

    my ($status, $rows) = $dal->batch_remove(
        {
            -where => {
                end_time => {
                    "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $window_seconds ]
                }
            },
            -limit => $batch,
        },
        $time_limit
    );
    return ($rows);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
