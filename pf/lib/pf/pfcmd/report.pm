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

use lib qw(/usr/local/pf/lib);
use pf::db;

use vars qw/$report_active_all_sql $report_inactive_all_sql $report_unregistered_active_sql $report_unregistered_all_sql
            $report_registered_active_sql $report_registered_all_sql $report_os_active_sql $report_os_all_sql $report_osclass_all_sql
            $report_osclass_active_sql $report_unknownprints_all_sql $report_unknownprints_active_sql $report_openviolations_all_sql
            $report_openviolations_active_sql $report_statics_all_sql $report_statics_active_sql @ISA @EXPORT/;

report_db_prepare($dbh);

sub report_db_prepare {
  my ($dbh) = @_;
  $report_inactive_all_sql=$dbh->prepare( qq [ select n.mac,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os from node n LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.mac not in (select i.mac from iplog i where i.end_time=0 or i.end_time > now()) ]);
  $report_active_all_sql=$dbh->prepare( qq [ select n.mac,ip,start_time,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os from (node n,iplog i) LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where i.mac=n.mac and (i.end_time=0 or i.end_time > now()) ]);
  $report_unregistered_all_sql=$dbh->prepare( qq [ select n.mac,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os FROM node n LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.status='unreg' ]);
  $report_unregistered_active_sql=$dbh->prepare( qq [ select n.mac,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os FROM (node n,iplog i) LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.status='unreg' and i.mac=n.mac and (i.end_time=0 or i.end_time > now()) ]);
  $report_registered_all_sql=$dbh->prepare( qq [ select n.mac,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os FROM node n LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.status='reg' ]);
  $report_registered_active_sql=$dbh->prepare( qq [ select n.mac,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os FROM (node n,iplog i) LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.status='reg' and i.mac=n.mac and (i.end_time=0 or i.end_time > now()) ]);
  $report_os_active_sql=$dbh->prepare( qq [ select o.description,n.dhcp_fingerprint,count(*) as count,ROUND(COUNT(*)/(SELECT COUNT(*) FROM node)*100,1) as percent FROM (node n,iplog i) LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.mac=i.mac and (i.end_time=0 or i.end_time > now()) group by o.description order by percent desc ]);
  $report_os_all_sql=$dbh->prepare( qq [select o.description,n.dhcp_fingerprint,count(*) as count,ROUND(COUNT(*)/(SELECT COUNT(*) FROM node)*100,1) as percent FROM node n LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id group by o.description order by percent desc ]);
  $report_osclass_all_sql=$dbh->prepare( qq [ select c.description,count(*) as count,ROUND(COUNT(*)/(SELECT COUNT(*) FROM node)*100,1) as percent from node n LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint left join os_mapping m on m.os_type=d.os_id left join os_class c on m.os_class=c.class_id group by c.description order by percent desc ]);
  $report_osclass_active_sql=$dbh->prepare( qq [ select c.description,count(*) as count,ROUND(COUNT(*)/(SELECT COUNT(*) FROM node,iplog where node.mac=iplog.mac and (iplog.end_time=0 or iplog.end_time > now()))*100,1) as percent from (node n,iplog i) LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint left join os_mapping m on m.os_type=d.os_id left join os_class c on m.os_class=c.class_id where n.mac=i.mac and (i.end_time=0 or i.end_time > now()) group by c.description order by percent desc ]);
  $report_unknownprints_all_sql=$dbh->prepare( qq [SELECT mac,dhcp_fingerprint,computername,user_agent FROM node WHERE dhcp_fingerprint NOT IN (SELECT fingerprint FROM dhcp_fingerprint) and dhcp_fingerprint!=0 ORDER BY dhcp_fingerprint, mac ]);
  $report_unknownprints_active_sql=$dbh->prepare( qq [SELECT node.mac,dhcp_fingerprint,computername,user_agent FROM node,iplog WHERE dhcp_fingerprint NOT IN (SELECT fingerprint FROM dhcp_fingerprint) and dhcp_fingerprint!=0 and node.mac=iplog.mac and (iplog.end_time=0 or iplog.end_time > now()) ORDER BY dhcp_fingerprint, mac]);
  $report_statics_all_sql=$dbh->prepare( qq [SELECT * FROM node WHERE dhcp_fingerprint="" OR dhcp_fingerprint IS NULL] );
  $report_statics_active_sql=$dbh->prepare( qq [SELECT * FROM node,iplog WHERE (dhcp_fingerprint="" OR dhcp_fingerprint IS NULL) AND node.mac=iplog.mac and (iplog.end_time=0 or iplog.end_time > now()) ] );
  $report_openviolations_all_sql=$dbh->prepare( qq [SELECT n.pid as owner, n.mac as mac, v.status as status, v.start_date as start_date, c.description as violation from violation v LEFT JOIN node n ON v.mac=n.mac LEFT JOIN class c on c.vid=v.vid WHERE v.status="open" order by n.pid ]);
  $report_openviolations_active_sql=$dbh->prepare( qq [SELECT n.pid as owner, n.mac as mac, v.status as status, v.start_date as start_date, c.description as violation from (violation v, iplog i) LEFT JOIN node n ON v.mac=n.mac LEFT JOIN class c on c.vid=v.vid WHERE v.status="open" and n.mac=i.mac and (i.end_time=0 or i.end_time > now()) order by n.pid ]);
}

