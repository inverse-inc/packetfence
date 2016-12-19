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

use pf::db;
use pf::log;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $auth_log_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $auth_log_statements = {};

sub auth_log_db_prepare {
    my $logger = get_logger;
    $logger->debug("Preparing pf::auth_log database queries");

    $auth_log_statements->{'auth_log_view_by_pid_sql'} = get_db_handle()->prepare(qq[
        SELECT * FROM auth_log WHERE pid = ?
    ]);

    $auth_log_statements->{'auth_log_record_oauth_attempt_sql'} = get_db_handle()->prepare(qq[
        insert into auth_log (process_name,source,mac,attempted_at,status)
        VALUES(?, ?, ?, NOW(), '$INCOMPLETE');
    ]);

    $auth_log_statements->{'auth_log_record_completed_oauth_sql'} = get_db_handle()->prepare(qq[
        update auth_log set completed_at=NOW(), status=?, pid=?
        where process_name=? and source=? and mac=?
        order by attempted_at desc limit 1;
    ]);

    $auth_log_statements->{'auth_log_invalidate_previous_sql'} = get_db_handle()->prepare(qq[
        update auth_log set completed_at=NOW(), status='$INVALIDATED'
        where process_name=? and source=? and mac=? and status='$INCOMPLETE';
    ]);

    $auth_log_statements->{'auth_log_record_guest_attempt_sql'} = get_db_handle()->prepare(qq[
        insert into auth_log (process_name,source,mac,pid,attempted_at,status)
        VALUES(?, ?, ?, ?, NOW(), '$INCOMPLETE');
    ]);

    $auth_log_statements->{'auth_log_record_completed_guest_sql'} = get_db_handle()->prepare(qq[
        update auth_log set completed_at=NOW(), status=?
        where process_name=? and source=? and mac=?
        order by attempted_at desc limit 1;
    ]);

    $auth_log_statements->{'auth_log_record_auth_sql'} = get_db_handle()->prepare(qq[
        insert into auth_log (process_name, source, mac, pid, attempted_at, completed_at, status)
        VALUES(?, ?, ?, ?, NOW(), NOW(), ?);
    ]);

    $auth_log_statements->{'auth_log_change_status_sql'} = get_db_handle()->prepare(qq[
        update auth_log set status=?
        where process_name=? and source=? and mac=?
        order by attempted_at desc limit 1;
    ]);
    
    $auth_log_statements->{'auth_log_cleanup_sql'} = get_db_handle()->prepare(
        qq [ delete from auth_log where attempted_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?]);


    $auth_log_db_prepared = 1;
}

=head2 view

view a an pending activation record, returns an hashref

=cut

sub view_by_pid {
    my ($pid) = @_;
    return db_data(AUTH_LOG, $auth_log_statements, 'auth_log_view_by_pid_sql', $pid);
}

=head2 open

=cut

sub invalidate_previous {
    my ($source, $mac) = @_;
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_invalidate_previous_sql', process_name, $source, $mac));
}

sub record_oauth_attempt {
    my ($source, $mac) = @_;
    invalidate_previous($source,$mac);
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_record_oauth_attempt_sql', process_name, $source, $mac));
}

sub record_completed_oauth {
    my ($source, $mac, $pid, $status) = @_;
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_record_completed_oauth_sql', $status, $pid, process_name, $source, $mac));
}

sub record_guest_attempt {
    my ($source, $mac, $pid) = @_;
    invalidate_previous($source,$mac);
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_record_guest_attempt_sql', process_name, $source, $mac, $pid));
}

sub record_completed_guest {
    my ($source, $mac, $status) = @_;
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_record_completed_guest_sql', $status, process_name, $source, $mac));
}

sub record_auth {
    my ($source, $mac, $pid, $status) = @_;
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_record_auth_sql', process_name, $source, $mac, $pid // '', $status));
}

sub change_record_status {
    my ($source, $mac, $status) = @_;
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_change_status_sql', $status, process_name, $source, $mac));
}

=head2 cleanup

Execute a cleanup job on the table

=cut

sub cleanup {
    my $timer = pf::StatsD::Timer->new({ sample_rate => 0.2 });
    my ($expire_seconds, $batch, $time_limit) = @_;
    my $logger = get_logger();
    $logger->debug("calling cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit");
    my $now = db_now();
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $query = db_query_execute(AUTH_LOG, $auth_log_statements, 'auth_log_cleanup_sql', $now, $expire_seconds, $batch)
        || return (0);
        my $rows = $query->rows;
        $query->finish;
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        $logger->trace( sub { "deleted $rows_deleted entries from auth_log during auth_log cleanup ($start_time $end_time) " });
        last if $rows <= 0 || (( $end_time - $start_time) > $time_limit );
    }
    $logger->trace( "deleted $rows_deleted entries from auth_log during auth_log cleanup ($start_time $end_time) " );
    return (0);
}

1;
