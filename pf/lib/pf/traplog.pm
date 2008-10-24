#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
# Copyright 2008 Inverse groupe conseil <dgehl@inverse.ca>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::traplog;

use strict;
use warnings;
use Log::Log4perl;
use Log::Log4perl::Level;
use RRDs;

our (
  $traplog_cleanup_sql,

  $traplog_insert_sql,

  $traplog_first_TimeStamp_sql,
  $traplog_all_switches_sql,
  $traplog_type_count_sql,
  $traplog_switch_type_count_sql,
  $traplog_switches_with_most_traps_sql,
  $traplog_switches_with_most_traps_date_sql,

  $traplog_db_prepared
);

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(
               traplog_db_prepare
               
               traplog_cleanup 

               traplog_insert

               traplog_get_first_timestamp
               traplog_get_all_switches
               traplog_get_type_count
               traplog_get_switch_type_count
               traplog_get_switches_with_most_traps

               traplog_update_rrd
               );
}

use lib qw(/usr/local/pf/lib);
use pf::config;
use pf::db;

$traplog_db_prepared = 0;

sub traplog_db_prepare {
  my ($dbh) = @_;
  db_connect($dbh);
  my $logger = Log::Log4perl::get_logger('pf::traplog');
  $logger->info("Preparing pf::traplog database queries");

  $traplog_insert_sql=$dbh->prepare( qq [ INSERT INTO traplog (switch, ifIndex, parseTime, `type`) VALUES(?,?,NOW(),?) ]);

  $traplog_cleanup_sql=$dbh->prepare( qq [ delete from traplog where parseTime < from_unixtime(unix_timestamp(now()) - ?) ]);

  $traplog_first_TimeStamp_sql=$dbh->prepare( qq [ SELECT unix_timestamp(parseTime) AS firstInsert FROM traplog ORDER BY parseTime ASC LIMIT 1 ] );
  $traplog_all_switches_sql=$dbh->prepare( qq [ SELECT distinct switch FROM traplog ] );
  $traplog_type_count_sql = $dbh->prepare( qq[ select `type`, count(*) as nb from traplog where parseTime >= from_unixtime(?) and parseTime < from_unixtime(?) group by `type` ]);
  $traplog_switch_type_count_sql = $dbh->prepare( qq[ select switch, `type`, count(*) as nb from traplog where parseTime >= from_unixtime(?) and parseTime < from_unixtime(?) group by switch, `type` ]);
  $traplog_switches_with_most_traps_sql = $dbh->prepare( qq [ select switch, count(*) as nb from traplog group by switch order by nb DESC limit ? ]);
  $traplog_switches_with_most_traps_date_sql = $dbh->prepare( qq [ select switch, count(*) as nb from traplog where parseTime >= from_unixtime(?) group by switch order by nb DESC limit ? ]);

  $traplog_db_prepared = 1;
}

sub traplog_insert {
  my ($switch,$ifIndex,$type) = @_;
  traplog_db_prepare($dbh) if (! $traplog_db_prepared);
  $traplog_insert_sql->execute($switch,$ifIndex,$type) || return(0);
  return(1);
}

sub traplog_cleanup {
  my ($time) = @_;
  my $logger = Log::Log4perl::get_logger('pf::traplog');
  traplog_db_prepare($dbh) if (! $traplog_db_prepared);
  $logger->debug("calling traplog_cleanup with time=$time");
  $traplog_cleanup_sql->execute($time) || return(0);
  my $rows = $traplog_cleanup_sql->rows;
  $logger->log((($rows > 0) ? $INFO : $DEBUG), "deleted $rows entries from traplog during traplog cleanup");
  return(0);
}

sub traplog_get_first_timestamp {
  my $logger = Log::Log4perl::get_logger('pf::traplog');
  traplog_db_prepare($dbh) if (! $traplog_db_prepared);
  $traplog_first_TimeStamp_sql->execute();
  if (my $ref = $traplog_first_TimeStamp_sql->fetchrow_hashref()) {
    $logger->debug("returning first timestamp (" . $ref->{'firstInsert'} . ") from traplog table");
    $traplog_first_TimeStamp_sql->finish();
    return $ref->{'firstInsert'};
  } else {
    $logger->info("traplog table doesn't have any entries.");
    return 0;
  }
}

sub traplog_get_all_switches {
  traplog_db_prepare($dbh) if (! $traplog_db_prepared);
  my @switches;
  $traplog_all_switches_sql->execute() || return @switches;
  while (my $row = $traplog_all_switches_sql->fetchrow_hashref()) {
    push @switches, $row->{'switch'};
  }
  $traplog_all_switches_sql->finish();
  return @switches;
}

