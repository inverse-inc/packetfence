#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
# Copyright 2007-2008 Inverse groupe conseil <dgehl@inverse.ca>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::locationlog;

use strict;
use warnings;
use Log::Log4perl;
use Log::Log4perl::Level;
use Net::MAC;

our (
  $locationlog_history_mac_sql,
  $locationlog_history_switchport_sql,
  
  $locationlog_history_mac_date_sql, 
  $locationlog_history_switchport_date_sql,
  
  $locationlog_view_all_sql,
  $locationlog_view_open_sql,
  $locationlog_view_open_mac_sql,
  $locationlog_view_open_switchport_sql,
  $locationlog_view_open_switchport_no_VoIP_sql,
  $locationlog_view_open_switchport_only_VoIP_sql,

  $locationlog_close_sql,

  $locationlog_cleanup_sql,

  $locationlog_insert_start_with_mac_sql,
  $locationlog_node_update_location_sql,
  $locationlog_insert_start_no_mac_sql,
  $locationlog_update_end_switchport_sql,
  $locationlog_update_end_switchport_no_VoIP_sql,
  $locationlog_update_end_switchport_only_VoIP_sql,
  $locationlog_update_end_mac_sql,

  $locationlog_db_prepared
);

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(
               locationlog_db_prepare
               
               locationlog_history_mac
               locationlog_history_switchport
               
               locationlog_view_all
               locationlog_view_all_open_mac
               locationlog_view_open
               locationlog_view_open_mac
               locationlog_view_open_switchport
               locationlog_view_open_switchport_no_VoIP
               locationlog_view_open_switchport_only_VoIP

               locationlog_close_all
               locationlog_cleanup

               locationlog_insert_start
               locationlog_update_end
               locationlog_update_end_mac
	       locationlog_update_end_switchport_no_VoIP
	       locationlog_update_end_switchport_only_VoIP
               locationlog_synchronize
               );
}

use lib qw(/usr/local/pf/lib);
use pf::db;
use pf::node;

$locationlog_db_prepared = 0;
#locationlog_db_prepare($dbh) if (!$thread);

sub locationlog_db_prepare {
  my ($dbh) = @_;
  db_connect($dbh);
  my $logger = Log::Log4perl::get_logger('pf::locationlog');
  $logger->info("Preparing pf::locationlog database queries");
  $locationlog_history_mac_sql=$dbh->prepare( qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where mac=? order by start_time desc, isnull(end_time) desc, end_time desc ]);
  $locationlog_history_switchport_sql=$dbh->prepare( qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where switch=? and port=? order by start_time desc, isnull(end_time) desc, end_time desc ]);
  
  $locationlog_history_mac_date_sql=$dbh->prepare( qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where mac=? and start_time < from_unixtime(?) and (end_time > from_unixtime(?) or isnull(end_time)) order by start_time desc, isnull(end_time) desc, end_time desc ]);
  $locationlog_history_switchport_date_sql=$dbh->prepare( qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where switch=? and port=? and start_time < from_unixtime(?) and (end_time > from_unixtime(?) or isnull(end_time)) order by start_time desc, isnull(end_time) desc, end_time desc ]);
  
  $locationlog_view_all_sql=$dbh->prepare( qq [ select mac,switch,port,vlan,start_time,end_time from locationlog order by start_time desc, end_time desc]);
  $locationlog_view_open_sql=$dbh->prepare( qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where isnull(end_time) or end_time=0 order by start_time desc ]);
  $locationlog_view_open_mac_sql=$dbh->prepare( qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where mac=? and (isnull(end_time) or end_time=0) order by start_time desc]);   
  $locationlog_view_open_switchport_sql=$dbh->prepare( qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where switch=? and port=? and (isnull(end_time) or end_time = 0) order by start_time desc]);
  $locationlog_view_open_switchport_no_VoIP_sql=$dbh->prepare( qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where switch=? and port=? and vlan!='VoIP' and (isnull(end_time) or end_time = 0) order by start_time desc]);
  $locationlog_view_open_switchport_only_VoIP_sql=$dbh->prepare( qq [ select mac,switch,port,vlan,start_time,end_time from locationlog where switch=? and port=? and vlan='VoIP' and (isnull(end_time) or end_time = 0) order by start_time desc]);

  $locationlog_insert_start_no_mac_sql=$dbh->prepare( qq [ INSERT INTO locationlog (mac, switch, port, vlan, start_time) VALUES(NULL,?,?,?,NOW())]);
  $locationlog_insert_start_with_mac_sql=$dbh->prepare( qq [ INSERT INTO locationlog (mac, switch, port, vlan, start_time) VALUES(?,?,?,?,NOW())]);
  $locationlog_node_update_location_sql=$dbh->prepare( qq [ UPDATE node SET switch=?, port=? WHERE mac=? ]);
  $locationlog_update_end_switchport_sql=$dbh->prepare( qq [ UPDATE locationlog SET end_time = now() WHERE switch = ? AND port = ? AND (ISNULL(end_time) or end_time = 0) ]);
  $locationlog_update_end_switchport_no_VoIP_sql=$dbh->prepare( qq [ UPDATE locationlog SET end_time = now() WHERE switch = ? AND port = ? AND vlan!='VoIP' AND (ISNULL(end_time) or end_time = 0) ]);
  $locationlog_update_end_switchport_only_VoIP_sql=$dbh->prepare( qq [ UPDATE locationlog SET end_time = now() WHERE switch = ? AND port = ? AND vlan='VoIP' AND (ISNULL(end_time) or end_time = 0) ]);
  $locationlog_update_end_mac_sql=$dbh->prepare( qq [ UPDATE locationlog SET end_time = now() WHERE mac = ? AND (ISNULL(end_time) or end_time = 0)]);

  $locationlog_close_sql=$dbh->prepare( qq [ UPDATE locationlog SET end_time = now() WHERE (ISNULL(end_time) or end_time = 0)]);

  $locationlog_cleanup_sql=$dbh->prepare( qq [ delete from locationlog where unix_timestamp(end_time) < (unix_timestamp(now()) - ?) and end_time != 0 ]);
  $locationlog_db_prepared = 1;
}

