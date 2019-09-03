package pf::db;

=head1 NAME

pf::db - module for database abstraction and utilities.

=cut

=head1 DESCRIPTION

pf::db contains the database utility functions used by the other
PacketFence modules

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use DBI;
use File::Basename;
use pf::log;
use pf::config;
use pfconfig::cached_hash;
use pf::StatsD::Timer;
use pf::util::statsd qw(called);
use POSIX::AtFork;
use pf::CHI;

my $CHI_READONLY = pf::CHI->new(driver => 'RawMemory', datastore => {});

# Constants
use constant MAX_RETRIES  => 3;
# constants used for symbolic referencing magic in db_query_execute
# stuff that is expected in database querying modules
use constant PREPARE_SUB       => '_db_prepare';  # sub with <modulename>_db_prepare
use constant PREPARED_VAR      => '_db_prepared'; # prepare flag with <modulename>_db_prepared
use constant PREPARE_PF_PREFIX => 'pf::';         # prefix to access exported _prepare(d) variables

our $MYSQL_READONLY_ERROR = 1290;
our $WSREP_NOT_READY_ERROR = 1047;

our ( $DBH, $LAST_CONNECT, $DB_Config, $NO_DIE_ON_DBH_ERROR );

our $MAX_STATEMENT_TIME = 0.0;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(db_data db_connect db_disconnect get_db_handle db_query_execute db_ping db_cancel_current_query db_now db_readonly_mode db_check_readonly db_set_max_statement_timeout $MYSQL_READONLY_ERROR);

}

sub CLONE {
    if($DBH) {
        my $clone = $DBH->clone();
        $DBH->{InactiveDestroy} = 1;
        undef $DBH;
        $DBH = $clone;
        $LAST_CONNECT = time();
        on_connect($DBH);
    }
}

POSIX::AtFork->add_to_child(\&CLONE);

END {
    $DBH->disconnect if $DBH;
    $DBH = undef;
}

tie %$DB_Config, 'pfconfig::cached_hash', 'resource::Database';

=head1 SUBROUTINES

=over

=item * db_connect

manages the list of database connection handler per thread

=cut

sub db_connect {
    if (is_old_connection_good($DBH)) {
        return $DBH;
    }
    my $logger = get_logger();
    $logger->debug("(Re)Connecting to MySQL (pid: $$)");
    my ($dsn, $user, $pass) = db_data_source_info();
    # make sure we have a database handle
    if ( $DBH = DBI->connect($dsn, $user, $pass, { RaiseError => 0, PrintError => 0, mysql_auto_reconnect => 1 })) {
        $logger->debug("connected");
        return on_connect($DBH);
    }

    $logger->logcroak("unable to connect to database: " . $DBI::errstr) unless $NO_DIE_ON_DBH_ERROR;
    $logger->error("unable to connect to database: " . $DBI::errstr);
    $pf::StatsD::statsd->increment(called() . ".error.count" );
    return ();
}

=head2 is_old_connection_good

is_old_connection_good

=cut

sub is_old_connection_good {
    my ($dbh) = @_;
    my $logger = get_logger();
    if (!defined $dbh) {
        return 0;
    }

    if (was_recently_connected()) {
        $logger->debug("not checking db handle, it has been less than 30 sec from last connection");
        return 1;
    }

    $logger->debug("checking handle");
    if ( $dbh->ping() ) {
        $LAST_CONNECT = time();
        $logger->debug("we are currently connected");
        return 1;
    }

    return 0;
}

=head2 was_recently_connected

was_recently_connected

=cut

sub was_recently_connected {
    return defined($LAST_CONNECT) && $LAST_CONNECT && (time()-$LAST_CONNECT < 30);
}

=head2 on_connect

on_connect

=cut

sub on_connect {
    my ($dbh) = @_;
    $LAST_CONNECT = time();
    if (my $sql = init_command($dbh)) {
        $dbh->do($sql);
    }
    return $dbh;
}

=head2 db_data_source_info

db_data_source_info

=cut

sub db_data_source_info {
    my ($self) = @_;
    my $config = db_config();
    my $dsn = "dbi:mysql:dbname=$config->{db};host=$config->{host};port=$config->{port};mysql_client_found_rows=0";
    get_logger->trace(sub {"connecting with $dsn"});

    return (
        $dsn,
        $config->{user},
        $config->{pass},
    );
}

=head2 init_command

init_command

=cut

