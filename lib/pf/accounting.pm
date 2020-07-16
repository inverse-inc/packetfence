package pf::accounting;

=head1 NAME

pf::accounting

=cut

=head1 DESCRIPTION

pf::accounting is a module to add the RADIUS accounting fonctionnalities and enable some bandwidth/session security_events mechanism.

=cut

use strict;
use warnings;

use pf::log;
use Readonly;
use pf::accounting_events_history;
use pf::config::pfmon qw(%ConfigMaintenance);
use pf::config::tenant;
use pf::util qw(make_node_id);
use pf::error qw(is_success);

use constant ACCOUNTING => 'accounting';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
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
        $ACCOUNTING_TRIGGER_RE
    );
}

use pf::constants;
use pf::config qw(
    $BANDWIDTH_DIRECTION_RE
    $BANDWIDTH_UNITS_RE
    $ACCOUNTING_POLICY_TIME
    $ACCOUNTING_POLICY_BANDWIDTH
);
use pf::constants::config qw($ACCT_TIME_MODIFIER_RE);
use pf::constants::trigger qw($TRIGGER_TYPE_ACCOUNTING);
use pf::config::security_event;
use pf::db;
use pf::error qw(is_error);
use pf::security_event;
use pf::util;
use pf::CHI;
use pf::dal::radacct_log;
use pf::dal::radacct;
use pf::dal::bandwidth_accounting;

# This parses the specific accounting security_event trigger format
Readonly our $ACCOUNTING_TRIGGER_RE => qr/
    ($BANDWIDTH_DIRECTION_RE)     # bandwidth direction
    (\d+)                         # nb of bandwidth units
    ($BANDWIDTH_UNITS_RE)         # bandwidth units
    ($ACCT_TIME_MODIFIER_RE)      # accounting time window (time modifier)
/x;

Readonly our $DIRECTION_IN => 'IN';
Readonly our $DIRECTION_OUT => 'OUT';

my %grouping_dates = (
    daily   => 'DATE(time_bucket)',
    weekly  => 'DATE_SUB(DATE(time_bucket), INTERVAL WEEKDAY(time_bucket) DAY)',
    monthly => 'DATE_ADD(DATE(time_bucket),INTERVAL -DAY(time_bucket)+1 DAY)',
    yearly  => 'DATE_ADD(DATE(time_bucket),INTERVAL -DAYOFYEAR(time_bucket)+1 DAY)',
);

my %direction_field = (
    IN  => 'in_bytes',
    OUT => 'out_bytes',
    TOT => 'total_bytes',
);

=head1 SUBROUTINES

=over

=item acct_maintenance

Check in the accounting tables for potential bandwidth abuse

=cut