sub traplog_get_type_count {
  my ($startTime) = @_;
  traplog_db_prepare($dbh) if (! $traplog_db_prepared);
  my $traplog_type_count = { 'total' => 0,
                             'up' => 0,
                             'down' => 0,
                             'mac' => 0,
                             'secureMacAddrViolation' => 0,
                             'reAssignVlan' => 0
                           };
  $traplog_type_count_sql->execute($startTime,$startTime+300) || return $traplog_type_count;
  while (my $ref = $traplog_type_count_sql->fetchrow_hashref()) {
    $traplog_type_count->{$ref->{'type'}} = $ref->{'nb'};
    $traplog_type_count->{'total'} += $ref->{'nb'};
  }
  $traplog_type_count_sql->finish();
  return $traplog_type_count;
}

sub traplog_get_switch_type_count {
  my ($startTime, @switches) = @_;
  my $logger = Log::Log4perl::get_logger('pf::traplog');
  traplog_db_prepare($dbh) if (! $traplog_db_prepared);
  my $traplog_switch_type_count = {};
  foreach my $switch (@switches) {
    $traplog_switch_type_count->{$switch} = {
                             'total' => 0,
                             'up' => 0,
                             'down' => 0,
                             'mac' => 0,
                             'secureMacAddrViolation' => 0,
                             'reAssignVlan' => 0
                           };
  }
  $traplog_switch_type_count_sql->execute($startTime,$startTime+300) || return $traplog_switch_type_count;
  while (my $ref = $traplog_switch_type_count_sql->fetchrow_hashref()) {
    $traplog_switch_type_count->{$ref->{'switch'}}->{$ref->{'type'}} = $ref->{'nb'};
    $traplog_switch_type_count->{$ref->{'switch'}}->{'total'} += $ref->{'nb'};
  }
  $traplog_switch_type_count_sql->finish();
  return $traplog_switch_type_count;
}

sub traplog_update_rrd {
  my $logger = Log::Log4perl::get_logger('pf::traplog');
  my $rrdDir = $install_dir . "/var/rrd";
  my $htmlDir = $install_dir . "/html/admin/traplog";

  my $startTime = traplog_get_first_timestamp() || time();
  $startTime = int($startTime/300)*300 + 300;
  my $lastStartTime = int(time()/300)*300 - 300;
  $logger->debug("startTime is $startTime; lastStartTime is $lastStartTime");

  #is this the first RRD run ? 
  #if it is we'll have to import ALL entries from the traplog database table
  #otherwise we'll just have to import the last 5 minutes
  my $firstRun = ((-e "$rrdDir/total.rrd") ? 0 : 1);
  $logger->debug("firstRun is $firstRun");

  #obtain all switches
  my @switches = traplog_get_all_switches();
  $logger->info("updating rrd files for " . scalar(@switches) . " switches");

  #create RRD files (when necessary)
  create_missing_RRDs($rrdDir, $startTime-1, @switches);
  fill_RRDs($rrdDir, $startTime, $lastStartTime, $firstRun, @switches);
  generate_graphs($rrdDir, $htmlDir, $startTime, $lastStartTime, @switches);
}

sub create_missing_RRDs {
  my ($rrdDir, $startTime, @switches) = @_;
  my $logger = Log::Log4perl::get_logger('pf::traplog');
  push @switches, "total";
  foreach my $switch (@switches) {
    if (! -e "$rrdDir/$switch.rrd") {
      $logger->info("creating $rrdDir/$switch.rrd");
      RRDs::create(
                   "$rrdDir/$switch.rrd",
                   "--start=$startTime",
                   "DS:total:ABSOLUTE:600:U:U",
                   "DS:down:ABSOLUTE:600:U:U",
                   "DS:up:ABSOLUTE:600:U:U",
                   "DS:mac:ABSOLUTE:600:U:U",
                   "DS:secure:ABSOLUTE:600:U:U",
                   "DS:reAssign:ABSOLUTE:600:U:U",
                   "RRA:AVERAGE:0.5:1:600",
                   "RRA:AVERAGE:0.5:6:700",
                   "RRA:AVERAGE:0.5:24:775",
                   "RRA:AVERAGE:0.5:228:797"
      );
    }
  }
}

sub traplog_get_switches_with_most_traps {
  my ($nb, %params) = @_;
  my $timeSpan = $params{'timespan'};
  my $logger = Log::Log4perl::get_logger('pf::traplog');
  traplog_db_prepare($dbh) if (! $traplog_db_prepared);
  if ($timeSpan =~ /total/) {
    return db_data($traplog_switches_with_most_traps_sql,$nb);
  } else {
    my $startTime = 0;
    if ($timeSpan =~ /day/) {
      $startTime = time() - 24*60*60;
    } elsif ($timeSpan =~ /week/) {
      $startTime = time() - 7*24*60*60;
    }
    return db_data($traplog_switches_with_most_traps_date_sql,$startTime,$nb);
  }
}

