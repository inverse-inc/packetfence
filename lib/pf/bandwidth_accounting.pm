package pf::bandwidth_accounting;

=head1 NAME

pf::bandwidth_accounting -

=head1 DESCRIPTION

pf::bandwidth_accounting

=cut

use strict;
use warnings;
use Exporter qw(import);
our @EXPORT_OK = qw(bandwidth_maintenance node_has_bandwidth_accounting);
use pf::util qw(make_node_id);
use pf::dal::bandwidth_accounting;
use pf::dal::bandwidth_accounting_history;
use pf::dal::node;
use pf::dal::tenant;
use pf::error qw(is_error is_success);
use pf::log;
use pf::config qw($ACCOUNTING_POLICY_BANDWIDTH %Config);
use pf::constants;
use pf::constants::trigger qw($TRIGGER_TYPE_ACCOUNTING);
use pf::config::security_event;
use pf::security_event qw(security_event_trigger);

my $logger = get_logger();

sub bandwidth_maintenance {
    my (
        $batch, $time_limit, $window,
        $history_batch, $history_timeout, $history_window,
        $session_batch, $session_timeout, $session_window) = @_;
    process_bandwidth_accounting_netflow($batch, $time_limit);
    trigger_bandwidth($batch, $time_limit);
    bandwidth_aggregation('hourly', $batch, $time_limit, 'DATE_SUB(NOW(), INTERVAL ? HOUR)', 2);
    bandwidth_aggregation('daily', $batch, $time_limit, 'DATE_SUB(NOW(), INTERVAL ? DAY)', 2);
    bandwidth_aggregation('monthly', $batch, $time_limit, 'DATE_SUB(NOW(), INTERVAL ? MONTH)', 1);
    bandwidth_accounting_radius_to_history($batch, $time_limit, $window);
    bandwidth_aggregation_history_daily($batch, $time_limit);
    bandwidth_aggregation_history_monthly($batch, $time_limit);
    bandwidth_accounting_history_cleanup($history_window, $history_batch, $history_timeout);
}

sub trigger_bandwidth {
    my ($batch, $time) = @_;
    my ($status, $iter) = pf::dal::tenant->search(
        -with_class => undef,
    );
    if (is_error($status)) {
        return;
    }

    while (my $t = $iter->next) {
        local $pf::config::tenant::CURRENT_TENANT = $t->{id};
        _trigger_bandwidth($batch, $time);
    }
}

sub _trigger_bandwidth {
    my ($batch, $time) = @_;
    if (@BANDWIDTH_EXPIRED_SECURITY_EVENTS > 0) {
        my ($status, $iter) = pf::dal::node->search(
            -where => {
                bandwidth_balance => 0,
                status => 'reg',
            },
            -columns => ['mac'],
            -with_class => undef,
        );
        if (is_success($status)) {
            while (my $row = $iter->next(undef)) {
                security_event_trigger(
                    {
                        'mac'  => $row->{mac},
                        'tid'  => $ACCOUNTING_POLICY_BANDWIDTH,
                        'type' => $TRIGGER_TYPE_ACCOUNTING
                    }
                );
            }
        }
    }
}

sub bandwidth_aggregation {
    my ($rounding, $batch, $time_limit, $date_sql, @date_args) = @_;
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $rows = call_bandwidth_aggregation($rounding, $batch, $date_sql, @date_args);
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        last if $rows <= 0 || (( $end_time - $start_time) > $time_limit );
    }

    $logger->info("aggregated $rows_deleted for bandwidth_aggregation_$rounding ($start_time $end_time) ");
}

sub bandwidth_accounting_radius_to_history {
    my ($batch, $time_limit, $window) = @_;
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $rows = call_bandwidth_accounting_radius_to_history($batch, $window);
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        last if $rows <= 0 || (( $end_time - $start_time) > $time_limit );
    }

    $logger->info("moved $rows_deleted for bandwidth_accounting_radius_to_history ($start_time $end_time) ");
}

sub bandwidth_aggregation_history_daily {
    my ($batch, $time_limit) = @_;
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $rows = call_bandwidth_aggregation_history_daily($batch);
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        last if $rows <= 0 || (( $end_time - $start_time) > $time_limit );
    }

    $logger->info("aggregated $rows_deleted for bandwidth_aggregation_history_daily ($start_time $end_time) ");
}

sub bandwidth_aggregation_history_monthly {
    my ($batch, $time_limit) = @_;
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $rows = call_bandwidth_aggregation_history_monthly($batch);
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        last if $rows <= 0 || (( $end_time - $start_time) > $time_limit );
    }

    $logger->info("aggregated $rows_deleted for bandwidth_aggregation_history_monthly ($start_time $end_time) ");
}

sub process_bandwidth_accounting_netflow {
    my ($batch, $time_limit) = @_;
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $rows = call_process_bandwidth_accounting_netflow($batch);
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        last if $rows <= 0 || (( $end_time - $start_time) > $time_limit );
    }

    $logger->info("processed $rows_deleted for process_bandwidth_accounting_netflow ($start_time $end_time) ");
}

