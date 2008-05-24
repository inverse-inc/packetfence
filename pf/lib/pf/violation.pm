#
# $Id: violation.pm,v 1.3 2005/11/17 21:34:56 dgehl Exp $
#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::violation;

use strict;
use warnings;

our ($violation_desc_sql, $violation_add_sql, $violation_exist_sql, $violation_exist_open_sql,
     $violation_exist_id_sql, $violation_view_sql, $violation_view_all_sql, $violation_view_top_sql,
     $violation_view_open_sql, $violation_view_open_desc_sql, $violation_view_open_uniq_sql, $violation_view_open_all_sql,
     $violation_view_all_active_sql, $violation_close_sql, $violation_delete_sql, $violation_modify_sql,
     $violation_grace_sql, $violation_count_sql, $violation_count_vid_sql);

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(violation_force_close violation_close violation_view violation_view_all violation_view_all_active
               violation_view_open_all violation_add violation_view_open violation_view_open_desc violation_view_open_uniq violation_modify
               violation_trigger violation_count violation_view_top violation_db_prepare violation_delete violation_exist_open);
}

use lib qw(/usr/local/pf/lib);
use pf::config;
use pf::db;
use pf::util;
use pf::node qw(node_exist node_add_simple);
use pf::action qw(action_execute);
use pf::trigger qw(trigger_view_enable);
use pf::iptables qw(unmark_node);
use pf::class qw(class_view);

violation_db_prepare($dbh) if (!$thread);

sub violation_db_prepare {
  my ($dbh) = @_;
  $violation_desc_sql=$dbh->prepare( qq [ desc violation ] );
  $violation_add_sql=$dbh->prepare( qq [ insert into violation(mac,vid,start_date,release_date,status,ticket_ref,notes) values(?,?,?,?,?,?,?) ]);
  $violation_modify_sql=$dbh->prepare( qq [ update violation set mac=?,vid=?,start_date=?,release_date=?,status=?,ticket_ref=?,notes=? where id=? ]);
  $violation_exist_sql=$dbh->prepare( qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? and vid=? and start_date=? ]);
  $violation_exist_open_sql=$dbh->prepare( qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? and vid=? and status="open" order by vid asc ]);
  $violation_exist_id_sql=$dbh->prepare( qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where id=? ]);
  #$violation_view_sql=$dbh->prepare( qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? order by start_date desc ]);
  $violation_view_sql=$dbh->prepare( qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where id=? order by start_date desc ]);
  $violation_view_all_sql=$dbh->prepare( qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation ]);
  $violation_view_open_sql=$dbh->prepare( qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? and status="open" order by start_date desc ]);
  $violation_view_open_desc_sql=$dbh->prepare( qq [ select v.start_date,c.description,v.vid,v.status from violation v inner join class c on v.vid=c.vid where v.mac=? and v.status="open" order by start_date desc ]);
  $violation_view_open_uniq_sql=$dbh->prepare( qq [ select mac from violation where status="open" group by mac ]);
  $violation_view_open_all_sql=$dbh->prepare( qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where status="open" ]);
  #$violation_view_top_sql=$dbh->prepare( qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? and status="open" order by start_date desc  limit 1]);
  $violation_view_top_sql=$dbh->prepare( qq [ select id,mac,v.vid,start_date,release_date,status,ticket_ref,notes from violation v, class c where v.vid=c.vid and mac=? and status="open" order by priority desc limit 1]);
  $violation_view_all_active_sql=$dbh->prepare( qq [ select v.mac,v.vid,v.start_date,v.release_date,v.status,v.ticket_ref,v.notes,i.ip,i.start_time,i.end_time from violation v left join iplog i on v.mac=i.mac where v.status="open" and i.end_time=0 group by v.mac]);
  $violation_delete_sql=$dbh->prepare( qq [ delete from violation where id=? ]);
  $violation_close_sql=$dbh->prepare( qq [ update violation set release_date=now(),status="closed" where mac=? and vid=? and status="open" ]);
  $violation_grace_sql=$dbh->prepare( qq [ select unix_timestamp(start_date)+grace_period-unix_timestamp(now()) from violation v left join class c on v.vid=c.vid where mac=? and v.vid=? and status="closed" order by start_date desc ]);
  $violation_count_sql=$dbh->prepare( qq [ select count(*) from violation where mac=? and status="open" ]);
  $violation_count_vid_sql=$dbh->prepare( qq [ select count(*) from violation where mac=? and vid=? ]);
}

#
#
sub violation_desc {
  return db_data($violation_desc_sql);
}

#
sub violation_modify {
  my ($id,%data)=@_;
  return(0) if (!$id);
  my $existing = violation_exist_id($id);

  if (!$existing) {
    if (violation_add($data{mac},$data{vid},%data)) {
      pflogger("modify of non-existent violation $id attempted - violation added", 1);
      return(2);
    } else {
      pflogger("modify of non-existent node $data{mac} attempted - node add failed", 1);
      return(0);
    }
  }
  foreach my $item (keys(%data)) {
    $existing->{$item} = $data{$item};
  }

  pflogger("violation for mac " . $existing->{mac} . " vid " . $existing->{vid} . " modified", 2);
  $violation_modify_sql->execute($existing->{mac},$existing->{vid},$existing->{start_date},$existing->{release_date},
				 $existing->{status},$existing->{ticket_ref},$existing->{notes},$id) || return(0);
  return(1);
}

sub violation_grace {
  my ($mac, $vid) = @_;
  $violation_grace_sql->execute($mac,$vid) || return(0);
  my ($val) = $violation_grace_sql->fetchrow_array();
  $violation_grace_sql->finish();
  $val=0 if (!$val);
  return($val);
}