sub fill_RRDs {
  my ($rrdDir, $startTime, $lastStartTime, $firstRun, @switches) = @_;
  my $logger = Log::Log4perl::get_logger('pf::traplog');
  #do we have to start at the beginning or do we only need to read 
  #the last 5 min interval ?
  my $tmpTime = (($firstRun) ? $startTime : $lastStartTime);
  $logger->info("updating rrd files from $tmpTime up tp $lastStartTime");
  while ($tmpTime <= $lastStartTime) {
    my $traplog_type_count = traplog_get_type_count($tmpTime);
    RRDs::update("$rrdDir/total.rrd", "--template", "total:down:up:mac:secure:reAssign", "$tmpTime:$traplog_type_count->{'total'}:$traplog_type_count->{'down'}:$traplog_type_count->{'up'}:$traplog_type_count->{'mac'}:$traplog_type_count->{'secureMacAddrViolation'}:$traplog_type_count->{'reAssignVlan'}");
    if (RRDs::error) {
      $logger->error("RRD error: " . RRDs::error);
    }
    my $traplog_switch_type_count = traplog_get_switch_type_count($tmpTime, @switches);
    foreach my $switch (@switches) {
      RRDs::update("$rrdDir/$switch.rrd", "--template", "total:down:up:mac:secure:reAssign", "$tmpTime:$traplog_switch_type_count->{$switch}->{'total'}:$traplog_switch_type_count->{$switch}->{'down'}:$traplog_switch_type_count->{$switch}->{'up'}:$traplog_switch_type_count->{$switch}->{'mac'}:$traplog_switch_type_count->{$switch}->{'secureMacAddrViolation'}:$traplog_switch_type_count->{$switch}->{'reAssignVlan'}");
      if (RRDs::error) {
        $logger->error("RRD error: " . RRDs::error);
      }
    }
    $tmpTime +=300;
  }
}

sub generate_graphs {
  my ($rrdDir, $htmlDir, $startTime, $lastStartTime, @switches) = @_;
  my $logger = Log::Log4perl::get_logger('pf::traplog');
  push @switches, "total";

  my $graphTypes = { 'total' => { 'titleAdd' => '', 'startTime' => $startTime },
                 'week' => { 'titleAdd' => ' (last 7 days)', 'startTime' => $lastStartTime - 7*24*60*60 },
                 'day' => {'titleAdd' => ' (last 24 hours)', 'startTime' => $lastStartTime - 24*60*60 }
  };

  foreach my $switch (@switches) {
    my $title = $switch;
    if ($title eq 'total') {
      $title = 'All switches';
    }
    foreach my $currentGraphType (keys %$graphTypes) {
      my $currentTitle .= $title . $graphTypes->{$currentGraphType}->{'titleAdd'};
      my $currentStartTime = $graphTypes->{$currentGraphType}->{'startTime'};
      RRDs::graph("$htmlDir/${switch}_$currentGraphType.png",
                  "--title=$currentTitle", 
                  "--height=150",
                  "--width=250",
                  "--start=$currentStartTime",
                  "--vertical-label=traps / min",
                  "--upper-limit=1",
                  "DEF:total=$rrdDir/$switch.rrd:total:AVERAGE",
                  "CDEF:realtotal=total,60,*",
                  "DEF:up=$rrdDir/$switch.rrd:up:AVERAGE",
                  "CDEF:realup=up,60,*",
                  "DEF:down=$rrdDir/$switch.rrd:down:AVERAGE",
                  "CDEF:realdown=down,60,*",
                  "CDEF:realLinkChange=realup,realdown,+",
                  "DEF:mac=$rrdDir/$switch.rrd:mac:AVERAGE",
                  "CDEF:realmac=mac,60,*",
                  "DEF:secure=$rrdDir/$switch.rrd:secure:AVERAGE",
                  "CDEF:realsecure=secure,60,*",
                  "DEF:reAssign=$rrdDir/$switch.rrd:reAssign:AVERAGE",
                  "CDEF:realreAssign=reAssign,60,*",
                  "AREA:realtotal#AAAAAA:total",
                  "LINE1:realLinkChange#00FF00:up/down",
                  "LINE1:realmac#0000FF:mac",
                  "LINE1:realsecure#00FFFF:secure");
      if (RRDs::error) {
        $logger->error("RRD error: " . RRDs::error);
      }
    }
  }
}

1

