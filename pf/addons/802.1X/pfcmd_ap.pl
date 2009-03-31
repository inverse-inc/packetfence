#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;
use FindBin;
use DBI;
use Data::Dumper;
use Sys::Syslog;

require 5.8.8;

my $database_hostname = 'localhost';
my $database_dbname = 'pf';
my $database_user = 'pf';
my $database_password = 'pf';

my $visitorVlan = 5;
my $registrationVlan = 3;
my $isolationVlan = 2;
my $normalVlan = 1;

my $switch_ip = $ARGV[0];
my $mac = lc($ARGV[1]);
my $is_eap_request = $ARGV[2];

syslog("info", "pfcmd_ap.pl called with switch_ip $switch_ip, mac $mac, is_eap_request $is_eap_request");

# create database connection
my $mysql_connection = DBI->connect("dbi:mysql:dbname=$database_dbname;host=$database_hostname", $database_user, $database_password, {PrintError => 0});

# check if mac exists already in database
# if not, create the node
my $nodeExists = $mysql_connection->selectrow_array("SELECT count(*) FROM node WHERE mac='$mac'");
if ($nodeExists == 0) {
  syslog("info", "node $mac does not yet exist in database -> will be created now");
  $mysql_connection->do("INSERT INTO node(mac,detect_date,status,last_arp) VALUES('$mac',now(),'unreg',now())");
}

# determine correct VLAN
my $correctVlan = -1;

# check if registered
if ($is_eap_request == 0) {
  my $registrationExists = $mysql_connection->selectrow_array("SELECT count(*) FROM node WHERE mac='$mac' AND status='reg'");
  if ($registrationExists != 0) {
    # check if 'visitor'
    my $isVisitor = $mysql_connection->selectrow_array("SELECT count(*) FROM node WHERE mac='$mac' AND pid='visitor'");
    if ($isVisitor == 1) {
      $correctVlan = $visitorVlan;
    }
  } else {
    $correctVlan = $registrationVlan;
  }
} else {
  my $isVisitor = $mysql_connection->selectrow_array("SELECT count(*) FROM node WHERE mac='$mac' AND pid='visitor'");
  if ($isVisitor == 0) {
    # check if violations
    my $nbOpenViolations = $mysql_connection->selectrow_array("SELECT count(*) FROM violation WHERE mac='$mac' and status='open'");
    if ($nbOpenViolations > 0) {
      $correctVlan = $isolationVlan;
    } else {
      $correctVlan = $normalVlan;
    }
  }
}

# update locationlog
syslog("info", "closing previous open locationlog entries for $mac");
$mysql_connection->do("UPDATE locationlog SET end_time=now() WHERE mac='$mac' and (end_time = 0 OR isnull(end_time))");
syslog("info", "inserting new open locationlog entry for $mac");
$mysql_connection->do("INSERT INTO locationlog(mac,switch,port,vlan,start_time) VALUES('$mac','$switch_ip','WIFI',$correctVlan,now())");
syslog("info", "updating node entry (switch and port) for mac $mac");
$mysql_connection->do("UPDATE node SET switch='$switch_ip', port='WIFI' WHERE mac='$mac'");

# return the correct VLAN
syslog("info", "returning VLAN $correctVlan for $mac");
print $correctVlan;

$mysql_connection->disconnect();

exit;

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2009 Inverse inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut


