#!/usr/bin/perl -w

=head1 NAME

accounting.pl

=head1 SYNOPSIS

./accounting

=head1 DESCRIPTION

Obtain ifInOctets and ifOutOctets from switches using SNMP

=cut

use strict;
use warnings;

use Data::Dumper;
use Net::SNMP;
use threads;
use threads::shared;
use Thread::Pool;
use Log::Log4perl;
use Log::Log4perl::Appender::File; # HACK: compile tests failed on build env. without that

use constant INSTALL_DIR => '/usr/local/pf';

use lib INSTALL_DIR . "/lib";
use pf::SwitchFactory;
use pf::db;
use pf::person;
use pf::locationlog;
use pf::node;
use pf::ifoctetslog;

Log::Log4perl->init( INSTALL_DIR . '/conf/log.conf' );
my $logger = Log::Log4perl->get_logger('');

my $switchFactory = new pf::SwitchFactory(
    -configFile => INSTALL_DIR . '/conf/switches.conf'
);

my $pool = Thread::Pool->new(
    {   workers => 10,
        do      => sub {
            my ($switchDesc) = @_;
            my $switch = $switchFactory->instantiate($switchDesc);
            if (!$switch) {
                $logger->error("Can not instantiate switch $switchDesc !");
                return 0;
            }
            if ( !$switch->isProductionMode() ) {
                return 0;
            }
            if ( $switch->connectRead() ) {
                my @managedIfIndexes = $switch->getManagedIfIndexes();
                my $octets = $switch->getAllIfOctets(@managedIfIndexes);
                my $macs   = $switch->getAllMacs(@managedIfIndexes);
                foreach my $ifIndex ( keys %$macs ) {
                    foreach my $vlan ( keys %{ $macs->{$ifIndex} } ) {
                        push @{ $octets->{$ifIndex}->{'macs'} },
                            @{ $macs->{$ifIndex}->{$vlan} };
                    }
                }
                foreach my $ifIndex ( sort keys %$octets ) {
                    if ( exists( $octets->{$ifIndex}->{'macs'} ) ) {
                        if (scalar( @{ $octets->{$ifIndex}->{'macs'} } )
                            == 1 )
                        {
                            print join( ",",
                                $switch->{_ip},
                                $ifIndex,
                                $octets->{$ifIndex}->{'macs'}->[0],
                                $octets->{$ifIndex}->{'in'},
                                $octets->{$ifIndex}->{'out'} )
                                . "\n";
                            ifoctetslog_insert(
                                $switch->{_ip},
                                $ifIndex,
                                $octets->{$ifIndex}->{'macs'}->[0],
                                $octets->{$ifIndex}->{'in'},
                                $octets->{$ifIndex}->{'out'}
                            );
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

my %Config = %{ $switchFactory->{_config} };
delete $Config{'default'};
delete $Config{'127.0.0.1'};

my %switchJobHash;
foreach my $switchDesc ( sort keys %Config ) {
    if ( !( $Config{$switchDesc}->{'type'} =~ /Aironet/ ) ) {
        $switchJobHash{$switchDesc} = $pool->job($switchDesc);
    }
}

foreach my $switchDesc ( keys %switchJobHash ) {
    $logger->debug("waiting for result for $switchDesc");
    my $result = $pool->result( $switchJobHash{$switchDesc} );
    if ( !$result ) {
        $logger->warn("$switchDesc: unable to determine");
    } else {
        $logger->info("calculation for $switchDesc terminated succesfully");
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

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