sub init_command {
    my ($dbh) = @_;
    my $sql = '';
    if (my $new_timeout = db_get_max_statement_timeout()) {
        my ($name, $current_timeout) = $dbh->selectrow_array("SHOW VARIABLES WHERE Variable_name in ('max_statement_time', 'max_execution_time')");
        if ($name) {
            $sql .= "SET SESSION $name=" . convert_timeout($current_timeout, $new_timeout);
        }
    }
    return $sql;
}

sub convert_timeout {
    my ($current_timeout, $new_timeout) = @_;
    $new_timeout = int($new_timeout * 1000) if $current_timeout =~ /^\d+$/;#If the current value is a pure integer then convert timeout to millisecond
    return $new_timeout;
}

=head2 db_config

db config

=cut

sub db_config {
    return {%$DB_Config};
}

=item * db_ping

checks if database is connected

=cut

sub db_ping {
    my ($dbh,$result);
    local $NO_DIE_ON_DBH_ERROR = 1;
    $dbh = db_connect;
    $result = $dbh->ping if $dbh;
    return $result;
}

=item db_handle_error

db_handle_error

=cut

sub db_handle_error {
    my ($err) = @_;
    if ($err == $MYSQL_READONLY_ERROR || $err == $WSREP_NOT_READY_ERROR) {
        db_set_readonly_mode(1);
    }
    return ;
}

=item * db_disconnect

=cut

sub db_disconnect {
    if (defined($DBH)) {
        my $logger = get_logger();
        $logger->debug("disconnecting db");
        $DBH->disconnect();
        $LAST_CONNECT = 0;
        $DBH = undef;
    }
}

=item * get_db_handle - always use that to get a db handle

=cut

sub get_db_handle {
    if (defined($DBH)) {
        return $DBH;
    } else {
        return db_connect();
    }
}

=item * db_data - fetch all the rows of a given database statement and returns a hashref to the data

=over 6

=item $from_module: calling module. Will be used to call the <name>_db_prepared if statements were not prepared.

=item $module_statements_ref: the hashref to all prepared statements for the calling module

=item $query: the name of the query to be executed

=item @params: query parameters (optional)

=back

=cut

sub db_data {
    my ($from_module, $module_statements_ref, $query, @params) = @_;
    my $timer = pf::StatsD::Timer->new({ 'stat' => called() . ".$query",  level => 9});

    my $sth = db_query_execute($from_module, $module_statements_ref, $query, @params) || return (0);

    my ( $ref, @array );
    # TODO maybe we should carry an arrayref around instead of copying an array?
    while ( $ref = $sth->fetchrow_hashref() ) {
        push( @array, $ref );
    }
    $sth->finish();
    return (@array);
}

=item * db_query_execute - execute a given database statement (making sure it succeed) and retuns the statement handle

=over 6

=item $from_module: calling module. Will be used to call the <name>_db_prepared if statements were not prepared.

=item $module_statements_ref: the hashref to all prepared statements for the calling module

=item $query: the name of the query to be executed

=item @params: query parameters (optional)

=back

=cut

