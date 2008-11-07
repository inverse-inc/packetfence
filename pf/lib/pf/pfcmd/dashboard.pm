#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

use strict;
use warnings;
use Log::Log4perl;

use pf::db;
use pf::pfcmd::report;

use vars qw/$nugget_recent_violations_sql $nugget_recent_violations_opened_sql $nugget_current_grace_sql
            $nugget_recent_violations_closed_sql $nugget_recent_registrations_sql $is_dashboard_db_prepared /;

$is_dashboard_db_prepared = 0;
#dashboard_db_prepare($dbh);

sub dashboard_db_prepare {
  my ($dbh) = @_;
  db_connect($dbh);
  my $logger = Log::Log4perl::get_logger('pf::pfcmd::dashboard');
  $logger->info("Preparing pf::pfcmd::dashboard database queries");
  $nugget_recent_violations_sql = $dbh->prepare( qq [ select v.mac,v.start_date,c.description as violation from violation v left join class c on v.vid=c.vid where unix_timestamp(start_date) > unix_timestamp(now()) - ? * 3600 order by start_date desc limit 10 ]);
  $nugget_recent_violations_opened_sql = $dbh->prepare( qq [ select v.mac,v.start_date,c.description as violation from violation v left join class c on v.vid=c.vid where unix_timestamp(start_date) > unix_timestamp(now()) - ? * 3600 and v.status="open" order by start_date desc limit 10 ]);
  $nugget_recent_violations_closed_sql = $dbh->prepare( qq [ select v.mac,v.start_date,c.description as violation from violation v left join class c on v.vid=c.vid where unix_timestamp(start_date) > unix_timestamp(now()) - ? * 3600 and v.status="closed" order by start_date desc limit 10 ]);
  #$nugget_recent_registrations_sql = $dbh->prepare( qq [ select n.pid,n.mac,n.regdate from node n where n.status="unreg" limit 10 ]);
  $nugget_recent_registrations_sql = $dbh->prepare( qq [ select n.pid,n.mac,n.regdate from node n where n.status="reg" and unix_timestamp(regdate) > unix_timestamp(now()) - ? * 3600 order by regdate desc limit 10 ]);
  $nugget_current_grace_sql = $dbh->prepare( qq [ select n.pid,n.lastskip from node n where status="grace" order by n.lastskip desc limit 10 ]);
  $is_dashboard_db_prepared = 1;
}

sub nugget_recent_violations {
  my ($interval) = @_;
  dashboard_db_prepare($dbh) if (! $is_dashboard_db_prepared);
  return db_data($nugget_recent_violations_sql, $interval);
}

sub nugget_recent_violations_opened {
  my ($interval) = @_;
  dashboard_db_prepare($dbh) if (! $is_dashboard_db_prepared);
  return db_data($nugget_recent_violations_opened_sql, $interval);
}

sub nugget_recent_violations_closed {
  my ($interval) = @_;
  dashboard_db_prepare($dbh) if (! $is_dashboard_db_prepared);
  return db_data($nugget_recent_violations_closed_sql, $interval);
}

sub nugget_recent_registrations {
  my ($interval) = @_;
  dashboard_db_prepare($dbh) if (! $is_dashboard_db_prepared);
  return db_data($nugget_recent_registrations_sql, $interval);
}

sub nugget_current_grace {
  dashboard_db_prepare($dbh) if (! $is_dashboard_db_prepared);
  return db_data($nugget_current_grace_sql);
}

sub nugget_current_activity {
  my @return;
  push(@return, { "type" => "Active Nodes", "total" => scalar(report_active_all()) } );
  push(@return, { "type" => "Inactive Nodes", "total" => scalar(report_inactive_all()) } );
  return(@return);
}

sub nugget_current_node_status {
  my @return;
  push(@return, { "type" => "Active Unregistered Nodes", "total" => scalar(report_unregistered_active()) } );
  push(@return, { "type" => "Active Registered Nodes", "total" => scalar(report_registered_active()) } );
  return(@return);
}

1
