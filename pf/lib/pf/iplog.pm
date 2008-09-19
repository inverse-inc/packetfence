#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
# Copyright 2008 Inverse groupe conseil <dgehl@inverse.ca>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::iplog;

use strict;
use warnings;
use Net::MAC;
use Net::Netmask;
use Net::Ping;
use Date::Parse;
use Log::Log4perl;

our ($iplog_shutdown_sql, $iplog_lastseen_sql, $iplog_view_open_sql, $iplog_view_all_sql, $iplog_history_ip_sql,
     $iplog_history_mac_sql, $iplog_history_ip_date_sql, $iplog_history_mac_date_sql, $iplog_close_sql, $iplog_close_now_sql,
     $iplog_open_with_lease_length_sql,$iplog_open_update_end_time_sql,
     $iplog_open_sql, $iplog_view_open_ip_sql, $iplog_view_open_mac_sql, $iplog_cleanup_sql, $iplog_expire_sql, $iplog_db_prepared);

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(iplog_db_prepare iplog_shutdown iplog_history_ip iplog_history_mac iplog_view_open iplog_view_open_ip
               iplog_view_open_mac iplog_view_all iplog_open iplog_close iplog_close_now iplog_cleanup iplog_expire mac2ip mac2allips ip2mac);
}

use lib qw(/usr/local/pf/lib);
use pf::config;
use pf::db;
use pf::util;
use pf::node qw(node_exist node_add_simple);

$iplog_db_prepared = 0;
#iplog_db_prepare($dbh) if (!$thread);

sub iplog_db_prepare {
  my ($dbh) = @_;
  db_connect($dbh);
  my $logger = Log::Log4perl::get_logger('pf::iplog');
  $logger->info("Preparing pf::iplog database queries");
  $iplog_shutdown_sql=$dbh->prepare( qq [ update iplog set end_time=now() where end_time=0 ]);
  #$iplog_lastseen_sql=$dbh->prepare( qq [ update iplog set last_seen=from_unixtime(?) where mac=? and ip=? and end_time=0]);
  $iplog_view_open_sql=$dbh->prepare( qq [ select mac,ip,start_time,end_time from iplog where end_time=0 or end_time > now() ]);
  $iplog_view_open_ip_sql=$dbh->prepare( qq [ select mac,ip,start_time,end_time from iplog where ip=? and (end_time=0 or end_time > now()) limit 1]);
  $iplog_view_open_mac_sql=$dbh->prepare( qq [ select mac,ip,start_time,end_time from iplog where mac=? and (end_time=0 or end_time > now()) order by start_time desc]);   
  $iplog_view_all_sql=$dbh->prepare( qq [ select mac,ip,start_time,end_time from iplog ]);
  $iplog_history_ip_date_sql=$dbh->prepare( qq [ select mac,ip,start_time,end_time from iplog where ip=? and unix_timestamp(start_time) < ? and (unix_timestamp(end_time) > ? or end_time=0) order by start_time desc ]);
  $iplog_history_mac_date_sql=$dbh->prepare( qq [ select mac,ip,start_time,end_time from iplog where mac=? and unix_timestamp(start_time) < ? and (unix_timestamp(end_time) > ? or end_time=0) order by start_time desc ]);
  $iplog_history_ip_sql=$dbh->prepare( qq [ select mac,ip,start_time,end_time from iplog where ip=? order by start_time desc ]);
  $iplog_history_mac_sql=$dbh->prepare( qq [ select mac,ip,start_time,end_time from iplog where mac=? order by start_time desc ]);
  $iplog_open_sql=$dbh->prepare( qq [ insert into iplog(mac,ip,start_time) values(?,?,now()) ]);
  $iplog_open_with_lease_length_sql=$dbh->prepare( qq [ insert into iplog(mac,ip,start_time,end_time) values(?,?,now(),adddate(now(), interval ? second)) ]);
  $iplog_open_update_end_time_sql=$dbh->prepare( qq [ update iplog set end_time = adddate(now(), interval ? second) where mac=? and ip=? and (end_time = 0 or end_time > now()) ]);
  $iplog_close_sql=$dbh->prepare( qq [ update iplog set end_time=now() where ip=? and end_time=0 ]);
  $iplog_close_now_sql=$dbh->prepare( qq [ update iplog set end_time=now() where ip=? and (end_time=0 or end_time > now())]);
  $iplog_cleanup_sql=$dbh->prepare ( qq [ delete from iplog where unix_timestamp(end_time) < (unix_timestamp(now()) - ?) and end_time!=0 ]);
  $iplog_db_prepared = 1;
}

