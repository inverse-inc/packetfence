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

our (
  $traplog_cleanup_sql,

  $traplog_insert_sql,

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
               );
}

use lib qw(/usr/local/pf/lib);
use pf::db;

$traplog_db_prepared = 0;

sub traplog_db_prepare {
  my ($dbh) = @_;
  db_connect($dbh);
  my $logger = Log::Log4perl::get_logger('pf::traplog');
  $logger->info("Preparing pf::traplog database queries");

  $traplog_insert_sql=$dbh->prepare( qq [ INSERT INTO traplog (switch, ifIndex, parseTime, `type`) VALUES(?,?,NOW(),?) ]);

  $traplog_cleanup_sql=$dbh->prepare( qq [ delete from traplog where parseTime < from_unixtime(unix_timestamp(now()) - ?) ]);
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

1

