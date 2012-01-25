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
        node_accounting_current_sessionid
        node_accounting_dynauth_attr
        node_accounting_exist
        node_accounting_view
        node_accounting_view_all
        node_accounting_daily_bw
        node_accounting_weekly_bw
        node_accounting_monthly_bw
        node_accounting_yearly_bw
        node_accounting_daily_time
        node_accounting_weekly_time
        node_accounting_monthly_time
        node_accounting_yearly_time
    );
}

use pf::config;
use pf::db;
use pf::violation;
use pf::util;

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

    $accounting_statements->{'acct_current_sessionid_sql'} = get_db_handle()->prepare(qq[
        SELECT acctsessionid FROM radacct WHERE acctstoptime IS NULL AND callingstationid=? ORDER BY acctstarttime DESC LIMIT 1;
    ]);

    $accounting_statements->{'acct_dynauth_attr_sql'} = get_db_handle()->prepare(qq[
        SELECT acctsessionid,username FROM radacct WHERE acctstoptime IS NULL AND callingstationid=? ORDER BY acctstarttime DESC LIMIT 1;
    ]);

    $accounting_statements->{'acct_exist_sql'} = get_db_handle()->prepare(qq[
        SELECT COUNT(*) FROM radacct WHERE username = ?;
    ]);

    $accounting_statements->{'acct_view_sql'} = get_db_handle()->prepare(qq[
        SELECT CONCAT(SUBSTRING(callingstationid,1,2),':',SUBSTRING(callingstationid,3,2),':',SUBSTRING(callingstationid,5,2),':',
               SUBSTRING(callingstationid,7,2),':',SUBSTRING(callingstationid,9,2),':',SUBSTRING(callingstationid,11,2)) AS mac,
               username,IF(ISNULL(acctstoptime),'connected','not connected') AS status,acctstarttime,acctstoptime,FORMAT(acctsessiontime/60,2) AS acctsessiontime,
               nasipaddress,nasportid,nasporttype,acctinputoctets AS acctoutput,
               acctoutputoctets AS acctinput,(acctinputoctets+acctoutputoctets) AS accttotal,
               IF(ISNULL(acctstoptime),'',acctterminatecause) AS acctterminatecause
        FROM (SELECT * FROM radacct ORDER BY acctstarttime DESC) AS tmp
        GROUP BY callingstationid
        HAVING callingstationid = ?;
    ]);

    $accounting_statements->{'acct_view_all_sql'} = get_db_handle()->prepare(qq[
        SELECT CONCAT(SUBSTRING(callingstationid,1,2),':',SUBSTRING(callingstationid,3,2),':',SUBSTRING(callingstationid,5,2),':',
               SUBSTRING(callingstationid,7,2),':',SUBSTRING(callingstationid,9,2),':',SUBSTRING(callingstationid,11,2)) AS mac,
               username,IF(ISNULL(acctstoptime),'connected','not connected') AS status,acctstarttime,acctstoptime,FORMAT(acctsessiontime/60,2) AS acctsessiontime,
               nasipaddress,nasportid,nasporttype,acctinputoctets AS acctoutput,
               acctoutputoctets AS acctinput,(acctinputoctets+acctoutputoctets) AS accttotal,
               IF(ISNULL(acctstoptime),'',acctterminatecause) AS acctterminatecause 
        FROM (SELECT * FROM radacct ORDER BY acctstarttime DESC) AS tmp
        GROUP BY callingstationid
        ORDER BY status ASC, acctstarttime DESC;
    ]);

   $accounting_statements->{'acct_bandwidth_daily_sql'} = get_db_handle()->prepare(qq[
        SELECT SUM(radacct_log.acctinputoctets) AS acctinput,
               SUM(radacct_log.acctoutputoctets) AS acctoutput,
               SUM(radacct_log.acctinputoctets+radacct_log.acctoutputoctets) AS accttotal
        FROM radacct_log
        LEFT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE timestamp >= CURRENT_DATE() AND callingstationid = ?;
    ]);

   $accounting_statements->{'acct_bandwidth_weekly_sql'} = get_db_handle()->prepare(qq[
        SELECT SUM(radacct_log.acctinputoctets) AS acctinput,
               SUM(radacct_log.acctoutputoctets) AS acctoutput,
               SUM(radacct_log.acctinputoctets+radacct_log.acctoutputoctets) AS accttotal
        FROM radacct_log
        LEFT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE YEARWEEK(timestamp) = YEARWEEK(CURRENT_DATE()) AND callingstationid = ?;
    ]);

   $accounting_statements->{'acct_bandwidth_monthly_sql'} = get_db_handle()->prepare(qq[
        SELECT SUM(radacct_log.acctinputoctets) AS acctinput,
               SUM(radacct_log.acctoutputoctets) AS acctoutput,
               SUM(radacct_log.acctinputoctets+radacct_log.acctoutputoctets) AS accttotal
        FROM radacct_log
        LEFT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE MONTH(timestamp) = MONTH(CURRENT_DATE()) AND callingstationid = ?;
    ]);

    $accounting_statements->{'acct_bandwidth_yearly_sql'} = get_db_handle()->prepare(qq[
        SELECT SUM(radacct_log.acctinputoctets) AS acctinput,
               SUM(radacct_log.acctoutputoctets) AS acctoutput,
               SUM(radacct_log.acctinputoctets+radacct_log.acctoutputoctets) AS accttotal
        FROM radacct_log
        LEFT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE YEAR(timestamp) = YEAR(CURRENT_DATE()) AND callingstationid = ?;
    ]);

    $accounting_statements->{'acct_sessiontime_daily_sql'} = get_db_handle()->prepare(qq[
        SELECT SUM(FORMAT((radacct_log.acctsessiontime/60),2)) AS accttotaltime
        FROM radacct_log
        LEFT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE timestamp >= CURRENT_DATE() AND callingstationid = ?;
    ]);

    $accounting_statements->{'acct_sessiontime_weekly_sql'} = get_db_handle()->prepare(qq[
        SELECT SUM(FORMAT((radacct_log.acctsessiontime/60),2)) AS accttotaltime
        FROM radacct_log
        LEFT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE YEARWEEK(timestamp) = YEARWEEK(CURRENT_DATE()) AND callingstationid = ?;
    ]);
    
    $accounting_statements->{'acct_sessiontime_monthly_sql'} = get_db_handle()->prepare(qq[
        SELECT SUM(FORMAT((radacct_log.acctsessiontime/60),2)) AS accttotaltime
        FROM radacct_log
        LEFT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE MONTH(timestamp) = MONTH(CURRENT_DATE()) AND callingstationid = ?;
    ]);

    $accounting_statements->{'acct_sessiontime_yearly_sql'} = get_db_handle()->prepare(qq[
        SELECT SUM(FORMAT((radacct_log.acctsessiontime/60),2)) AS accttotaltime
        FROM radacct_log
        LEFT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE YEAR(timestamp) = YEAR(CURRENT_DATE()) AND callingstationid = ?;
    ]);

    $accounting_db_prepared = 1;
}