sub violation_count {
  my ($mac) = @_;
  $violation_count_sql->execute($mac) || return(0);
  my ($val) = $violation_count_sql->fetchrow_array();
  $violation_count_sql->finish();
  return($val);
}

sub violation_count_vid {
  my ($mac, $vid) = @_;
  $violation_count_vid_sql->execute($mac,$vid) || return(0);
  my ($val) = $violation_count_vid_sql->fetchrow_array();
  $violation_count_vid_sql->finish();
  return($val);
}

sub violation_exist {
  my ($mac, $vid, $start_date) = @_;
  $violation_exist_sql->execute($mac,$vid,$start_date) || return(0);
  my $val = $violation_exist_sql->fetchrow_hashref();
  $violation_exist_sql->finish();
  return($val);
}

sub violation_exist_id {
  my ($id) = @_;
  $violation_exist_id_sql->execute($id) || return(0);
  my $val = $violation_exist_id_sql->fetchrow_hashref();
  $violation_exist_id_sql->finish();
  return($val);
}

sub violation_exist_open {
  my ($mac, $vid) = @_;
  $violation_exist_open_sql->execute($mac,$vid) || return(0);
  my ($val) = $violation_exist_open_sql->fetchrow_array();
  $violation_exist_open_sql->finish();
  return($val);
}

sub violation_view {
  my ($id) = @_;
  return db_data($violation_view_sql,$id);
}

sub violation_view_all {
  return db_data($violation_view_all_sql);
}

sub violation_view_top {
  my ($mac) = @_;
  $violation_view_top_sql->execute($mac) || return(0);
  my $ref = $violation_view_top_sql->fetchrow_hashref(); 
  $violation_view_top_sql->finish();
  return($ref);
}

sub violation_view_open {
  my ($mac) = @_;
  return db_data($violation_view_open_sql,$mac);
}

sub violation_view_open_desc {
  my ($mac) = @_;
  return db_data($violation_view_open_desc_sql,$mac);
}

sub violation_view_open_uniq {
  return db_data($violation_view_open_uniq_sql);
}

sub violation_view_open_all {
  return db_data($violation_view_open_all_sql);
}

sub violation_view_all_active {
  return db_data($violation_view_all_active_sql);
}

#
sub violation_add  {
  my ($mac,$vid,%data) = @_;
  return(0) if (!$vid);
  #print Dumper(%data);
  #defaults
  $data{start_date}=mysql_date() if (!defined $data{start_date} || !$data{start_date});
  $data{release_date}=0 if (!defined $data{release_date});
  $data{status}="open" if (!defined $data{status} || !$data{status});
  $data{notes}="" if (!defined $data{notes});
  $data{ticket_ref}="" if (!defined $data{ticket_ref});

  # Is this MAC and ID aready in DB?  if so don't add another
  if (violation_exist_open($mac, $vid)) {
    pflogger("violation $vid already exists for $mac",4);
    return(1);
  }

  my $latest_violation = (violation_view_open($mac))[0];
  my $latest_vid = $latest_violation->{'vid'};
  if($latest_vid) {
    # don't add a hostscan if violation exists
    if ($vid == $portscan_sid) {
      pflogger("hostscan detected from $mac, but violation $latest_vid exists - ignoring",2);
      return(1);
    }
    #replace UNKNOWN hostscan with known violation
    if ($latest_vid == $portscan_sid) {
      pflogger("violation $vid detected for $mac - updating existing hostscan entry",2);
      violation_force_close($mac,$portscan_sid);
    }
  }

  #  has this mac registered if not register for violation?
  if (!node_exist($mac)) {
    node_add_simple($mac);
  } else {
    # not a new violation check violation
    my ($remaining_time) = violation_grace($mac, $vid);
    if ($remaining_time > 0) {
      pflogger("$remaining_time grace remaining on violation $vid for node $mac",4);
      return(1);
    } else {
      pflogger("grace expired on violation $vid for node $mac",2);
    }
  }

  # insert violation into db
  $violation_add_sql->execute($mac,$vid,$data{start_date},$data{release_date},$data{status},$data{ticket_ref},$data{notes}) || return(0);
  pflogger("violation $vid added for $mac",2);
  action_execute($mac, $vid);
  return(1);
}

sub violation_trigger {
  my ($mac,$tid,$type,%data) = @_;
  return(0) if (!$tid);
  $type=lc($type);

  my @trigger_info=trigger_view_enable($tid,$type);
  if (!scalar(@trigger_info)) {
    pflogger("violation not added, no trigger found for ${type}::${tid} or violation is disabled",12);
  }
  foreach my $row (@trigger_info){
    violation_add($mac,$row->{'vid'},%data);
  }
}

sub violation_delete {
  my ($id)=@_;
  $violation_delete_sql->execute($id) || return(0); 
  return(0);
}

#return -1 on failure, because grace=0 is unlimited
#
sub violation_close {
  my ($mac,$vid) = @_;

  my $class_info = class_view($vid);
  # check auto_enable = 'N'
  if ($class_info->{'auto_enable'} =~ /^N$/i) {
    return(-1);
  }

  #check the number of violations
  my $num = violation_count_vid($mac,$vid);
  my $max  = $class_info->{'max_enables'};

  if ($num <= $max || $max == 0) {
    unmark_node($mac, $vid);
    my $grace = $class_info->{'grace_period'};
    $violation_close_sql->execute($mac,$vid) || return(0);
    pflogger("violation $vid closed for $mac",2);
    return($grace);
  }
  return(-1);
}

# use force close on non-trap violations
#
sub violation_force_close {
  my ($mac,$vid) = @_;
  #unmark_node($mac, $vid);
  $violation_close_sql->execute($mac,$vid) || return(0);
  pflogger("violation $vid closed for $mac since it's a non-trap violation",2);
  return(1);
} 

1
