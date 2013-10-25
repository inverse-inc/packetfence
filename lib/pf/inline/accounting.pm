package pf::inline::accounting;

=head1 NAME

pf::inline::accounting - Inline accounting

=cut

=head1 DESCRIPTION

pf::inline::accounting FIXME

=head1 CONFIGURATION AND ENVIRONMENT

TODO  : describe database tables, view, procedures required + interaction with ulogd

=cut

use strict;
use warnings;

use Carp;
use Log::Log4perl;
use Readonly;

my $mem_table = 'inline_accounting_mem';
my $accounting_table = 'inline_accounting';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        inline_accounting_db_prepare
        $inline_accounting_db_prepared

        inline_accounting_import_ulogd_data
    );
}

use pf::config;
use pf::config::cached;
use pf::db;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $accounting_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $accounting_statements = {};


=head1 SUBROUTINES

=over

=item inline_accounting_db_prepare

Prepares all the SQL statements related to this module

=cut

sub accounting_db_prepare {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->debug("Preparing" . __PACKAGE__ . "database queries");

    $accounting_statements->{'accounting_select_all_mem_sql'} = get_db_handle()->prepare(qq[
        SELECT src_ip, inbytes, outbytes, firstseen, lastmodified from $mem_table
    ]);

    $accounting_statements->{'accounting_delete_all_mem_sql'} = get_db_handle()->prepare(qq[
        DELETE FROM $mem_table
    ]);

    $accounting_statements->{'accounting_drop_inactive_sessions_mem_sql'} = get_db_handle()->prepare(qq[
        DELETE FROM $mem_table where `lastmodified` < NOW() - ?
    ]);

    $accounting_statements->{'accounting_reset_autoincrement_mem_sql'} = get_db_handle()->prepare(qq[
        ALTER TABLE $mem_table AUTO_INCREMENT = 1
    ]);

    $accounting_statements->{'accounting_add_active_session_sql'} = get_db_handle()->prepare(qq[
        INSERT into $accounting_table(src_ip, firstseen, lastmodified, outbytes, inbytes)
          VALUES (?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE
            lastmodified = ?,
            outbytes = ?,
            inbytes = ?
    ]);

    $accounting_db_prepared = 1;
}


sub import_ulogd_data {
    # Session that haven't been updated for more than this amount of seconds will
    # be dropped from the mem table. If the client connects again,
    # he'll simply get a new entry in the accounting table
    # This should be higher than the interval at which import_ulogd_data is called
    my $accounting_session_timeout = shift;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->debug("Importing ulogd data");

    # lock table write
    # fetch all relevant info
    # loop quickly through returned data,
    #   if lastmodified is not on same day than first seen
    #     delete all from mem_table
    #     reset auto increment counter
    #   else
    #     delete inactive sessions from mem table
    # unlock
    # Update real accounting table with fetched data

    my $dbh = get_db_handle();
    $dbh->do("LOCK TABLE $mem_table WRITE");

    # XXX if one of these statements fail it will reconnect. losing the table lock
    # some accounting data updates may be lost
    my $new_data_query = db_query_execute("inline::accounting",
                              $accounting_statements,
                              'accounting_select_all_mem_sql') || return (0);

    #my $new_accounting_data = $new_data_query->fetchall_hashref('src_ip');
    my $new_accounting_data = $new_data_query->fetchall_arrayref();

    my $dropall=0;
    for my $row (@$new_accounting_data) {
      # this is kind of crude, but should be good enough to detect day changes
      # 2013-10-25 10:01:02
        $$row[-1] =~ /\d+-\d+-(\d+) /;
        my $lastmodified_day = $1;
        $$row[-2] =~ /\d+-\d+-(\d+) /;
        my $firstseen_day = $1;

        if ($firstseen_day != $lastmodified_day) {
            $dropall=1;
            last;
        }
    }
    if ($dropall) {
        $logger->debug("New day, dropping all rows from ulogd memory table");
        # Need to use DELETE FROM + reset AUTO_INCREMENT since a locked table cannot be truncated
        db_query_execute("inline::accounting", $accounting_statements, 'accounting_delete_all_mem_sql');
        db_query_execute("inline::accounting", $accounting_statements, 'accounting_reset_autoincrement_mem_sql');
    }
    else {
        db_query_execute("inline::accounting", $accounting_statements, 'accounting_drop_inactive_sessions_mem_sql', $accounting_session_timeout);
    }
    $dbh->do("UNLOCK TABLES");

    foreach my $row (@$new_accounting_data) {
        my $src_ip = $$row[0];
        my $inbytes = $$row[1];
        my $outbytes = $$row[2];
        my $firstseen = $$row[3];
        my $lastmodified = $$row[4];
        db_query_execute("inline::accounting", $accounting_statements, 'accounting_add_active_session_sql',
                         $src_ip, $firstseen, $lastmodified,
                         $outbytes, $inbytes,
                         $lastmodified, $outbytes, $inbytes);

    }

}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