#TODO we should mesure the performance and security benefit of using prepared statements because they
# cause a lot of complexity
# TODO refactoring: getrid of all the module discovery magic and have the clients pass a reference to
# the module itself and call is_db_prepared() and db_prepare_sub().
# this would remove most magic and unneeded string magic
# afterwards: remove export of $<module>_db_prepared and <module>_db_prepare()
sub db_query_execute {
    my ($from_module, $module_statements_ref, $query, @params) = @_;
    my $timer = pf::StatsD::Timer->new({ 'stat' => called() . ".$query",  level => 9});
    my $logger = get_logger();

    # argument validation
    my $parameters_exist = (defined($from_module) && defined($query) && defined($module_statements_ref));
    my $statements_valid = (ref($module_statements_ref) eq 'HASH');
    if (!($parameters_exist && $statements_valid)) {
        $logger->error("Invalid parameters for query $query. Called from: " .(caller(1))[3].". Query failed.");
        $pf::StatsD::statsd->increment(called() . ".error.count" );
        return;
    }

    # module-magic to verify prepared statements or call them
    # after these assignation, ${$db_prepared_var} refers to calling module prepare var. same goes for sub
    my $basename = ($from_module =~ /^.*::(.+)$/) ? $1 : $from_module; # basename equals ::(this) if there's a ::
    my $db_prepare_sub  = PREPARE_PF_PREFIX . $from_module . "::" . $basename . PREPARE_SUB;
    my $db_prepared_var = PREPARE_PF_PREFIX . $from_module . "::" . $basename . PREPARED_VAR;
    pf::log::logstacktrace("Calling query '${query}' for module $from_module");

    # loop variables
    my $attempts = 0;
    my $done = 0;
    my $db_statement;
    my $dbi_err = 0;
    do {
        $logger->trace(sub {"attempt #$attempts to run query $query from module $from_module"});

        # are module statements prepared?
        # remove restriction on symbolic reference, I need this magic
        my $prepared;
        {
            no strict 'refs';
            $prepared = ${$db_prepared_var};
        }

        # if module's statements are not prepared, prepare them now
        if (!$prepared) {

            $logger->debug("Database statements not prepared, preparing...");

            # calling the module's db prepare sub
            # remove restriction on symbolic reference, I need this magic
            {
                no strict 'refs';
                # convoluted statement to call the sub <module>_db_prepare()
                &{$db_prepare_sub}()
                    or $logger->error("Can't prepare database statements for $from_module. "
                        ."Sub $db_prepare_sub does not exist");
            }
        }

        # fetch statement, run query and catch errors
        $db_statement = $module_statements_ref->{$query};
        my $valid_prepared_statement = (defined($db_statement) && (ref($db_statement) eq 'DBI::st'));
        # hack! for statements that we can't prepare, we have put the SQL statement in the statement ref
        # and we will prepare it now
        my $dbh = get_db_handle;
        if ($dbh && !$valid_prepared_statement && $db_statement !~ /^$/) {
            $logger->debug("statement provided is a SQL string, preparing statement...");
            $db_statement = $dbh->prepare($db_statement);
        }

        my $valid_statement = (defined($db_statement) && (ref($db_statement) eq 'DBI::st'));
        $logger->trace( sub { "SQL statement ($query): " . $db_statement->{Statement} } ) if ($valid_statement);
        $logger->trace( sub { "SQL params ($query): " . join(', ', map { defined $_ ? $_ : '<null>' } @params) } ) if (@params);

        if ($valid_statement && $db_statement->execute(@params)) {

            # statement execute was a success; we are done
            $done = 1;

        } else {

            # is it a DBI error?
            $dbi_err = $dbh->err;
            if (defined($dbi_err)) {
                $dbi_err = int($dbi_err);
                my $dbi_errstr = $dbh->errstr;
                db_handle_error($dbi_err);
                # Do not retry server errors
                if ($dbi_err < 2000) {
                    $logger->info("database query failed with: $dbi_errstr (errno: $dbi_err)");
                    $done = 2;
                }
                else {
                    # retry client errors
                    $logger->warn("database query failed with: $dbi_errstr (errno: $dbi_err), will try again");
                }
            }
            else {
                $logger->warn(
                    "database query failed because statement handler was undefined or invalid, " . "will try again");
            }

            unless ($done) {
                # this forces real reconnection by invalidating last_connect timer for this thread
                $LAST_CONNECT = 0;
                db_connect();

                # invalidate prepared database statements, forces a new preparation on next iteration
                {
                    no strict 'refs';
                    ${$db_prepared_var} = 0;
                }
            }
        }

        $attempts++;
    } while ($attempts < MAX_RETRIES && !$done);

    if ($done == 1) {
        return $db_statement;
    }
    if ($done) {
        if (defined $dbi_err && $dbi_err == $MYSQL_READONLY_ERROR) {
            $logger->warn("Database issue: attempting to update a readonly database (read_only is ON)");
        }
        elsif (defined $dbi_err && $dbi_err == $WSREP_NOT_READY_ERROR) {
            $logger->warn("Database issue: attempting to update a database that is not ready for writes (wsrep_ready is OFF)");
        }
        else {
            $logger->error("Database issue: Failed with a non-repeatable error with query $query");
        }
    } else {
        $logger->error("Database issue: We tried ". MAX_RETRIES ." times to serve query $query called from "
            .(caller(1))[3]." and we failed. Is the database running?");
    }
    $pf::StatsD::statsd->increment(called() . ".error.count" );
    return;
}

=item db_transaction_execute

Intended to run db_query_execute commands in a transactional mode

=cut

