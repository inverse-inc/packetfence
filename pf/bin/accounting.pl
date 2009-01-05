#!/usr/bin/perl -w
#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

=head1 NAME
accounting.pl

=head1 SYNOPSIS

./accounting

=head1 DESCRIPTION

Obtain ifInOctets and ifOutOctets from switches using SNMP

=head1 AUTHOR

=over 

=item Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (c) 2007-2008 Inverse groupe conseil

This program is available under the GPL.

=cut

use strict;
use warnings;
use diagnostics;

use Data::Dumper;
use Net::SNMP;
use threads;
use threads::shared;
use Thread::Pool;


use constant INSTALL_DIR => '/usr/local/pf';

use lib INSTALL_DIR . "/lib";
use pf::SwitchFactory;
use pf::db;
use pf::person;
use pf::locationlog;
use pf::node;
use pf::ifoctetslog;

Log::Log4perl->init(INSTALL_DIR . '/conf/log.conf');
my $logger = Log::Log4perl->get_logger('');

my $switchFactory = new pf::SwitchFactory(
  -configFile => INSTALL_DIR . '/conf/switches.conf';
);

my $pool = Thread::Pool->new(
  {
    workers => 10,
    do => sub {
      my ($switchDesc) = @_;
      my $mysql_connection = db_connect();
      node_db_prepare($mysql_connection);
      locationlog_db_prepare($mysql_connection);
      person_db_prepare($mysql_connection);
      ifoctetslog_db_prepare($mysql_connection);
      my $switch = $switchFactory->instantiate($switchDesc);
      if (! $switch->isProductionMode()) {
        return 0;
      }
      if ($switch->connectRead()) {
        my @managedIfIndexes = $switch->getManagedIfIndexes();
        my $octets = $switch->getAllIfOctets(@managedIfIndexes);
        my $macs = $switch->getAllMacs(@managedIfIndexes);
        foreach my $ifIndex (keys %$macs) {
          foreach my $vlan (keys %{$macs->{$ifIndex}}) {
            push @{$octets->{$ifIndex}->{'macs'}}, @{$macs->{$ifIndex}->{$vlan}};
          }
        }
        foreach my $ifIndex (sort keys %$octets) {
          if (exists($octets->{$ifIndex}->{'macs'})) {
            if (scalar(@{$octets->{$ifIndex}->{'macs'}}) == 1) {
              print join(",", $switch->{_ip},$ifIndex,$octets->{$ifIndex}->{'macs'}->[0],$octets->{$ifIndex}->{'in'},$octets->{$ifIndex}->{'out'}) . "\n";
              ifoctetslog_insert($switch->{_ip},$ifIndex,$octets->{$ifIndex}->{'macs'}->[0],$octets->{$ifIndex}->{'in'},$octets->{$ifIndex}->{'out'});
            }
          }
        }
        return 1;
      } else {
        return 0;
      }
    }
  }
);
      
my %Config = %{$switchFactory->{_config}};
delete $Config{'default'};

my %switchJobHash;
foreach my $switchDesc (sort keys %Config) {
  if (! ($Config{$switchDesc}->{'type'} =~ /Aironet/)) {
    $switchJobHash{$switchDesc} = $pool->job($switchDesc);
  }
}

foreach my $switchDesc (keys %switchJobHash) {
  $logger->debug("waiting for result for $switchDesc");
  my $result = $pool->result($switchJobHash{$switchDesc});
  if (! $result) {
    $logger->warn("$switchDesc: unable to determine");
  } else {
    $logger->info("calculation for $switchDesc terminated succesfully");
  }
}

