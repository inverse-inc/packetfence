package pf::radacct_db;

=head1 NAME

pf::radacct_db -

=head1 DESCRIPTION

pf::radacct_db

=cut

use strict;
use warnings;
use DBI;
use File::Basename;
use pf::log;
use pf::config qw(%Config);
use pf::StatsD::Timer;
use pf::util::statsd qw(called);
our (
    $DBH,
    $NO_DIE_ON_DBH_ERROR,
    $LAST_CONNECT,
);

our $MAX_STATEMENT_TIME = 0.0;

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

=head2 was_recently_connected

was_recently_connected

=cut

sub was_recently_connected {
    return defined($LAST_CONNECT) && $LAST_CONNECT && (time()-$LAST_CONNECT < 30);
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

sub db_config {
    my %config = %{$Config{database}};
    my %radacctConfig = %{$Config{database_radacct} };
    while (my ($k, $v) = each %config) {
        if (!$radacctConfig{$k}) {
            $radacctConfig{$k} = $v;
        }
    }

    return \%radacctConfig;
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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