sub db_transaction_execute {
    my ( $sub ) = @_;
    my $logger = get_logger();

    my $dbh = get_db_handle();
    unless ( $dbh->{AutoCommit} ) {
        $logger->error("Transaction already in place");
        return;
    }
    $dbh->{AutoCommit} = 0;
    if ( $dbh->{AutoCommit} ) {
        $logger->error("Unable to start transaction");
        return;
    }

    my $rc = eval {
        $sub->();
        $dbh->commit;
    };
    if ( $@ ) {
        $dbh->rollback;
    }

    $dbh->{AutoCommit} = 1;
    return $rc;
}

our $PREPARED_NOW_STMT;

=item db_now

Get the current timestamp of the mysql query

=cut

sub db_now {
    my $dbh = get_db_handle();
    $PREPARED_NOW_STMT = $dbh->prepare("SELECT NOW();") unless $PREPARED_NOW_STMT;
    return unless $PREPARED_NOW_STMT->execute();
    my $row = $PREPARED_NOW_STMT->fetch;
    $PREPARED_NOW_STMT->finish;
    return unless $row;
    return $row->[0];
}

=item * db_cancel_current_query

Cancels the current query

=cut

sub db_cancel_current_query {
    if($DBH) {
        my $dbh_clone = $DBH->clone;
        $dbh_clone->do("KILL QUERY ". $DBH->{"mysql_thread_id"} . ";");
        $dbh_clone->disconnect();
    }
}

=item db_set_readonly_mode

db_set_readonly_mode

=cut

sub db_set_readonly_mode {
    my ($mode) = @_;
    $CHI_READONLY->set("inreadonly", $mode);
}

=item db_readonly_mode

db_readonly_mode

=cut

sub db_readonly_mode {
    my $dbh = eval {
        db_connect()
    };
    return 0 unless $dbh;

    # check if the read_only flag is set
    my $sth = $dbh->prepare_cached('SELECT @@global.read_only;');
    return 0 unless $sth->execute;
    my $row = $sth->fetch;
    $sth->finish;
    my $readonly = $row->[0];
    # If readonly no need to check wsrep health
    return 1 if $readonly;
    $sth = $dbh->prepare_cached('SELECT VARIABLE_VALUE from information_schema.GLOBAL_VARIABLES where VARIABLE_NAME=\'INNODB_READ_ONLY\'');
    return 0 unless $sth->execute;
    $row = $sth->fetch;
    $sth->finish;
    $readonly = $row->[0];
    # If readonly no need to check wsrep health
    return 1 if ($readonly eq 'ON');
    # If wsrep is not healthly then it is in readonly mode
    return !db_wsrep_healthy();
}

=head2 db_wsrep_healthy

check if the wsrep_ready status is ON if there is a wsrep_provider_name

=cut

sub db_wsrep_healthy {
    my $logger = get_logger();
    my $dbh = eval {
        db_connect()
    };
    return 0 unless $dbh;

    my $sth = $dbh->prepare_cached('show status like "wsrep_provider_name";');
    return 0 unless $sth->execute;
    my $row = $sth->fetch;
    $sth->finish;

    if(defined($row) && $row->[1] ne "") {
        $logger->debug("There is a wsrep provider, checking the wsrep_ready flag");
        # check if the wsrep_ready status is ON
        $sth = $dbh->prepare_cached('show status like "wsrep_ready";');
        return 0 unless $sth->execute;
        $row = $sth->fetch;
        $sth->finish;
        # If there is no wsrep_ready row, then we're not in read only because we don't use wsrep
        # If its there and not set to ON, then we're in read only
        return (defined($row) && $row->[1] eq "ON");
    }
    # wsrep isn't enabled
    else {
        $logger->debug("No wsrep provider so considering wsrep as healthy");
        return 1;
    }
}

=item db_check_readonly

db_in_readonly

=cut

sub db_check_readonly {
    my ($self) = @_;
    my $mode = $CHI_READONLY->compute("inreadonly", {expires_in => '5'}, \&db_readonly_mode);
    return $mode;
}

=item db_set_max_statement_timeout

Set the max statement timeout

In order to take effect must be set before connecting to the database

=cut

sub db_set_max_statement_timeout {
    my ($timeout) = @_;
    $timeout //= 0.0;
    $timeout += 0.0;
    if ($MAX_STATEMENT_TIME != $timeout) {
        db_disconnect();
        $DBH = undef;
        $MAX_STATEMENT_TIME = $timeout;
    }
}

=head2 db_get_max_statement_timeout

Get the max statement timeout

=cut

sub db_get_max_statement_timeout {
    return $MAX_STATEMENT_TIME + 0.0 ;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