sub iplog_shutdown {
  my $logger = Log::Log4perl::get_logger('pf::iplog');
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  $logger->info("closing open iplogs");
  $iplog_shutdown_sql->execute() || return(0);
  return(1);
}

sub iplog_history_ip {
  my($ip, %params) = @_;
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  if (defined($params{'start_time'}) && defined($params{'end_time'})) {
    return db_data($iplog_history_ip_date_sql,$ip, $params{'end_time'}, $params{'start_time'});
  } elsif (defined($params{'date'})) {
    return db_data($iplog_history_ip_date_sql,$ip, $params{'date'}, $params{'date'});
  } else {
    $iplog_history_ip_sql->execute($ip) || return(0);
    return db_data($iplog_history_ip_sql);
  }
}

sub iplog_history_mac {
  my($mac, %params) = @_;
  my $tmpMAC = Net::MAC->new('mac' => $mac);
  $mac = $tmpMAC->as_IEEE();
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  if (defined($params{'start_time'}) && defined($params{'end_time'})) {
    return db_data($iplog_history_mac_date_sql,$mac, $params{'end_time'}, $params{'start_time'});
  } elsif (defined($params{'date'})) {
    return db_data($iplog_history_mac_date_sql,$mac, $params{'date'}, $params{'date'});
  } else {
    $iplog_history_mac_sql->execute($mac) || return(0);
    return db_data($iplog_history_mac_sql);
  }
}

sub iplog_view_open {
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  return db_data($iplog_view_open_sql);
}

sub iplog_view_open_ip {
  my ($ip) = @_;
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  $iplog_view_open_ip_sql->execute($ip) || return(0);
  my $ref = $iplog_view_open_ip_sql->fetchrow_hashref();
  # just get one row and finish
  $iplog_view_open_ip_sql->finish();
  return($ref);
}

sub iplog_view_open_mac {
  my ($mac) = @_;
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  $iplog_view_open_mac_sql->execute($mac) || return(0);
  my $ref = $iplog_view_open_mac_sql->fetchrow_hashref();
  # just get one row and finish
  $iplog_view_open_mac_sql->finish();
  return($ref);
}

sub iplog_view_all_open_mac {
  my ($mac) = @_;
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  return db_data($iplog_view_open_mac_sql, $mac);
}

sub iplog_view_all {
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  return db_data($iplog_view_all_sql);
}

sub iplog_open {
  my ($mac, $ip, $lease_length) = @_;
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  my $logger = Log::Log4perl::get_logger('pf::iplog');
  if (! node_exist($mac)) {
    node_add_simple($mac);
  }
  if ($lease_length) {
    if (! defined(iplog_view_open_mac($mac))) {
      $logger->debug("creating new entry for ($mac - $ip)");
      $iplog_open_with_lease_length_sql->execute($mac, $ip, $lease_length);
    } else {
      $logger->debug("updating end_time for ($mac - $ip)");
      $iplog_open_update_end_time_sql->execute($lease_length, $mac, $ip);
    }
  } elsif (! defined(iplog_view_open_mac($mac))) {
    $logger->debug("creating new entry for ($mac - $ip) with empty end_time");
    $iplog_open_sql->execute($mac, $ip) || return(0);
  }
  return(0);
}

sub iplog_close {
  my ($ip) = @_;
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  $iplog_close_sql->execute($ip) || return(0);
  return(0);
}

sub iplog_close_now {
  my ($ip) = @_;
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  $iplog_close_now_sql->execute($ip) || return(0);
  return(0);
}

sub iplog_cleanup {
  my ($time) = @_;
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  $iplog_cleanup_sql->execute($time) || return(0);
  return(0);
}

