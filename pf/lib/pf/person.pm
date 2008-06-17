#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::person;

use strict;
use warnings;

our ($person_modify_sql, $person_exist_sql, $person_delete_sql, $person_add_sql, 
     $person_view_sql, $person_view_all_sql, $person_nodes_sql);

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(person_db_prepare person_exist person_delete person_add person_view person_view_all person_modify person_nodes);
}

use lib qw(/usr/local/pf/lib);
use pf::config;
use pf::db;
use pf::util;

person_db_prepare($dbh) if (!$thread);

sub person_db_prepare {
  my ($dbh) = @_;
  $person_exist_sql=$dbh->prepare( qq[ select count(*) from person where pid=? ]);
  $person_add_sql=$dbh->prepare( qq[ insert into person(pid,notes) values(?,?) ]); 
  $person_delete_sql=$dbh->prepare( qq[ delete from person where pid=? ]);
  $person_modify_sql=$dbh->prepare( qq[ update person set pid=?,notes=? where pid=? ]);
  $person_view_sql=$dbh->prepare( qq[ select pid,notes from person where pid=? ]);
  $person_view_all_sql=$dbh->prepare( qq[ select pid,notes from person ]);
  $person_nodes_sql=$dbh->prepare( qq[ select mac,pid,regdate,unregdate,lastskip,status,user_agent,computername,dhcp_fingerprint from node where pid=? ]);
}

#
#
#
sub person_exist {
  my ($pid) = @_;
  $person_exist_sql->execute($pid) || return(0);
  my ($val) = $person_exist_sql->fetchrow_array();
  $person_exist_sql->finish();
  return($val);
}

#
# delete and return 1
#
sub person_delete {
  my ($pid) = @_;
  return(0) if ($pid eq "1"); 

  if (!person_exist($pid)) {
    pflogger("delete of non-existent person '$pid' failed", 2);
    return 0;
  }
                
  $person_delete_sql->execute($pid) || return(0);
  pflogger("person $pid deleted", 2);
  return(1)
}

#
# clean input parameters and add to person table
#
sub person_add {
  my ($pid,%data)=@_;
  if (person_exist($pid)) {
    pflogger("attempt to add existing person $pid", 1);
    return(2);
  }
  $person_add_sql->execute($pid,$data{'notes'}) || return(0);
  pflogger("person $pid added", 2);
  return(1);
}

#
# return row = pid
#
sub person_view {
  my ($pid) = @_;
  $person_view_sql->execute($pid) || return(0);
  my $ref = $person_view_sql->fetchrow_hashref();
  # just get one row and finish
  $person_view_sql->finish();
  return($ref);
}

sub person_view_all {
  return db_data($person_view_all_sql);
}

sub person_modify {
  my($pid,%data) = @_;
  if (!person_exist($pid)) {
    if (person_add($pid,%data)) {
      pflogger("modify of non-existent person $pid attempted - person added", 1);
      return(2);
    } else {
      pflogger("modify of non-existent person $pid attempted - person add failed", 1);
      return(0);
    }
  }
  my $existing = person_view($pid);
  foreach my $item (keys(%data)) {
    $existing->{$item} = $data{$item};
  }
  my $new_pid = $existing->{'pid'};
  my $new_notes = $existing->{'notes'};

  if ($pid ne $new_pid && person_exist($new_pid)) {
    pflogger("modify of pid $pid to $new_pid conflicts with existing person", 1);
    return(0);
  }

  $person_modify_sql->execute($new_pid, $new_notes, $pid) || return(0);
  pflogger("person $pid modified to $new_pid", 2);
  return(1);
}

sub person_nodes {
  my ($pid) = @_;
  return db_data($person_nodes_sql,$pid);
}

1
