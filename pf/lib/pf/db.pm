#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::db;

use strict;
use warnings;
use DBD::mysql;
use File::Basename;
use Log::Log4perl;
use threads;

our ($dbh,%last_connect);

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw($dbh db_data db_connect db_disconnect);
}

END {
     $dbh->disconnect() if $dbh;
}

use lib qw(/usr/local/pf/lib);
use pf::config;

#$dbh = db_connect() if (!threads->self->tid);

sub db_connect {
  my ($mydbh,@function_list) = @_;
  my $logger = Log::Log4perl::get_logger('pf::db');
  $mydbh=0 if (!defined $mydbh);
  my $caller = (caller(1))[3] || basename($0);
  $logger->debug("function $caller is calling db_connect");

  my $tid = threads->self->tid;
  $mydbh=$dbh if (!$tid  && defined $dbh);

  if (defined($last_connect{$tid}) && $last_connect{$tid} && (time() - $last_connect{$tid} < 30) && $mydbh) {
    $logger->debug("not checking db handle, it has less then 300 sec from last time");
    return $mydbh;
  } 
  $logger->debug("checking handle");

  if ($mydbh && $mydbh->ping()){
    $last_connect{$tid} = time();
    $logger->debug("we are currently connected");
    return $mydbh;
  }

  $logger->debug("Connecting $mydbh from $tid db connection is DEAD (re)connecting");

  my $host = $Config{'database'}{'host'};
  my $port = $Config{'database'}{'port'};
  my $user = $Config{'database'}{'user'};
  my $pass = $Config{'database'}{'pass'};
  my $db   = $Config{'database'}{'db'};

  $mydbh = DBI->connect("dbi:mysql:dbname=$db;host=$host;port=$port",$user,$pass, {RaiseError => 0});
 
  # make sure we have a database handle
  if ($mydbh) {
    $logger->debug("connected");
    $last_connect{$tid} = time() if $mydbh;
    $dbh=$mydbh if (!$tid);
    foreach my $function (@function_list){
      $function.="_db_prepare";
      $logger->info("db preparing $function");
      ($main::{$function} or sub { print "No such sub: $_\n" })->($mydbh);
     }
    $_[0]=$mydbh;
    return($mydbh);
  } else {
    $logger->logdie("ERROR: unable to connect to database!");
    return();
  }
}

sub db_disconnect {
}

sub db_data {
  my ($db_handle,@value)=@_;
  if (@value){
     $db_handle->execute(@value) || return(0);
  }else{
     $db_handle->execute() || return(0);
  }
  my ($ref,@array);
  while ( $ref = $db_handle->fetchrow_hashref() ) {
    push(@array,$ref);
  }
  $db_handle->finish();
  return(@array);
}


1
