package pf::auth_log;

use strict;
use warnings;

use constant AUTH_LOG => "auth_log";

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
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
        insert into auth_log (source,mac,attempted_at,status) 
        VALUES(?, ?, NOW(), "incomplete");
    ]);

    $auth_log_statements->{'auth_log_record_completed_oauth_sql'} = get_db_handle()->prepare(qq[
        update auth_log set completed_at=NOW(), status=?, pid=? 
        where source=? and mac=?
        order by attempted_at desc limit 1;
    ]);

    $auth_log_statements->{'auth_log_record_guest_attempt_sql'} = get_db_handle()->prepare(qq[
        insert into auth_log (source,mac,pid,attempted_at,status) 
        VALUES(?,?,?,NOW(),"incomplete");
    ]);

    $auth_log_statements->{'auth_log_record_completed_guest_sql'} = get_db_handle()->prepare(qq[
        update auth_log set completed_at=NOW(), status=? 
        where source=? and mac=?
        order by attempted_at desc limit 1;
    ]);

    $auth_log_statements->{'auth_log_record_auth_sql'} = get_db_handle()->prepare(qq[
        insert into auth_log (source, mac, pid, attempted_at, completed_at, status) 
        VALUES(?, ?, ?, NOW(), NOW(), ?);
    ]);

    $auth_log_statements->{'auth_log_change_status_sql'} = get_db_handle()->prepare(qq[
        update auth_log set status=? 
        where source=? and mac=?
        order by attempted_at desc limit 1;
    ]);

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

sub record_oauth_attempt {
    my ($source, $mac) = @_;
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_record_oauth_attempt_sql', $source, $mac));
}

sub record_completed_oauth {
    my ($source, $mac, $pid, $status) = @_;
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_record_completed_oauth_sql', $status, $pid, $source, $mac));
}

sub record_guest_attempt {
    my ($source, $mac, $pid) = @_;
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_record_guest_attempt_sql', $source, $mac, $pid));
}

sub record_completed_guest {
    my ($source, $mac, $status) = @_;
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_record_completed_guest_sql', $status, $source, $mac));
}

sub record_auth {
    my ($source, $mac, $pid, $status) = @_;
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_record_auth_sql', $source, $mac, $pid, $status));
}

sub change_record_status {
    my ($source, $mac, $status) = @_;
    return(db_data(AUTH_LOG, $auth_log_statements, 'auth_log_change_status_sql', $status, $source, $mac));
}

1;
