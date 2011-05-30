package pf::accounting;

=head1 NAME

pf::accounting

=cut

=head1 DESCRIPTION

pf::accounting is a module to add the RADIUS accounting fonctionnalities and enable some bandwidth/session violations mechanism.

=cut

use strict;
use warnings;

use Log::Log4perl;

use constant ACCOUNTING => 'accounting';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw($accounting_db_prepared accounting_db_prepare);
    @EXPORT_OK = qw(
        node_accounting_exist
        node_accounting_view_active
        node_accounting_view_inactive
    );
}

use pf::config;
use pf::db;
use pf::violation;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $accounting_db_prepared = 0;

# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $accounting_statements = {};

=head1 SUBROUTINES

=over

=item accounting_db_prepare

Initialize database prepared statements

=cut
sub accounting_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::accounting');
    $logger->debug("Preparing pf::accounting database queries");

    $accounting_statements->{'acct_exist_sql'} = get_db_handle()->prepare(qq[
        SELECT COUNT(*) FROM radacct WHERE username = ?;
    ]);

    $accounting_statements->{'acct_view_active_sessions_sql'} = get_db_handle()->prepare(qq[
        SELECT REPLACE(username,'-',':') AS mac,acctstarttime,acctinputoctets,acctoutputoctets,(acctinputoctets+acctoutputoctets) AS accttotaloctets
        FROM radacct
        WHERE acctstoptime IS NULL;
    ]);

    $accounting_statements->{'acct_view_inactive_sessions_sql'} = get_db_handle()->prepare(qq[
        SELECT REPLACE(username,'-',':') AS mac,acctstarttime,acctinputoctets,acctoutputoctets,(acctinputoctets+acctoutputoctets) AS accttotaloctets 
        FROM (SELECT * FROM radacct WHERE acctstoptime IS NOT NULL AND username NOT IN (SELECT username FROM radacct WHERE acctstoptime IS NULL) ORDER BY acctstoptime DESC) AS tmp
        GROUP BY username;
    ]);

   $accounting_statements->{'acct_cummul_statistics_sql'} = get_db_handle()->prepare(qq[
       SELECT SUM(acctinputoctets) AS accttotalinput,SUM(acctoutputoctets) AS accttotaloutput,(accttotalinput+accttotaloutput) AS accttotaloctets
       FROM radacct
       WHERE username = ?;
    ]);

    $accounting_db_prepared = 1;
}

=item accounting_exist

Returns true if an accounting entry exists undef or 0 otherwise.

=cut
sub node_accounting_exist {
    my ($mac) = acct_mac(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'accounting_exist_sql', $mac) || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

=item node_accounting_view_active - view all accounting entries, returns an array of hashrefs

=cut
sub node_accounting_view_active {
    return db_data(ACCOUNTING, $accounting_statements, 'acct_view_active_sessions_sql');
}

=item node_accounting_view_inactive - view the latest session entry, returns an hashref

=cut
sub node_accounting_view_inactive {
    return db_data(ACCOUNTING, $accounting_statements, 'acct_view_inactive_sessions_sql');
}


=back

=head1 AUTHOR

Francois Gaudreault <fgaudreault@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009-2011 Inverse inc.

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
