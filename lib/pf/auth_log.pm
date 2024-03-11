package pf::auth_log;

use strict;
use warnings;

use constant AUTH_LOG => "auth_log";

# We will use the process name defined in the logging to insert in the table
use Log::Log4perl::MDC;
use constant process_name => Log::Log4perl::MDC->get("proc") || "N/A";

use Readonly;
Readonly our $COMPLETED => "completed";
Readonly our $FAILED => "failed";
Readonly our $INCOMPLETE => "incomplete";
Readonly our $INVALIDATED => "invalidated";

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        auth_log_db_prepare
        $auth_log_db_prepared
    );
}

use pf::dal;
use pf::dal::auth_log;
use pf::constants qw($ZERO_DATE);
use pf::error qw(is_error is_success);
use pf::log;

=head2 invalidate_previous

=cut

sub invalidate_previous {
    my ($source, $mac, $profile) = @_;
    my ($status, $rows) = pf::dal::auth_log->update_items(
        -set => {
            completed_at => \'NOW()',
            status => $INVALIDATED,
        },
        -where => {
            process_name => process_name,
            source => $source,
            mac => $mac,
            status => $INCOMPLETE,
            profile => $profile,
        },
    );
    return $rows;
}

sub record_oauth_attempt {
    my ($source, $mac, $profile) = @_;
    invalidate_previous($source, $mac, $profile);
    my $status = pf::dal::auth_log->create({
        process_name => process_name,
        source => $source,
        mac => $mac,
        attempted_at => \'NOW()',
        status => $INCOMPLETE,
        profile => $profile,
    });
    return (is_success($status));
}

sub record_completed_oauth {
    my ($source, $mac, $pid, $auth_status, $profile) = @_;
    my ($status, $rows) = pf::dal::auth_log->update_items(
        -set => {
            completed_at => \'NOW()',
            status => $auth_status,
            pid => $pid,
            profile => $profile,
        },
        -where => {
            process_name => process_name,
            source => $source,
            mac => $mac,
        },
        -limit => 1,
        -order_by => { -desc => 'attempted_at' },
    );
    return $rows;
}

sub record_guest_attempt {
    my ($source, $mac, $pid, $profile) = @_;
    invalidate_previous($source, $mac, $profile);
    my $status = pf::dal::auth_log->create({
        process_name => process_name,
        source => $source,
        mac => $mac,
        pid => ($pid // ''),
        attempted_at => \'NOW()',
        status => $INCOMPLETE,
        profile => $profile,
    });
    return (is_success($status));
}

sub record_completed_guest {
    my ($source, $mac, $auth_status, $profile) = @_;
    my ($status, $rows) = pf::dal::auth_log->update_items(
        -set => {
            completed_at => \'NOW()',
            status => $auth_status,
            profile => $profile,
        },
        -where => {
            process_name => process_name,
            source => $source,
            mac => $mac,
        },
        -limit => 1,
        -order_by => { -desc => 'attempted_at' },
    );
    return $rows;
}

sub record_auth {
    my ($source, $mac, $pid, $auth_status, $profile) = @_;
    my $status = pf::dal::auth_log->create({
        process_name => process_name,
        source => $source,
        mac => $mac,
        pid => ($pid // ''),
        attempted_at => \'NOW()',
        completed_at => \'NOW()',
        status => $auth_status,
        profile => $profile,
    });
    return (is_success($status));
}

sub change_record_status {
    my ($source, $mac, $auth_status) = @_;
    my ($status, $rows) = pf::dal::auth_log->update_items(
        -set => {
            status => $auth_status,
        },
        -where => {
            process_name => process_name,
            source => $source,
            mac => $mac,
        },
        -limit => 1,
        -order_by => { -desc => 'attempted_at' },
    );
    return $rows;
}

=head2 cleanup

Execute a cleanup job on the table

=cut

sub cleanup {
    my $timer = pf::StatsD::Timer->new({ sample_rate => 0.2 });
    my ($expire_seconds, $batch, $time_limit) = @_;
    my $logger = get_logger();
    $logger->debug("calling cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit");

    if($expire_seconds eq "0") {
        $logger->debug("Not deleting because the window is 0");
        return;
    }
    my $now = pf::dal->now();
    my ($status, $rows_deleted) = pf::dal::auth_log->batch_remove(
        {
            -where => {
                attempted_at => {
                    "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ]
                },
            },
            -limit => $batch,
        },
        $time_limit
    );
    return ($rows_deleted);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
