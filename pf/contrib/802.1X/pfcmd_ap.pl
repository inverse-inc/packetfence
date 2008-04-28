#!/usr/bin/perl -w
#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

use strict;
use warnings;
use diagnostics;
use FindBin;
use DBI;
use Data::Dumper;

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

# create database connection
my $mysql_connection = DBI->connect("dbi:mysql:dbname=$database_dbname;host=$database_hostname", $database_user, $database_password, {PrintError => 0});

# check if mac exists already in database
# if not, create the node
my $nodeExists = $mysql_connection->selectrow_array("SELECT count(*) FROM node WHERE mac='$mac'");
if ($nodeExists == 0) {
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
$mysql_connection->do("UPDATE locationlog SET end_time=now() WHERE mac='$mac' and (end_time = 0 OR isnull(end_time))");
$mysql_connection->do("INSERT INTO locationlog(mac,switch,port,vlan,start_time) VALUES('$mac','$switch_ip','WIFI',$correctVlan,now())");
$mysql_connection->do("UPDATE node SET switch='$switch_ip', port='WIFI' WHERE mac='$mac'");

# return the correct VLAN
print $correctVlan;

$mysql_connection->disconnect();

exit;