sub acct_maintenance {
    my $logger = get_logger();
    $logger->info("getting security_events triggers for accounting cleanup");

    my $events_history = pf::accounting_events_history->new();
    my $events_history_hash = $events_history->get_new_history_hash();
    my $history_added = $FALSE;

    foreach my $info (@ACCOUNTING_TRIGGERS) {
        my $acct_policy = $info->{trigger};
        my $security_event_id = $info->{security_event};
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

            $logger->info("Found timeframed accounting policy : $acct_policy for security_event $security_event_id");

            # Grab the list of the mac address first without caring about the security_events
            my $next = 0;
            my $results;
            while (defined $next) {
                ($next, $results) = next_node_acct_maintenance_bw($next, 100, $direction, $interval, $bwInBytes);
                # Now that we have the results, loop on the mac.  While doing that, we need to re-check from the last security_event if needed.
                foreach my $mac (@$results) {
                    my $cleanedMac = clean_mac($mac->{'mac'});

                    #Do we have a closed security_event for the current mac
                    $logger->info("Looking if we have a closed security_event in the present window for mac $cleanedMac and security_event_id $security_event_id");

                    if (security_event_exist_acct($cleanedMac, $security_event_id, $interval)) {
                        $logger->info("We have a closed security_event in the interval window for node $cleanedMac, need to recalculate using the last security_event release date");
                        $events_history->add_to_history_hash($events_history_hash, $cleanedMac, $acct_policy);
                        $history_added = $TRUE;
                        my @security_event = security_event_view_last_closed($cleanedMac,$security_event_id);
                        my $releaseDate = $security_event[0]{'release_date'};
                        if (node_acct_maintenance_bw_exists($mac->{tenant_id}, $mac->{mac}, $direction, $interval, $releaseDate, $bwInBytes)) {
                              security_event_trigger( { 'mac' => $cleanedMac, 'tid' => $acct_policy, 'type' => $TRIGGER_TYPE_ACCOUNTING } );
                        }
                    } else {
                        $events_history->add_to_history_hash($events_history_hash, $cleanedMac, $acct_policy);
                        $history_added = $TRUE;
                        security_event_trigger( { 'mac' => $cleanedMac, 'tid' => $acct_policy, 'type' => $TRIGGER_TYPE_ACCOUNTING } );
                    }
                }
            }
        }
        elsif (($acct_policy ne $ACCOUNTING_POLICY_TIME &&
               $acct_policy ne $ACCOUNTING_POLICY_BANDWIDTH)) {
            $logger->warn("Invalid trigger for accounting maintenance: $acct_policy");
        }
    }

    # Commit the data and give 3 times the acct_maintenance interval as a TTL which should be plenty for the next loop to populate this again
    $events_history->commit($events_history_hash, $ConfigMaintenance{acct_maintenance}{interval}*3) if $history_added;
    return $TRUE;
}

sub next_node_acct_maintenance_bw {
    my ($start, $limit, $direction, $interval, $bytes) = @_;
    my $find_min_max_sql = <<SQL;
    SELECT MIN(node_id), MAX(node_id) from (
    (SELECT node_id FROM bandwidth_accounting node_id WHERE node_id > ? GROUP BY node_id ORDER BY node_id LIMIT ?)
    UNION (SELECT node_id FROM bandwidth_accounting_history node_id WHERE node_id > ? GROUP BY node_id ORDER BY node_id LIMIT ?)) as x ;
SQL

    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($find_min_max_sql, $start, $limit, $start, $limit);
    my ($min, $max) = $sth->fetchrow_array();
    $sth->finish;
    if (!defined $max) {
        return (undef, undef);
    }
    my $field = $direction_field{$direction};
    my $date = $grouping_dates{$interval};
    my $sql2 = <<"SQL";
SELECT
    tenant_id,
    mac,
    SUM($field) as $field FROM (
        SELECT 
            $date AS time_bucket,
            node_id,
            tenant_id,
            mac,
            SUM($field) AS $field 
        FROM bandwidth_accounting
        WHERE node_id BETWEEN ? AND ? GROUP BY node_id, $date 
        UNION ALL SELECT 
            $date AS time_bucket,
            node_id,
            tenant_id,
            mac,
            SUM($field) AS $field 
        FROM bandwidth_accounting_history
        WHERE node_id BETWEEN ? AND ? GROUP BY node_id, $date 
        ) AS X GROUP BY node_id, time_bucket HAVING SUM($field) >= ?;
SQL

    ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql2, $min, $max, $min, $max, $bytes);

    my $r = $sth->fetchall_arrayref({});
    $sth->finish;
    return ($max, $r);
}

=item current_sessionid

Returns the current sessionid for a given mac address

=cut

sub node_accounting_current_sessionid {
    my ($mac) = @_;
    if(my $entry = pf::accounting->cache->get($mac)){
        return $entry->{'Acct-Session-Id'};
    }
    my $entry = _db_item(
        -columns => [qw(acctsessionid)],
        -where => {
            acctstoptime => undef,
            callingstationid => $mac,
        },
        -limit => 1,
        -order_by => {-desc => 'acctstarttime'},
    );
    return ($entry ? $entry->{acctsessionid} : undef);
}

=item dynauth_attr

Returns the RADIUS Dynamic Authorization attributes (User-name, Acct-Session-Id)

=cut

