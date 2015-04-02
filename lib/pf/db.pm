package pf::db;

=head1 NAME

pf::db - module for database abstraction and utilities.

=cut

=head1 DESCRIPTION

pf::db contains the database utility functions used by the other
Packetfence modules

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

# Constants
use constant MAX_RETRIES  => 3;
# constants used for symbolic referencing magic in db_query_execute
# stuff that is expected in database querying modules
use constant PREPARE_SUB       => '_db_prepare';  # sub with <modulename>_db_prepare
use constant PREPARED_VAR      => '_db_prepared'; # prepare flag with <modulename>_db_prepared
use constant PREPARE_PF_PREFIX => 'pf::';         # prefix to access exported _prepare(d) variables

our ( $DBH, $LAST_CONNECT, $DB_Config, $NO_DIE_ON_DBH_ERROR );

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(db_data db_connect db_disconnect get_db_handle db_query_execute db_ping db_cancel_current_query db_now);

}

sub CLONE {
    if($DBH) {
        $DBH = undef;
        $LAST_CONNECT = 0;
    }
}

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
    my ($mydbh) = @_;
    my $logger = get_logger();
    $mydbh = 0 if ( !defined $mydbh );
    my $caller = ( caller(1) )[3] || basename($0);
    $logger->debug("function $caller is calling db_connect");

    my $tid = threads->self->tid;
    $mydbh = $DBH if ($DBH);

    my $recently_connected = (defined($LAST_CONNECT) && $LAST_CONNECT && (time()-$LAST_CONNECT < 30));
    if ($recently_connected && $mydbh) {
        $logger->debug("not checking db handle, it has been less than 30 sec from last connection");
        return $mydbh;
    }

    $logger->debug("checking handle");
    if ( $mydbh && $mydbh->ping() ) {
        $LAST_CONNECT = time();
        $logger->debug("we are currently connected");
        return $mydbh;
    }

    $logger->debug("(Re)Connecting to MySQL (thread id: $tid)");

    my $host = $DB_Config->{'host'};
    my $port = $DB_Config->{'port'};
    my $user = $DB_Config->{'user'};
    my $pass = $DB_Config->{'pass'};
    my $db   = $DB_Config->{'db'};

    # TODO database prepared statements are disabled by default in dbd::mysql
    # we should test with them, see http://search.cpan.org/~capttofu/DBD-mysql-4.013/lib/DBD/mysql.pm#DESCRIPTION
    $mydbh = DBI->connect( "dbi:mysql:dbname=$db;host=$host;port=$port",
        $user, $pass, { RaiseError => 0, PrintError => 0, mysql_auto_reconnect => 1 } );

    # make sure we have a database handle
    if ($mydbh) {

        $logger->debug("connected");
        $LAST_CONNECT = time();
        $DBH = $mydbh;
        return ($mydbh);

    } else {
        $logger->logcroak("unable to connect to database: " . $DBI::errstr) unless $NO_DIE_ON_DBH_ERROR;
        $logger->error("unable to connect to database: " . $DBI::errstr);
        return ();
    }
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

=item * db_disconnect

=cut

sub db_disconnect {
    my $tid = threads->self->tid;
    if (defined($DBH)) {
        my $logger = get_logger();
        $logger->debug("disconnecting db");
        $DBH->disconnect();
        $LAST_CONNECT = 0;
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
    my $logger = get_logger();

    # argument validation
    my $parameters_exist = (defined($from_module) && defined($query) && defined($module_statements_ref));
    my $statements_valid = (ref($module_statements_ref) eq 'HASH');
    if (!($parameters_exist && $statements_valid)) {
        $logger->error("Invalid parameters for query $query. Called from: " .(caller(1))[3].". Query failed.");
        return;
    }

    # module-magic to verify prepared statements or call them
    # after these assignation, ${$db_prepared_var} refers to calling module prepare var. same goes for sub
    my $basename = ($from_module =~ /^.*::(.+)$/) ? $1 : $from_module; # basename equals ::(this) if there's a ::
    my $db_prepare_sub  = PREPARE_PF_PREFIX . $from_module . "::" . $basename . PREPARE_SUB;
    my $db_prepared_var = PREPARE_PF_PREFIX . $from_module . "::" . $basename . PREPARED_VAR;

    # loop variables
    my $attempts = 0;
    my $done = 0;
    my $db_statement;
    do {
        $logger->trace("attempt #$attempts to run query $query from module $from_module");

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
            my $dbi_err = $dbh->err;
            if (defined($dbi_err)) {
                $dbi_err = int($dbi_err);
                my $dbi_errstr = $dbh->errstr;
                if ($dbi_err == 1062 || $dbi_err == 1317) {

                    # Duplicate entry (1062) or query interrupted (1317)  -- don't retry
                    $logger->info("database query failed with: $dbi_errstr (errno: $dbi_err)");
                    $done = 1;
                }
                else {
                    $logger->warn("database query failed with: $dbi_errstr (errno: $dbi_err), will try again");
                }
            }
            else {
                $logger->warn(
                    "database query failed because statement handler was undefined or invalid, " . "will try again");
            }

            # this forces real reconnection by invalidating last_connect timer for this thread
            $LAST_CONNECT = 0;
            db_connect();

            # invalidate prepared database statements, forces a new preparation on next iteration
            {
                no strict 'refs';
                ${$db_prepared_var} = 0;
            }
        }

        $attempts++;
    } while ($attempts < MAX_RETRIES && !$done);

    if (!$done) {
        $logger->error("Database issue: We tried ". MAX_RETRIES ." times to serve query $query called from "
            .(caller(1))[3]." and we failed. Is the database running?");
        return;
    } else {
        return $db_statement;
    }
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

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
