package pf::bandwidth_accounting;

=head1 NAME

pf::bandwidth_accounting -

=head1 DESCRIPTION

pf::bandwidth_accounting

=cut

use strict;
use warnings;
use Exporter qw(import);
our @EXPORT_OK = qw(bandwidth_maintenance);
use pf::dal::bandwidth_accounting;
use pf::dal::node;
use pf::error qw(is_error);
use pf::log;
use pf::config qw($ACCOUNTING_POLICY_BANDWIDTH);
use pf::constants::trigger qw($TRIGGER_TYPE_ACCOUNTING);
use pf::config::security_event;
my $logger = get_logger();

sub bandwidth_maintenance {
    my ($batch, $time_limit) = @_;
    process_bandwidth_accounting($batch, $time_limit);
    trigger_bandwidth($batch, $time_limit);
    bandwidth_aggreation_hourly($batch, $time_limit);
}

sub trigger_bandwidth {
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

sub bandwidth_aggreation_hourly {
    my ($batch, $time_limit) = @_;
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $rows = call_bandwidth_aggreation_hourly($batch);
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        last if $rows <= 0 || (( $end_time - $start_time) > $time_limit );
    }

    $logger->info("deleted $rows_deleted for bandwidth_maintenance ($start_time $end_time) ");
}

sub process_bandwidth_accounting {
    my ($batch, $time_limit) = @_;
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $rows = call_process_bandwidth_accounting($batch);
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        last if $rows <= 0 || (( $end_time - $start_time) > $time_limit );
    }

    $logger->info("deleted $rows_deleted for process_bandwidth_accounting ($start_time $end_time) ");
}

sub call_process_bandwidth_accounting {
    my ($batch) = @_;
    my $sql = "CALL process_bandwidth_accounting(?);";
    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, $batch);
    if (is_error($status)) {
        $logger->error("Error calling process_bandwidth_accounting");
        return 0;
    } else {
        my ($count) = $sth->fetchrow_array();
        $sth->finish;
        return $count;
    }
}

sub call_bandwidth_aggreation_hourly {
    my ($batch) = @_;
    my $sql = "CALL bandwidth_aggreation('hourly', SUBDATE(NOW(), INTERVAL 2 HOUR), ?);";
    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, $batch);
    if (is_error($status)) {
        $logger->error("Error calling bandwidth_aggreation");
        return 0;
    } else {
        my ($count) = $sth->fetchrow_array();
        $sth->finish;
        return $count;
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