sub node_accounting_dynauth_attr {
    my ($mac) = @_;
    if(my $entry = pf::accounting->cache->get($mac)){
        return {username => $entry->{'User-Name'}, acctsessionid => $entry->{'Acct-Session-Id'}};
    }
    return _db_item(
        -columns => [qw(username acctsessionid)],
        -where => {
            acctstoptime => undef,
            callingstationid => $mac,
        },
        -limit => 1,
        -order_by => {-desc => 'acctstarttime'},
    );
}

=item accounting_exist

Returns true if an accounting entry exists undef or 0 otherwise.

=cut

sub node_accounting_exist {
    my ($mac) = @_;
    my ($status, $count) = pf::dal::radacct->count(
        -where => {
            username => $mac,
        }
    );
    return ($count);
}

=item node_accounting_view - view latest accounting entry for a node, returns an array of hashrefs

=cut

sub node_accounting_view {
    my ($mac) = @_;
    return _db_item(
        -columns => [
            "CONCAT(SUBSTRING(callingstationid,1,2),':',SUBSTRING(callingstationid,3,2),':',SUBSTRING(callingstationid,5,2),':',SUBSTRING(callingstationid,7,2),':',SUBSTRING(callingstationid,9,2),':',SUBSTRING(callingstationid,11,2))|mac",
            "username",
            "IF(ISNULL(acctstoptime),'connected','not connected')|status",
            'acctstarttime',
            'acctstoptime',
            'FORMAT(acctsessiontime/60,2)|acctsessiontime',
            'nasipaddress',
            'nasportid',
            'nasporttype',
            'acctinputoctets|acctoutput',
            'acctoutputoctets|acctinput',
            '(acctinputoctets+acctoutputoctets)|accttotal',
            "IF(ISNULL(acctstoptime),'',acctterminatecause)|acctterminatecause",
      ],
      -where => {
        callingstationid => $mac,
      },
      -limit => 1,
      -order_by => {-desc => 'acctstarttime'},
    );
}

=item node_accounting_view_all - view all accounting entries, returns an hashref

=cut

sub node_accounting_view_all {
    return _translate_bw(_db_items(
        -columns => [
            "CONCAT(SUBSTRING(callingstationid,1,2),':',SUBSTRING(callingstationid,3,2),':',SUBSTRING(callingstationid,5,2),':',SUBSTRING(callingstationid,7,2),':',SUBSTRING(callingstationid,9,2),':',SUBSTRING(callingstationid,11,2))|mac",
            "username",
            "IF(ISNULL(acctstoptime),'connected','not connected')|status",
            'acctstarttime',
            'acctstoptime',
            'FORMAT(acctsessiontime/60,2)|acctsessiontime',
            'nasipaddress',
            'nasportid',
            'nasporttype',
            'acctinputoctets|acctoutput',
            'acctoutputoctets|acctinput',
            '(acctinputoctets+acctoutputoctets)|accttotal',
            "IF(ISNULL(acctstoptime),'',acctterminatecause)|acctterminatecause",
      ],
      -from => \"(SELECT * FROM radacct ORDER BY acctstarttime DESC) AS tmp",
      -group_by => 'callingstationid',
      -order_by => [{-asc => 'status'}, {-desc => 'acctstarttime'}],
    ));
}

=item node_accounting_daily_bw - view bandwidth tranferred today for a node, returns an array of hashrefs

=cut

sub node_accounting_daily_bw {
    my ($mac) = @_;
    return node_accounting_bw($mac, 'daily');
}

=item node_accounting_weekly_bw - view bandwidth tranferred this week for a node, returns an array of hashrefs

=cut

sub node_accounting_weekly_bw {
    my ($mac) = @_;
    return node_accounting_bw($mac, 'weekly');
}

=item node_accounting_monthly_bw - view bandwidth tranferred this month for a node, returns an array of hashrefs

=cut

sub node_accounting_monthly_bw {
    my ($mac) = @_;
    return node_accounting_bw($mac, 'monthly');
}

=item node_accounting_yearly_bw - view bandwidth tranferred this year for a node, returns an array of hashrefs

=cut

sub node_accounting_yearly_bw {
    my ($mac) = @_;
    return node_accounting_bw($mac, 'monthly');
}