sub locationlog_history_mac {
  my($mac, %params) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  my $tmpMAC = Net::MAC->new('mac' => $mac);
  $mac = $tmpMAC->as_IEEE();
  if (defined($params{'date'})) {
    return db_data($locationlog_history_mac_date_sql,$mac, $params{'date'}, $params{'date'});
  } else {
    $locationlog_history_mac_sql->execute($mac) || return(0);
    return db_data($locationlog_history_mac_sql);
  }
}

sub locationlog_history_switchport {
  my($switch, %params) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  if (defined($params{'date'})) {
    return db_data($locationlog_history_switchport_date_sql,$switch,$params{'ifIndex'}, $params{'date'}, $params{'date'});
  } else {
    $locationlog_history_switchport_sql->execute($switch,$params{'ifIndex'}) || return(0);
    return db_data($locationlog_history_switchport_sql);
  }
}

sub locationlog_view_all {
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  return db_data($locationlog_view_all_sql);
}

sub locationlog_view_all_open_mac {
  my ($mac) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  my $tmpMAC = Net::MAC->new('mac' => $mac);
  $mac = $tmpMAC->as_IEEE();
  return db_data($locationlog_view_open_mac_sql, $mac);
}

sub locationlog_view_open {
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  return db_data($locationlog_view_open_sql);
}

sub locationlog_view_open_switchport {
  my ($switch,$ifIndex) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  return db_data($locationlog_view_open_switchport_sql, $switch, $ifIndex);
}

sub locationlog_view_open_switchport_no_VoIP {
  my ($switch,$ifIndex) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  return db_data($locationlog_view_open_switchport_no_VoIP_sql, $switch, $ifIndex);
}

sub locationlog_view_open_switchport_only_VoIP {
  my ($switch,$ifIndex) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  $locationlog_view_open_switchport_only_VoIP_sql->execute($switch,$ifIndex) || return(0);
  my $ref = $locationlog_view_open_switchport_only_VoIP_sql->fetchrow_hashref();
  # just get one row and finish
  $locationlog_view_open_switchport_only_VoIP_sql->finish();
  return($ref);
}

sub locationlog_view_open_mac {
  my ($mac) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  my $tmpMAC = Net::MAC->new('mac' => $mac);
  $mac = $tmpMAC->as_IEEE();
  $locationlog_view_open_mac_sql->execute($mac) || return(0);
  my $ref = $locationlog_view_open_mac_sql->fetchrow_hashref();
  # just get one row and finish
  $locationlog_view_open_mac_sql->finish();
  return($ref);
}

