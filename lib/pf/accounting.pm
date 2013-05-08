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
use Readonly;

use constant ACCOUNTING => 'accounting';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw($accounting_db_prepared accounting_db_prepare);
    @EXPORT_OK = qw(
        acct_maintenance
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
        node_acct_maintenance_bw_all_exists
        node_acct_maintenance_bw_inbound_exists
        node_acct_maintenance_bw_outbound_exists
        $ACCOUNTING_TRIGGER_RE
    );
}

use pf::config;
use pf::db;
use pf::violation;
use pf::util;
use pf::trigger;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $accounting_db_prepared = 0;

# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $accounting_statements = {};

# This parses the specific accounting violation trigger format
Readonly our $ACCOUNTING_TRIGGER_RE => qr/
    ($BANDWIDTH_DIRECTION_RE)     # bandwidth direction
    (\d+)                         # nb of bandwidth units
    ($BANDWIDTH_UNITS_RE)         # bandwidth units
    ($ACCT_TIME_MODIFIER_RE)      # accounting time window (time modifier)
/x;

Readonly our $DIRECTION_IN => 'IN';
Readonly our $DIRECTION_OUT => 'OUT';

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
        FROM radacct
        WHERE callingstationid = ?
        ORDER BY acctstarttime DESC LIMIT 1;
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
    
    $accounting_statements->{'acct_maintenance_bw_daily_inbound'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid, 
                SUM(radacct_log.acctinputoctets) AS acctinput
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE DAY(timestamp) = DAY(CURRENT_DATE()) AND timestamp >= ?
        GROUP BY radacct.callingstationid
        HAVING acctinput >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_weekly_inbound'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
                SUM(radacct_log.acctinputoctets) AS acctinput
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE YEARWEEK(timestamp) = YEARWEEK(CURRENT_DATE()) AND timestamp >= ? 
        GROUP BY radacct.callingstationid
        HAVING acctinput >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_monthly_inbound'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
                SUM(radacct_log.acctinputoctets) AS acctinput
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE MONTH(timestamp) = MONTH(CURRENT_DATE()) AND timestamp >= ?
        GROUP BY radacct.callingstationid
        HAVING acctinput >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_yearly_inbound'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
                SUM(radacct_log.acctinputoctets) AS acctinput
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE YEAR(timestamp) = YEAR(CURRENT_DATE()) AND timestamp >= ?
        GROUP BY radacct.callingstationid
        HAVING acctinput >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_daily_outbound'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
                SUM(radacct_log.acctoutputoctets) AS acctoutput
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE DAY(timestamp) = DAY(CURRENT_DATE()) AND timestamp >= ?
        GROUP BY radacct.callingstationid
        HAVING acctoutput >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_weekly_outbound'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
                SUM(radacct_log.acctoutputoctets) AS acctoutput
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE YEARWEEK(timestamp) = YEARWEEK(CURRENT_DATE()) AND timestamp >= ?
        GROUP BY radacct.callingstationid
        HAVING acctoutput >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_monthly_outbound'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
                SUM(radacct_log.acctoutputoctets) AS acctoutput
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE MONTH(timestamp) = MONTH(CURRENT_DATE()) AND timestamp >= ?
        GROUP BY radacct.callingstationid
        HAVING acctoutput >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_yearly_outbound'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
                SUM(radacct_log.acctoutputoctets) AS acctoutput
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE YEAR(timestamp) = YEAR(CURRENT_DATE()) AND timestamp >= ?
        GROUP BY radacct.callingstationid
        HAVING acctoutput >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_daily_all'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
               SUM(radacct_log.acctinputoctets) AS acctinput,
               SUM(radacct_log.acctoutputoctets) AS acctoutput,
               SUM(radacct_log.acctinputoctets+radacct_log.acctoutputoctets) AS accttotal
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE DAY(timestamp) = DAY(CURRENT_DATE()) AND timestamp >= ? 
        GROUP BY radacct.callingstationid     
        HAVING accttotal >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_weekly_all'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
               SUM(radacct_log.acctinputoctets) AS acctinput,
               SUM(radacct_log.acctoutputoctets) AS acctoutput,
               SUM(radacct_log.acctinputoctets+radacct_log.acctoutputoctets) AS accttotal
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE YEARWEEK(timestamp) = YEARWEEK(CURRENT_DATE()) AND timestamp >= ?
        GROUP BY radacct.callingstationid
        HAVING accttotal >= ?;
    ]);
 
    $accounting_statements->{'acct_maintenance_bw_monthly_all'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
               SUM(radacct_log.acctinputoctets) AS acctinput,
               SUM(radacct_log.acctoutputoctets) AS acctoutput,
               SUM(radacct_log.acctinputoctets+radacct_log.acctoutputoctets) AS accttotal
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE MONTH(timestamp) = MONTH(CURRENT_DATE()) AND timestamp >= ?
        GROUP BY radacct.callingstationid
        HAVING accttotal >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_yearly_all'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
               SUM(radacct_log.acctinputoctets) AS acctinput,
               SUM(radacct_log.acctoutputoctets) AS acctoutput,
               SUM(radacct_log.acctinputoctets+radacct_log.acctoutputoctets) AS accttotal
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE YEAR(timestamp) = YEAR(CURRENT_DATE()) AND timestamp >= ?
        GROUP BY radacct.callingstationid
        HAVING accttotal >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_inbound_exists'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
               SUM(radacct_log.acctinputoctets) AS acctinput
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE timestamp >= ? AND timestamp <= NOW() AND radacct.callingstationid = ?
        GROUP BY radacct.callingstationid
        HAVING acctinputoctets >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_outbound_exists'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
               SUM(radacct_log.acctoutputoctets) AS acctoutput
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE timestamp >= ? AND timestamp <= NOW() AND radacct.callingstationid = ?
        GROUP BY radacct.callingstationid
        HAVING acctoutputoctets >= ?;
    ]);

    $accounting_statements->{'acct_maintenance_bw_all_exists'} = get_db_handle()->prepare(qq[
        SELECT radacct.callingstationid,
               SUM(radacct_log.acctinputoctets) AS acctinput,
               SUM(radacct_log.acctoutputoctets) AS acctoutput,
               SUM(radacct_log.acctinputoctets+radacct_log.acctoutputoctets) AS accttotal
        FROM radacct_log
        RIGHT JOIN radacct ON radacct_log.acctsessionid = radacct.acctsessionid
        WHERE timestamp >= ? AND timestamp <= NOW() AND radacct.callingstationid = ?
        GROUP BY radacct.callingstationid
        HAVING accttotal >= ?;
    ]);

    $accounting_db_prepared = 1;
}