sub _node_accounting_time {
    return _db_item (
        -columns => ['SUM(FORMAT((radacct_log.acctsessiontime/60),2))|accttotaltime'],
        -from => [-join => 'radacct_log', '=>{radacct_log.acctuniqueid=radacct.acctuniqueid}', "(select acctuniqueid, callingstationid from radacct group by acctuniqueid) as radacct"],
        @_
    );
}

=item node_accounting_daily_time - view connected time today for a node, returns an array of hashrefs

=cut

sub node_accounting_daily_time {
    my ($mac) = @_;
    return _node_accounting_time(
        -where => {
            callingstationid => $mac,
            timestamp => { ">=" => \"CURRENT_DATE()" },
        },
    );
}

=item node_accounting_weekly_time - view connected time this week for a node, returns an array of hashrefs

=cut

sub node_accounting_weekly_time {
    my ($mac) = @_;
    return _node_accounting_time(
        -where => [
            -and => [
                {callingstationid => $mac},
                \"YEARWEEK(timestamp) = YEARWEEK(CURRENT_DATE())",
            ],
        ],
    );
}

=item node_accounting_monthly_time - view connected time this month for a node, returns an array of hashrefs

=cut

sub node_accounting_monthly_time {
    my ($mac) = @_;
    return _node_accounting_time(
        -where => [
            -and => [
                {callingstationid => $mac},
                \"MONTH(timestamp) = MONTH(CURRENT_DATE())",
            ],
        ],
    );
}

=item node_accounting_yearly_time - view connected time this year for a node, returns an array of hashrefs

=cut

sub node_accounting_yearly_time {
    my ($mac) = @_;
    return _node_accounting_time(
        -where => [
            -and => [
                {callingstationid => $mac},
                \"YEAR(timestamp) = YEAR(CURRENT_DATE())",
            ],
        ],
    );
}

our %INTERVAL_TO_METHOD = (
    daily => 'DAY',
    weekly => 'YEARWEEK',
    monthly => 'MONTH',
    yearly => 'YEAR',
);

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

sub cache {
    my ($class) = @_;
    return pf::CHI->new(namespace => "accounting");
}

=item _db_item

_db_item

=cut

sub _db_item {
    my (@args) = @_;
    my ($status, $iter) = pf::dal::radacct->search(
        @args,
        -with_class => undef,
        -no_auto_tenant_id => 1,
    );
    if (is_error($status)) {
        return undef;
    }
    return $iter->next;
}

=item _db_items

=cut

sub _db_items {
    my (@args) = @_;
    my ($status, $iter) = pf::dal::radacct->search(
        @args,
        -with_class => undef,
        -no_auto_tenant_id => 1,
    );
    if (is_error($status)) {
        return;
    }
    return @{$iter->all(undef) // []};
}

=head2 cleanup

Perform cleanup of the accounting tables

=cut

sub cleanup {
    my $timer = pf::StatsD::Timer->new( { sample_rate => 0.2 } );
    my ( $expire_seconds, $batch, $time_limit ) = @_;
    my $logger = get_logger();
    $logger->debug( sub { "calling accounting_cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit"; });

    if ( $expire_seconds eq "0" ) {
        $logger->debug("Not deleting because the window is 0");
        return;
    }
    my $now        = pf::dal->now();

    # Close old un-updated sessions
    my %params = (
        -set => { 
            acctstoptime => \"NOW()",
        },
        -where => {
            acctupdatetime => {
                "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ]
            },
            acctstoptime => undef,
        },
        -limit => $batch,
        -no_auto_tenant_id => 1,
    );
    pf::dal::radacct->batch_update(\%params, $time_limit);

    # Cleanup the radacct table
    %params = (
        -where => {
            acctstarttime => {
                "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ]
            },
            acctstoptime => { "!=", undef },
        },
        -limit => $batch,
        -no_auto_tenant_id => 1,
    );
    pf::dal::radacct->batch_remove(\%params, $time_limit);

    # Cleanup the radacct_log table
    %params = (
        -where => {
            timestamp => {
                "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ]
            },
        },
        -limit => $batch,
        -no_auto_tenant_id => 1,
    );
    pf::dal::radacct_log->batch_remove(\%params, $time_limit);
    return;
}

sub node_acct_maintenance_bw {
    my ($direction, $interval, $releaseDate, $bytes) = @_;
    my $field = $direction_field{$direction};
    my $date = $grouping_dates{$interval};
    my $sql = <<"SQL";
    select tenant_id, mac, SUM($field) as $field FROM (
        SELECT $date AS time_bucket, node_id, tenant_id, mac, SUM($field) AS $field FROM bandwidth_accounting WHERE time_bucket >= ? GROUP BY $date, node_id
        UNION ALL SELECT $date AS time_bucket, node_id, tenant_id, mac, SUM($field) AS $field FROM bandwidth_accounting_history WHERE time_bucket >= ? GROUP BY $date, node_id
    ) AS X GROUP BY time_bucket, node_id HAVING SUM($field) >= ?;
SQL
    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, $releaseDate, $releaseDate, $bytes);
    if (is_success($status)) {
        my $tbl_ary_ref = $sth->fetchall_arrayref({});
        $sth->finish();
        return @$tbl_ary_ref;
    }

    return;
}

