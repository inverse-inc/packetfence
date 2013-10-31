package pf::inline::accounting;

# TODO
#  
#  provide function to get accounting data for a single ip.
#    Taking starttime, endtime as optional parameters

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

    $accounting_statements->{'accounting_select_all_ip_stats_mem_sql'} =
      get_db_handle()->prepare(qq[
        SELECT src_ip, inbytes, outbytes, firstseen, lastmodified from $mem_table
      ]);

    $accounting_statements->{'accounting_select_single_ip_stats_mem_sql'} =
      get_db_handle()->prepare(qq[
        SELECT src_ip, inbytes, outbytes, firstseen, lastmodified from $mem_table
      ]);

    $accounting_statements->{'accounting_delete_all_mem_sql'} =
      get_db_handle()->prepare(qq[
        DELETE FROM $mem_table
      ]);

    $accounting_statements->{'accounting_drop_single_ip_stats_mem_sql'} = 
      get_db_handle()->prepare(qq[
        DELETE FROM $mem_table where `src_ip` =  ?
      ]);

    $accounting_statements->{'accounting_drop_inactive_sessions_mem_sql'} = 
      get_db_handle()->prepare(qq[
        DELETE FROM $mem_table where `lastmodified` < NOW() - ?
      ]);

    $accounting_statements->{'accounting_reset_autoincrement_mem_sql'} =
      get_db_handle()->prepare(qq[
        ALTER TABLE $mem_table AUTO_INCREMENT = 1
      ]);

    $accounting_statements->{'accounting_add_active_session_sql'} = 
      get_db_handle()->prepare(qq[
        INSERT into $accounting_table(src_ip, firstseen, lastmodified, outbytes, inbytes)
          VALUES (?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE
            lastmodified = ?,
            outbytes = ?,
            inbytes = ?
      ]);

    $accounting_statements->{'accounting_select_single_ip_stats_sql'} =
      get_db_handle()->prepare(qq[
        SELECT src_ip, inbytes, outbytes, firstseen, lastmodified
          from $mem_table where src_ip = ?
      ]);

    $accounting_db_prepared = 1;
}


sub inline_accounting_stats_for_ip {
    # $ip: ip to get stats for
    # $starttime:  get stats from that time until $endtime
    # $endtime
    # By default it will fetch / add all rows/stats for the requested ip
    my ($ip, $starttime, $endtime) = @_;

}

sub inline_accounting_import_ulogd_data {
    # Session that haven't been updated for more than
    # $accounting_session_timeout seconds will be dropped from the mem table.
    # When reconnecting, the client willget a new entry in the accounting table.
    # Should be higher than the interval at which import_ulogd_data is called.
    # $ip is optional. When call with this parameter, this function will import
    # the stats for that ip only and then delete its row in the mem table.
    # This is done to ensure that new statistics will be part of a new
    # accounting session
    my ($accounting_session_timeout, $ip)= @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->debug("Importing ulogd data");

    my $dbh = get_db_handle();
    $dbh->do("LOCK TABLE $mem_table WRITE");

    # XXX if one of these statements fail it will reconnect. losing the table lock
    # some accounting data updates may be lost
    my $new_data_query;
    if (defined $ip) {
      $new_data_query = db_query_execute("inline::accounting",
                              $accounting_statements,
                              'accounting_select_single_ip_stats_mem_sql',
                              $ip) || return (0);
    } else {
      $new_data_query = db_query_execute("inline::accounting",
                              $accounting_statements,
                              'accounting_select_all_ip_stats_mem_sql') || return (0);
    }

    my $new_accounting_data = $new_data_query->fetchall_arrayref();

    if (defined $ip) {
        # This is done to ensure that new stats will create a new 'session'
        # in the accounting table.
        $logger->debug("Dropping stats from memory table for ip $ip");
        db_query_execute("inline::accounting", $accounting_statements,
                         'accounting_drop_single_ip_stats_mem_sql', $ip);
    } else {
        # This drop all logic must be done only when called for all ips
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
            # Drop all data from mem table to get new accounting sessions every day
            $logger->debug("New day, dropping all rows from ulogd memory table");
            # Need to use DELETE FROM + reset AUTO_INCREMENT since a locked table cannot be truncated
            db_query_execute("inline::accounting", $accounting_statements, 'accounting_delete_all_mem_sql');
            db_query_execute("inline::accounting", $accounting_statements, 'accounting_reset_autoincrement_mem_sql');
        }
        else {
            db_query_execute("inline::accounting", $accounting_statements, 'accounting_drop_inactive_sessions_mem_sql', $accounting_session_timeout);
        }
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
