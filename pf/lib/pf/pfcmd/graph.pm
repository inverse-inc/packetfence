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

use lib qw(/usr/local/pf/lib);
use pf::db;

use vars qw/$graph_registered_day_sql $graph_registered_month_sql $graph_registered_year_sql
            $graph_unregistered_day_sql $graph_unregistered_month_sql $graph_unregistered_year_sql
            $graph_violations_day_sql $graph_violations_month_sql $graph_violations_year_sql
            $graph_nodes_day_sql  $graph_nodes_month_sql  $graph_nodes_year_sql $graph_db_prepared /;

$graph_db_prepared = 0;

sub graph_db_prepare {
  my ($dbh) = @_;
  db_connect($dbh);
  $graph_registered_day_sql   = $dbh->prepare( qq [ SELECT 'registered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(regdate,"%Y/%m/%d") <= mydate AND regdate!=0) as count FROM  (SELECT DISTINCT DATE_FORMAT(regdate,"%Y/%m/%d") AS mydate FROM node) as tmp order by mydate ]);
  $graph_registered_month_sql = $dbh->prepare( qq [ SELECT 'registered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(regdate,"%Y/%m") <= mydate AND regdate!=0) as count FROM  (SELECT DISTINCT DATE_FORMAT(regdate,"%Y/%m") AS mydate FROM node) as tmp order by mydate ]);
  $graph_registered_year_sql  = $dbh->prepare( qq [ SELECT 'registered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(regdate,"%Y") <= mydate AND regdate!=0) as count FROM  (SELECT DISTINCT DATE_FORMAT(regdate,"%Y") AS mydate FROM node) as tmp order by mydate ]);

  $graph_unregistered_day_sql   = $dbh->prepare( qq [ SELECT 'unregistered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(detect_date,"%Y/%m/%d") <= mydate AND (DATE_FORMAT(regdate,"%Y/%m/%d") >= mydate OR regdate=0) ) AS count FROM (SELECT DISTINCT DATE_FORMAT(detect_date,"%Y/%m/%d") AS mydate FROM node) as tmp group by mydate order by mydate ]);
  $graph_unregistered_month_sql = $dbh->prepare( qq [ SELECT 'unregistered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(detect_date,"%Y/%m") <= mydate AND (DATE_FORMAT(regdate,"%Y/%m") >= mydate OR regdate=0) ) AS count FROM (SELECT DISTINCT DATE_FORMAT(detect_date,"%Y/%m") AS mydate FROM node) as tmp group by mydate order by mydate ]);
  $graph_unregistered_year_sql  = $dbh->prepare( qq [ SELECT 'unregistered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(detect_date,"%Y") <= mydate AND (DATE_FORMAT(regdate,"%Y") >= mydate OR regdate=0) ) AS count FROM (SELECT DISTINCT DATE_FORMAT(detect_date,"%Y") AS mydate FROM node) as tmp group by mydate order by mydate ]);

  $graph_violations_day_sql   = $dbh->prepare( qq [ SELECT mydate, (SELECT COUNT(*) FROM violation WHERE vid=myvid AND DATE_FORMAT(start_date,"%Y/%m/%d") <= mydate AND (DATE_FORMAT(release_date,"%Y/%m/%d") >= mydate OR release_date=0) ) AS count,description as series FROM (SELECT DISTINCT DATE_FORMAT(start_date,"%Y/%m/%d") AS mydate, v.vid as myvid,c.description FROM violation v,class c) as tmp group by myvid, mydate order by mydate ]);
  $graph_violations_month_sql = $dbh->prepare( qq [ SELECT mydate, (SELECT COUNT(*) FROM violation WHERE vid=myvid AND DATE_FORMAT(start_date,"%Y/%m") <= mydate AND (DATE_FORMAT(release_date,"%Y/%m") >= mydate OR release_date=0) ) AS count,description as series FROM (SELECT DISTINCT DATE_FORMAT(start_date,"%Y/%m") AS mydate, v.vid as myvid,c.description FROM violation v,class c) as tmp group by myvid, mydate order by mydate ]);
  $graph_violations_year_sql  = $dbh->prepare( qq [ SELECT mydate, (SELECT COUNT(*) FROM violation WHERE vid=myvid AND DATE_FORMAT(start_date,"%Y") <= mydate AND (DATE_FORMAT(release_date,"%Y") >= mydate OR release_date=0) ) AS count,description as series FROM (SELECT DISTINCT DATE_FORMAT(start_date,"%Y") AS mydate, v.vid as myvid,c.description FROM violation v,class c) as tmp group by myvid, mydate order by mydate ]);


# graph_activity_current
# graph_nodes_current
# graph_violations_current
  $graph_db_prepared = 1;
}

sub graph_unregistered {
  my ($interval) = @_;
  graph_db_prepare($dbh) if (! $graph_db_prepared);
  my $graph = "graph_unregistered_".$interval."_sql";
  no strict 'refs';
  return (db_data($$graph));
}

sub graph_registered {
  my ($interval) = @_;
  graph_db_prepare($dbh) if (! $graph_db_prepared);
  my $graph = "graph_registered_".$interval."_sql";
  no strict 'refs';
  return (db_data($$graph));
}

sub graph_violations {
  my ($interval) = @_;
  graph_db_prepare($dbh) if (! $graph_db_prepared);
  my $graph = "graph_violations_".$interval."_sql";
  no strict 'refs';
  return (db_data($$graph));
}

sub graph_nodes {
  my ($interval) = @_;
  graph_db_prepare($dbh) if (! $graph_db_prepared);
  no strict 'refs';
  my $graph = "graph_registered_".$interval."_sql";
  my @return = db_data($$graph);
  $graph = "graph_unregistered_".$interval."_sql";
  push(@return, db_data($$graph));
  return(sort { $a->{'mydate'} cmp $b->{'mydate'} } @return);
  #return(@return);
}

1