sub node_acct_maintenance_bw_exists {
    my ($tenant_id, $mac, $direction, $interval, $releaseDate, $bytes) = @_;
    my $field = $direction_field{$direction};
    my $date = $grouping_dates{$interval};
    my $node_id = make_node_id($tenant_id, $mac);
    my $sql = <<"SQL";
    select tenant_id, mac FROM (
        SELECT $date AS time_bucket, tenant_id, mac, SUM($field) AS $field FROM bandwidth_accounting WHERE time_bucket >= ? AND node_id = ? GROUP BY $date
        UNION ALL SELECT $date AS time_bucket, tenant_id, mac, SUM($field) AS $field FROM bandwidth_accounting_history WHERE time_bucket >= ? AND node_id = ? GROUP BY $date
    ) AS X GROUP BY time_bucket HAVING SUM($field) >= ?;
SQL
    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, $releaseDate, $node_id, $releaseDate, $node_id, $bytes);
    if (is_success($status)) {
        my $tbl_ary_ref = $sth->fetchall_arrayref({});
        $sth->finish();
        return @$tbl_ary_ref;
    }

    return;
}

my %mac_grouping_dates = (
    daily   => 'CURDATE()',
    weekly  => 'DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)',
    monthly => 'DATE_ADD(CURDATE(),INTERVAL -DAY(CURDATE())+1 DAY)',
    yearly  => 'DATE_ADD(CURDATE(),INTERVAL -DAYOFYEAR(CURDATE())+1 DAY)',
);

sub node_accounting_bw {
    my ($mac, $interval) = @_;
    my $tenant_id = pf::config::tenant::get_tenant();
    my $date = $mac_grouping_dates{$interval};
    my $node_id = make_node_id($tenant_id, $mac);
    my $sql = <<"SQL";
    select SUM(in_bytes) AS acctinput, SUM(out_bytes) AS acctoutput, SUM(total_bytes) AS accttotal FROM (
        SELECT IFNULL(SUM(in_bytes), 0) AS in_bytes, IFNULL(SUM(out_bytes), 0) AS out_bytes, IFNULL(SUM(total_bytes), 0) AS total_bytes  FROM bandwidth_accounting WHERE time_bucket >= $date AND node_id = ?
        UNION SELECT IFNULL(SUM(in_bytes), 0) AS in_bytes, IFNULL(SUM(out_bytes), 0) AS out_bytes, IFNULL(SUM(total_bytes), 0) AS total_bytes  FROM bandwidth_accounting_history WHERE time_bucket >= $date AND node_id = ?
    ) AS X;
SQL
    my ($status, $sth) = pf::dal::bandwidth_accounting->db_execute($sql, $node_id, $node_id);
    if (is_success($status)) {
        my $tbl_ary_ref = $sth->fetchall_arrayref({});
        return $tbl_ary_ref->[0];
    }

    return
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