sub call_process_bandwidth_accounting_netflow {
    my ($batch) = @_;
    my $accounting_timebucket = $Config{advanced}{accounting_timebucket_size};
    my $sql = "CALL process_bandwidth_accounting_netflow(SUBDATE(NOW(), INTERVAL ? SECOND) ,?);";
    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, $accounting_timebucket, $batch);
    if (is_error($status)) {
        $logger->error("Error calling process_bandwidth_accounting_netflow");
        return 0;
    } else {
        my ($count) = $sth->fetchrow_array();
        $sth->finish;
        return $count;
    }
}

sub call_bandwidth_aggregation {
    my ($rounding, $batch, $date_sql, @date_args) = @_;
    my $sql = "CALL bandwidth_aggregation(?, $date_sql, ?);";
    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, $rounding, @date_args, $batch);
    if (is_error($status)) {
        $logger->error("Error calling bandwidth_aggregation");
        return 0;
    } else {
        my ($count) = $sth->fetchrow_array();
        $sth->finish;
        return $count;
    }
}

sub call_bandwidth_aggregation_history_daily {
    my ($batch) = @_;
    my $sql = "CALL bandwidth_aggregation_history('daily', SUBDATE(NOW(), INTERVAL ? DAY), ?);";
    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, 1, $batch);
    if (is_error($status)) {
        $logger->error("Error calling bandwidth_aggregation_history");
        return 0;
    } else {
        my ($count) = $sth->fetchrow_array();
        $sth->finish;
        return $count;
    }
}

sub call_bandwidth_aggregation_history_monthly {
    my ($batch) = @_;
    my $sql = "CALL bandwidth_aggregation_history('monthly', DATE_SUB(NOW(), INTERVAL ? MONTH), ?);";
    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, 1, $batch);
    if (is_error($status)) {
        $logger->error("Error calling bandwidth_aggregation_history");
        return 0;
    } else {
        my ($count) = $sth->fetchrow_array();
        $sth->finish;
        return $count;
    }
}

sub call_bandwidth_accounting_radius_to_history {
    my ($batch, $window) = @_;
    my $sql = "CALL bandwidth_accounting_radius_to_history(DATE_SUB(NOW(), INTERVAL ? SECOND), ?);";
    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, $window, $batch);
    if (is_error($status)) {
        $logger->error("Error calling call_bandwidth_accounting_radius_to_history");
        return 0;
    } else {
        my ($count) = $sth->fetchrow_array();
        $sth->finish;
        return $count;
    }
}

=head2 bandwidth_accounting_history_cleanup

bandwidth_accounting_history_cleanup

=cut

sub bandwidth_accounting_history_cleanup {
    my ($window_seconds, $batch, $time_limit) = @_;
    if ($window_seconds eq "0") {
        $logger->debug("Not deleting because the window is 0");
        return;
    }

    my $now = pf::dal->now();
    my ($status, $rows) = pf::dal::bandwidth_accounting_history->batch_remove(
        {
            -where => {
                time_bucket => {
                    "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $window_seconds ]
                },
            },
            -limit => $batch,
            -no_auto_tenant_id => 1,
        },
        $time_limit
    );

    return $rows;
}

sub clean_old_sessions {
    my ($window, $batch, $time_limit ) = @_;
    if ($window eq "0") {
        $logger->debug("Not deleting because the window is 0");
        return;
    }
    my $sql = <<SQL;
UPDATE
    bandwidth_accounting,
    (SELECT node_id, unique_session_id, MAX(last_updated) FROM bandwidth_accounting GROUP BY node_id, unique_session_id HAVING MAX(last_updated) < DATE_SUB(NOW(), INTERVAL ? SECOND) AND MAX(last_updated) > '0000-00-00 00:00:00' LIMIT ?) as old_sessions
    SET last_updated = '0000-00-00 00:00:00'
    WHERE (bandwidth_accounting.node_id, bandwidth_accounting.unique_session_id) = (old_sessions.node_id, old_sessions.unique_session_id);
SQL
    my $start_time = time;
    my $end_time;
    my $rows_updated = 0;
    while (1) {
        my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, $window, $batch);
        my $rows = $sth->rows;
        $end_time = time;
        $rows_updated+=$rows if $rows > 0;
        last if $rows <= 0 || (( $end_time - $start_time) > $time_limit );
    }

    $logger->info("processed $rows_updated for bandwidth_close_session ($start_time $end_time) ");
}

sub node_has_bandwidth_accounting {
    my ($mac) = @_;
    my $tenant_id = pf::config::tenant::get_tenant();
    my $node_id = make_node_id($tenant_id, $mac);

    my $sql = <<"SQL";
    select sum(c) as entries from (select count(1) as c from bandwidth_accounting where node_id=? union all select count(1) as c from bandwidth_accounting_history where node_id=?) x;
SQL
    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, $node_id, $node_id);
    if (is_success($status)) {
        my $tbl_ary_ref = $sth->fetchall_arrayref({});
        return $tbl_ary_ref->[0]->{entries} > 0;
    }
    else {
        return $FALSE;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