sub report_os_all {
  my @data    = db_data($report_os_all_sql);
  my $statics = scalar(db_data($report_statics_all_sql)); 
  my $total   = 0;

  my $ref;
  foreach my $record (@data) {
    $total += $record->{'count'};
    $ref = $record if (!$record->{'description'});
  }

  my $static_percent = sprintf("%.1f",($statics/$total)*100);

  if ($statics > 0) { 
    push @data, { description => "*Probable Static IP(s)", percent => $static_percent, count => $statics };
  }

  $ref->{'description'} = "Unknown DHCP Fingerprint";
  $ref->{'percent'}     = sprintf("%.1f",($ref->{'count'} / $total) * 100) - $static_percent;
  $ref->{'count'}       -= $statics;

  push @data, { description => "Total", percent => "100", count => $total };
  return(@data);
}

sub report_os_active {
  my @data    = db_data($report_os_active_sql);
  my $statics = scalar(db_data($report_statics_active_sql)); 
  my $total   = 0;

  my $ref;
  foreach my $record (@data) {
    $total += $record->{'count'};
    $ref = $record if (!$record->{'description'});
  }

  my $static_percent = sprintf("%.1f",($statics/$total)*100);

  if ($statics > 0) { 
    push @data, { description => "*Probable Static IP(s)", percent => $static_percent, count => $statics };
  }

  $ref->{'description'} = "Unknown DHCP Fingerprint";
  $ref->{'percent'}     = sprintf("%.1f",($ref->{'count'} / $total) * 100) - $static_percent;
  $ref->{'count'}       -= $statics;

  push @data, { description => "Total", percent => "100", count => $total };
  return(@data);
}

sub report_osclass_all {
  my @data = db_data($report_osclass_all_sql);
  my $statics = scalar(db_data($report_statics_all_sql));
  my $total = 0;
  my $ref;

  foreach my $record (@data) {
    if (!$record->{'description'}) {
      $ref = $record;
    }
    $total += $record->{'count'};
  }

  my $static_percent = sprintf("%.1f",($statics/$total)*100);

  $ref->{'description'} = "Unknown";
  $ref->{'percent'}     -= $static_percent;
  $ref->{'count'}       -= $statics; 

  if ($statics > 0) {
    push @data, { description => "*Probable Static IP(s)", percent => $static_percent, count => $statics };
  }

  push @data, { description => "Total", percent => "100", count => $total };
  return(@data);
}


sub report_osclass_active {
  my @data    = db_data($report_osclass_active_sql);
  my $statics = scalar(db_data($report_statics_active_sql));
  my $total   = 0;
  my $ref;

  foreach my $record (@data) {
    if (!$record->{'description'}) {
      $ref = $record;
    }
    $total += $record->{'count'};
  }

  my $static_percent = sprintf("%.1f",($statics/$total)*100);

  $ref->{'description'} = "Unknown";
  $ref->{'percent'}     -= $static_percent;
  $ref->{'count'}       -= $statics; 

  if ($statics > 0) {
    push @data, { description => "*Probable Static IP(s)", percent => $static_percent, count => $statics };
  }

  push @data, { description => "Total", percent => "100", count => $total };
  return(@data);
}

sub report_active_all {
 return db_data($report_active_all_sql);
}


sub report_inactive_all {
 return db_data($report_inactive_all_sql);
}

sub report_unregistered_active {
 return db_data($report_unregistered_active_sql);
}

sub report_unregistered_all {
 return db_data($report_unregistered_all_sql);
}

sub report_active_reg {
 return db_data($report_registered_active_sql);
}

sub report_registered_all {
 return db_data($report_registered_all_sql);
}

sub report_registered_active {
 return db_data($report_registered_active_sql);
}

sub report_openviolations_all {
 return db_data($report_openviolations_all_sql);
}

sub report_openviolations_active {
 return db_data($report_openviolations_active_sql);
}

sub report_statics_all {
  return db_data($report_statics_all_sql);
}

sub report_statics_active {
  return db_data($report_statics_active_sql);
}

sub report_unknownprints_all {
  my @data = db_data($report_unknownprints_all_sql);
  foreach my $datum (@data) {
    $datum->{'vendor'} = oui_to_vendor($datum->{'mac'});
  }
  return(@data);
}

sub report_unknownprints_active {
  my @data = db_data($report_unknownprints_active_sql);
  foreach my $datum (@data) {
    $datum->{'vendor'} = oui_to_vendor($datum->{'mac'});
  }
  return(@data);
}

1