=item acct_maintenance

Check in the accounting tables for potential bandwidth abuse

=cut

sub acct_maintenance {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->info("getting violations triggers for accounting cleanup");

    my @triggers = trigger_view_type("accounting");

    foreach my $acct_triggers (@triggers) {
        my $acct_policy = $acct_triggers->{'tid_start'};
        my @tid = trigger_view_tid($acct_policy);
        my $vid = $tid[0]{'vid'};

        if ($acct_policy =~ /$ACCOUNTING_TRIGGER_RE/) {

            my $direction = $1;
            my $bwInBytes = pf::util::unpretty_bandwidth($2,$3);

            my $interval;

            if (defined($4)) {
                if ($4 eq 'D'){
                    $interval = "daily";
                } elsif ($4 eq 'W') {
                    $interval = "weekly";
                } elsif ($4 eq 'M') {
                    $interval = "monthly";
                } elsif ($4 eq 'Y') {
                    $interval = "yearly";
                }
            } 
            # no interval given so we assume from beginning of time
            else {
                $interval = "all";
            }

            # Grab the list of the mac address first without caring about the violations
            my $releaseDate = "1";
            my @results;
            if ($direction eq $DIRECTION_IN) {
                @results = node_acct_maintenance_bw_inbound($interval,$releaseDate,$bwInBytes);
            } elsif ($direction eq $DIRECTION_OUT) {
                @results = node_acct_maintenance_bw_outbound($interval,$releaseDate,$bwInBytes);
            } else {
                $logger->info("Calling node acct maintenance total with $interval and $releaseDate for $bwInBytes");
                @results = node_acct_maintenance_bw_total($interval,$releaseDate,$bwInBytes);
            }
            
            # Now that we have the results, loop on the mac.  While doing that, we need to re-check from the last violation if needed.
            foreach my $mac (@results) {
                my $cleanedMac = clean_mac($mac->{'callingstationid'});

                #Do we have a closed violation for the current mac
                $logger->info("Looking if we have a closed violation in the present window for mac $cleanedMac and vid $vid");

                if (violation_exist_acct($cleanedMac,$vid,$interval)) {
                    $logger->info("We have a closed violation in the interval window for node $cleanedMac, need to recalculate using the last violation release date");
                    my @violation = violation_view_last_closed($cleanedMac,$vid);
                    $releaseDate = $violation[0]{'release_date'};

                    if ($direction eq $DIRECTION_IN) {
                         if(node_acct_maintenance_bw_inbound_exists($releaseDate,$bwInBytes,$mac->{'callingstationid'})) {
                              violation_trigger($cleanedMac,$acct_policy,"accounting");
                         } 
                    } elsif ($direction eq $DIRECTION_OUT) {
                         if(node_acct_maintenance_bw_outbound_exists($releaseDate,$bwInBytes,$mac->{'callingstationid'})) { 
                                 violation_trigger($cleanedMac,$acct_policy,"accounting");
                         } 
                    } else {
                         if(node_acct_maintenance_bw_total_exists($releaseDate,$bwInBytes,$mac->{'callingstationid'})) { 
                                 violation_trigger($cleanedMac,$acct_policy,"accounting");
                         } 
                    }
                } else {
                    violation_trigger($cleanedMac,$acct_policy,"accounting");
                }
            }
        }
        else {
            $logger->warn("Invalid trigger for accounting maintenance: $acct_policy");
        }
    }
    return $TRUE;
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
    return _translate_bw(db_data(ACCOUNTING, $accounting_statements, 'acct_view_all_sql'));
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

=item node_acct_maintenance_bw_inbound - get mac that downloaded more bandwidth than they should

=cut
sub node_acct_maintenance_bw_inbound {
    my ($interval,$releaseDate,$bytes) = @_;
    my $query = "acct_maintenance_bw_" . $interval . "_inbound";
    return db_data(ACCOUNTING, $accounting_statements, $query, $releaseDate, $bytes );
}

=item node_acct_maintenance_bw_outbound - get mac that uploaded more bandwidth than they should

=cut
sub node_acct_maintenance_bw_outbound {
    my ($interval,$releaseDate,$bytes) = @_;
    my $query = "acct_maintenance_bw_" . $interval . "_outbound";    
    return db_data(ACCOUNTING, $accounting_statements, $query, $releaseDate, $bytes );

}

=item node_acct_maintenance_bw_total - get mac that used more bandwidth (IN + OUT) than they should

=cut
sub node_acct_maintenance_bw_total {
    my ($interval,$releaseDate,$bytes) = @_;
    my $query = "acct_maintenance_bw_" . $interval . "_all";
    return db_data(ACCOUNTING, $accounting_statements, $query, $releaseDate, $bytes );
}

=item node_acct_maintenance_bw_inbound_exists - check if the mac bust the bandwidth down limit

=cut
sub node_acct_maintenance_bw_inbound_exists {
    my ($releaseDate,$bytes,$mac) = @_;
    return db_data(ACCOUNTING, $accounting_statements, "acct_maintenance_bw_inbound_exists" , $releaseDate, $mac, $bytes );
}

=item node_acct_maintenance_bw_outbound_exists - check if the mac bust the bandwidth up limit

=cut
sub node_acct_maintenance_bw_outbound_exists {
    my ($releaseDate,$bytes,$mac) = @_;
    return db_data(ACCOUNTING, $accounting_statements, "acct_maintenance_bw_outbound_exists" , $releaseDate, $mac, $bytes );
}

=item node_acct_maintenance_bw_total_exists - check if the mac bust the bandwidth up-down limit

=cut
sub node_acct_maintenance_bw_total_exists {
    my ($releaseDate,$bytes,$mac) = @_;
    return db_data(ACCOUNTING, $accounting_statements, "acct_maintenance_bw_all_exists" , $releaseDate, $mac, $bytes );
}

sub _translate_bw {
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

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
