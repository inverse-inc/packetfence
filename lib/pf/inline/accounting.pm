package pf::inline::accounting;

=head1 NAME

=cut

=head1 DESCRIPTION

=head1 CONFIGURATION AND ENVIRONMENT

=cut

use strict;
use warnings;

use Carp;
use Log::Log4perl;
use Readonly;

my $accounting_table = 'inline_accounting';

my $ACTIVE = 0;
my $INACTIVE = 1;
my $ANALYZED = 3;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        inline_accounting_db_prepare
        $inline_accounting_db_prepared

        inline_accounting_update_session_for_ip
    );
}

use pf::config;
use pf::config::cached;
use pf::db;
use pf::trigger;
use pf::violation;

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

    $accounting_statements->{'accounting_update_session_for_ip'} =
      get_db_handle()->prepare(qq[
        UPDATE $accounting_table SET inbytes  =  inbytes + ?, outbytes = outbytes + ?, lastmodified = FROM_UNIXTIME(?)
	  WHERE ip = ? AND status = $ACTIVE
      ]);

    $accounting_statements->{'accounting_insert_session_for_ip'} =
      get_db_handle()->prepare(qq[
        INSERT INTO $accounting_table(ip, inbytes, outbytes, firstseen, lastmodified, status)
         VALUES (?, ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?), $ACTIVE)
      ]);

    $accounting_statements->{'accounting_active_session_for_ip'} =
      get_db_handle()->prepare(qq[
        SELECT firstseen FROM $accounting_table WHERE ip = ? AND status = $ACTIVE
      ]);

    $accounting_statements->{'accounting_select_node_bandwidth_balance_sql'} =
      get_db_handle()->prepare(qq[
        SELECT n.mac, i.ip, n.bandwidth_balance, COALESCE((a.outbytes + a.inbytes), 0) as bandwidth_consumed
        FROM node n, iplog i
        LEFT JOIN $accounting_table a ON i.ip = a.src_ip AND a.status = $ACTIVE
        WHERE n.mac = i.mac
          AND i.end_time = 0
          AND (n.bandwidth_balance = 0
               OR (n.bandwidth_balance < (a.outbytes + a.inbytes)))
        FOR UPDATE
      ]);

    $accounting_statements->{'accounting_update_node_bandwidth_balance_sql'} =
      get_db_handle()->prepare(qq[
        UPDATE node n SET n.bandwidth_balance = n.bandwidth_balance -
          COALESCE(
            (SELECT SUM(a.outbytes+a.inbytes)
             FROM $accounting_table a, iplog i
             WHERE a.src_ip = i.ip
               AND i.end_time = 0
               AND i.mac = n.mac
               AND a.status = $INACTIVE
            ),
          0)
        WHERE n.bandwidth_balance > 0
      ]);

    $accounting_db_prepared = 1;
}

sub inline_accounting_update_session_for_ip {
    my ($ip, $inbytes, $outbytes, $firstseen, $lastmodified) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $active_session_query =  db_query_execute("inline::accounting",
                                                 $accounting_statements,
                                                 'accounting_active_session_for_ip', $ip) || return(0);

    my $active_session = $active_session_query->fetchrow_arrayref();
    if (defined($active_session)) {
      db_query_execute("inline::accounting",
		       $accounting_statements,
		       'accounting_update_session_for_ip',
		       $inbytes, $outbytes, $lastmodified, $ip) || return(0);
    } else {
        db_query_execute("inline::accounting",
			  $accounting_statements,
			  'accounting_insert_session_for_ip',
			  $ip, $inbytes, $outbytes, $firstseen, $lastmodified) || return(0);
    }
   
    return 1;
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
# vim: set ts=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