=item current_sessionid

Returns the current sessionid for a given mac address

=cut
sub node_accounting_current_sessionid {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_current_sessionid_sql', $mac) || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

=item dynauth_attr

Returns the RADIUS Dynamic Authorization attributes (User-name, Acct-Session-Id)

=cut
sub node_accounting_dynauth_attr {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_dynauth_attr_sql', $mac) || return (0);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}

=item accounting_exist

Returns true if an accounting entry exists undef or 0 otherwise.

=cut
sub node_accounting_exist {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_exist_sql', $mac) || return (0);
    my ($val) = $query->fetchrow_hashref();
    $query->finish();
    return ($val);
}

=item node_accounting_view - view latest accounting entry for a node, returns an array of hashrefs

=cut
sub node_accounting_view {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_view_sql', $mac);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}

=item node_accounting_view_all - view all accounting entries, returns an hashref

=cut
sub node_accounting_view_all {
    return translate_bw(db_data(ACCOUNTING, $accounting_statements, 'acct_view_all_sql'));
}

=item node_accounting_daily_bw - view bandwidth tranferred today for a node, returns an array of hashrefs

=cut
sub node_accounting_daily_bw {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_bandwidth_daily_sql', $mac);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}


=item node_accounting_weekly_bw - view bandwidth tranferred this week for a node, returns an array of hashrefs

=cut
sub node_accounting_weekly_bw {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_bandwidth_weekly_sql', $mac);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}

=item node_accounting_monthly_bw - view bandwidth tranferred this month for a node, returns an array of hashrefs

=cut
sub node_accounting_monthly_bw {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_bandwidth_monthly_sql', $mac);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}

=item node_accounting_yearly_bw - view bandwidth tranferred this year for a node, returns an array of hashrefs

=cut
sub node_accounting_yearly_bw {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_bandwidth_yearly_sql', $mac);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}

=item node_accounting_daily_time - view connected time today for a node, returns an array of hashrefs

=cut
sub node_accounting_daily_time {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_sessiontime_daily_sql', $mac);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}

=item node_accounting_weekly_time - view connected time this week for a node, returns an array of hashrefs

=cut
sub node_accounting_weekly_time {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_sessiontime_weekly_sql', $mac);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}

=item node_accounting_monthly_time - view connected time this month for a node, returns an array of hashrefs

=cut
sub node_accounting_monthly_time {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_sessiontime_monthly_sql', $mac);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}

=item node_accounting_yearly_time - view connected time this year for a node, returns an array of hashrefs

=cut
sub node_accounting_yearly_time {
    my ($mac) = format_mac_for_acct(@_);
    my $query = db_query_execute(ACCOUNTING, $accounting_statements, 'acct_sessiontime_yearly_sql', $mac);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}

sub translate_bw {
    my (@data) = @_;

    # determine fields to translate
    my @fields = ('acctinput','acctoutput','accttotal');

    # change bw unit into its meaningful to humans counterpart
    foreach my $datum (@data) {

        for (my $i=0; $i<3 ; $i++) {
            $datum->{$fields[$i]} = pf::util::pretty_bandwidth($datum->{$fields[$i]});
        }
    }
    return (@data);
}

=back

=head1 AUTHOR

Francois Gaudreault <fgaudreault@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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