sub locationlog_insert_start {
  my ($switch,$ifIndex,$vlan,$mac) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  if (defined($mac)) {
    $locationlog_insert_start_with_mac_sql->execute(lc($mac),$switch,$ifIndex,$vlan) || return(0);
    $locationlog_node_update_location_sql->execute($switch,$ifIndex,lc($mac));
  } else {
    $locationlog_insert_start_no_mac_sql->execute($switch,$ifIndex,$vlan) || return(0);
  }
  return(1);
}

sub locationlog_update_end {
  my ($switch, $ifIndex, $mac) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  my $logger = Log::Log4perl::get_logger('pf::locationlog');
  if (defined($mac)) {
    $logger->info("locationlog_update_end called with mac=$mac");
    locationlog_update_end_mac($mac);
  } else {
    $logger->info("locationlog_update_end called without mac");
    $locationlog_update_end_switchport_sql->execute($switch, $ifIndex) || return(0);
  }
  return(1);
}

sub locationlog_update_end_switchport_no_VoIP {
  my ($switch, $ifIndex) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  $locationlog_update_end_switchport_no_VoIP_sql->execute($switch, $ifIndex) || return(0);
  return(1);
}

sub locationlog_update_end_switchport_only_VoIP {
  my ($switch, $ifIndex) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  $locationlog_update_end_switchport_only_VoIP_sql->execute($switch, $ifIndex) || return(0);
  return(1);
}

sub locationlog_update_end_mac {
  my ($mac) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  $locationlog_update_end_mac_sql->execute($mac) || return(0);
  return(1);
}

#synchronize locationlog to current values if necessary
#if locationlog table contains an open entry for $switch, $ifIndex, $vlan, $mac
#and no other open entry for $mac
#and the node table contains $switch, $ifIndex for $mac
#then do nothing
sub locationlog_synchronize {
  my ($switch, $ifIndex,$vlan,$mac) = @_;
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  if (defined($mac)) {
    $mac = lc($mac);
    my $locationlog_mac = locationlog_view_open_mac($mac);
    if ( (defined($locationlog_mac)) &&
      ( ($locationlog_mac->{vlan} != $vlan) ||
        ($locationlog_mac->{switch} ne $switch) ||
        ($locationlog_mac->{port} != $ifIndex))) {
      $locationlog_update_end_mac_sql->execute($mac) || return(0);
    }
    if (! node_exist($mac)) {
      node_add_simple($mac);
    }
    my $node_data = node_view($mac);
    if (($node_data->{'switch'} ne $switch) || ($node_data->{'port'} ne $ifIndex)) {
      node_modify($mac, ('switch' => $switch, 'port' => $ifIndex));
      #$locationlog_node_update_location_sql->execute($switch,$ifIndex,$mac);
    }
  }
  my $mustInsert = 0;
  my @locationlog_switchport = locationlog_view_open_switchport_no_VoIP($switch, $ifIndex);
  if (! (@locationlog_switchport && scalar(@locationlog_switchport) > 0)) {
    $mustInsert = 1;
  } elsif (($locationlog_switchport[0]->{vlan} != $vlan) ||
    (defined($mac) && (! defined($locationlog_switchport[0]->{mac})))) {
    $locationlog_update_end_switchport_no_VoIP_sql->execute($switch, $ifIndex);
    $mustInsert = 1;
  }
  if ($mustInsert) {
    if (defined($mac)) {
      $locationlog_insert_start_with_mac_sql->execute($mac,$switch,$ifIndex,$vlan) || return(0);
    } else {
      $locationlog_insert_start_no_mac_sql->execute($switch,$ifIndex,$vlan) || return(0);
    }
  }
  return 1;
}

sub locationlog_close_all {
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  $locationlog_close_sql->execute() || return(0);
  return(0);
}

sub locationlog_cleanup {
  my ($time) = @_;
  my $logger = Log::Log4perl::get_logger('pf::locationlog');
  locationlog_db_prepare($dbh) if (! $locationlog_db_prepared);
  $logger->debug("calling locationlog_cleanup with time=$time");
  $locationlog_cleanup_sql->execute($time) || return(0);
  my $rows = $locationlog_cleanup_sql->rows;
  $logger->log((($rows > 0) ? $INFO : $DEBUG), "deleted $rows entries from locationlog during locationlog cleanup");
  return(0);
}

1