sub iplog_expire {
  my ($time)= @_;
  iplog_db_prepare($dbh) if (! $iplog_db_prepared);
  return db_data($iplog_expire_sql,$time);
}

sub ip2mac {
  my ($ip, $date) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iplog');
  my $mac;
  return(0) if (!valid_ip($ip));

  if ($date) {
    return if (!valid_date($date));
    my @iplog = iplog_history_ip($ip,('date' => str2time($date)));
    $mac = $iplog[0]->{'mac'};
  } else {
    my $iplog = iplog_view_open_ip($ip);
    $mac = $iplog->{'mac'};
    if (!$mac) {
      $logger->debug("could not resolve $ip to mac in iplog table");
      $mac = ip2macinarp($ip);
      if (! $mac) {
        $logger->debug("trying to resolve $ip to mac using ping");
        my @lines = `/sbin/ip address show`;
        my $lineNb = 0;
        my $src_ip = undef;
        while (($lineNb < scalar(@lines)) && (! defined($src_ip))) {
          my $line = $lines[$lineNb];
          if ($line =~ /inet ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\/([0-9]+)/) {
            my $tmp_src_ip = $1;
            my $tmp_src_bits = $2;
            my $block = new Net::Netmask("$tmp_src_ip/$tmp_src_bits");
            if ($block->match($ip)) {
              $src_ip = $tmp_src_ip;
              $logger->debug("found $ip in Network $tmp_src_ip/$tmp_src_bits");
            }
          }
          $lineNb++;
        }
        if (defined($src_ip)) {
          my $ping = Net::Ping->new();
          $logger->debug("binding ping src IP to $src_ip for ping");
          $ping->bind($src_ip);
          $ping->ping($ip,2);
	  $ping->close();
	  $mac = ip2macinarp($ip);
        } else {
          $logger->debug("unable to find an IP address on PF host in the same broadcast domain than $ip -> won't send ping");
        }
      }
      if ($mac) {
        iplog_open($mac,$ip);
      }
    }
  }
  if (!$mac){
    $logger->warn("could not resolve $ip to mac");
    return(0);
  }else{
    return(clean_mac($mac));
  }
}

sub ip2macinarp {
  my($ip)=@_;
  my $logger = Log::Log4perl::get_logger('pf::iplog');
  return(0) if (!valid_ip($ip));
  my $mac;
  my @arpList = `/sbin/arp -n -a $ip`;
  my $lineNb = 0;
  while (($lineNb < scalar(@arpList)) && (! $mac)) {
    if ($arpList[$lineNb] =~ /\($ip\) at ([0-9a-z]{2}:[0-9a-z]{2}:[0-9a-z]{2}:[0-9a-z]{2}:[0-9a-z]{2}:[0-9a-z]{2})/i) {
      $mac=$1;
      $mac = clean_mac($mac);
      logger->info("resolved $ip to mac ($mac) in ARP table");
    }
  $lineNb++;
  }
  if (! $mac) {
    $logger->info("could not resolve $ip to mac in ARP table");
    return(0);
  }
  return $mac;
}

sub mac2ip {
  my($mac,$date) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iplog');
  my $ip;
  return(0) if (!valid_mac($mac));

  if ($date) {
    return if (!valid_date($date));
    my @iplog = iplog_history_mac($mac,('date' => str2time($date)));
    $ip = $iplog[0]->{'ip'};
  } else {
    my $iplog = iplog_view_open_mac($mac);
    $ip = $iplog->{'ip'} || 0 ;
  }
  if (!$ip) {
    $logger->warn("unable to resolve $mac to ip");
    return();
  } else {
    return($ip);
  }
}

sub mac2allips {
  my ($mac) = @_;
  my $logger = Log::Log4perl::get_logger('pf::iplog');
  return (0) if (!valid_mac($mac));
  my @all_ips = ();
  foreach my $iplog_entry (iplog_view_all_open_mac($mac)) {
    push @all_ips, $iplog_entry->{'ip'};
  }
  if (scalar(@all_ips) == 0) {
    $logger->warn("unable to resolve $mac to ip");
  }
  return @all_ips;
}
1
