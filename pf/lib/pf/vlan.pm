package pf::vlan;

=head1 NAME

pf::vlan - Object oriented module for VLAN isolation oriented functions 

=head1 SYNOPSIS

The pf::vlan module implements VLAN isolation oriented functions.

=cut

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;
use pf::config;
use pf::node qw(node_view node_add_simple node_exist);
use pf::util;
use pf::violation qw(violation_count_trap violation_exist_open);
use pf::SwitchFactory;
use Net::Ping;
use threads;
use threads::shared;

sub new {
    my $logger = Log::Log4perl::get_logger("pf::vlan");
    $logger->debug("instantiating new pf::vlan object");
    my ( $class, %argv ) = @_;
    my $this = bless {}, $class;
    return $this;
}

sub vlan_determine_for_node {
    my ( $this, $mac, $switch_ip, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::vlan');
    Log::Log4perl::MDC->put( 'tid', threads->self->tid() );

    my $correctVlanForThisMAC;
    my $open_violation_count = violation_count_trap($mac);
    if ( $open_violation_count > 0 ) {
        if (   ( $open_violation_count == 1 )
            && ( violation_exist_open( $mac, 1200001 ) ) )
        {
            $logger->info(
                "$mac has scan reg violation open; belongs into registration VLAN."
            );
            my $switchFactory = new pf::SwitchFactory(
                -configFile => "$conf_dir/switches.conf" );
            my $switch = $switchFactory->instantiate($switch_ip);
            $correctVlanForThisMAC = $switch->{_registrationVlan};
        } else {
            $logger->info(
                "$mac has $open_violation_count open violations(s) with action=trap; belongs into isolation VLAN."
            );
            my $switchFactory = new pf::SwitchFactory(
                -configFile => "$conf_dir/switches.conf" );
            my $switch = $switchFactory->instantiate($switch_ip);
            $correctVlanForThisMAC = $switch->{_isolationVlan};
        }
    } else {
        if ( !node_exist($mac) ) {
            $logger->info(
                "node $mac does not yet exist in PF database. Adding it now");
            node_add_simple($mac);
        }
        my $node_info = node_view($mac);
        if ( isenabled( $Config{'trapping'}{'registration'} ) ) {
            if (   ( !defined($node_info) )
                || ( $node_info->{'status'} eq 'unreg' ) )
            {
                $logger->info(
                    "MAC: $mac is unregistered; belongs into registration VLAN"
                );
                my $switchFactory = new pf::SwitchFactory(
                    -configFile => "$conf_dir/switches.conf" );
                my $switch = $switchFactory->instantiate($switch_ip)
                    || return -1;
                $correctVlanForThisMAC = $switch->{_registrationVlan};
            } else {
                $correctVlanForThisMAC
                    = $this->custom_getCorrectVlan( $switch_ip, $ifIndex,
                    $mac, $node_info->{status}, $node_info->{vlan},
                    $node_info->{pid} );
                $logger->info( "MAC: $mac, PID: "
                        . $node_info->{pid}
                        . ", Status: "
                        . $node_info->{status}
                        . ", VLAN: $correctVlanForThisMAC" );
            }
        } else {
            my $switchFactory = new pf::SwitchFactory(
                -configFile => "$conf_dir/switches.conf" );
            my $switch = $switchFactory->instantiate($switch_ip) || return -1;
            $correctVlanForThisMAC
                = $this->custom_getCorrectVlan( $switch_ip, $ifIndex, $mac,
                $node_info->{status},
                ( $node_info->{vlan} || $switch->{_normalVlan} ),
                $node_info->{pid} );
            $logger->info( "MAC: $mac, PID: "
                    . $node_info->{pid}
                    . ", Status: "
                    . $node_info->{status}
                    . ", VLAN: $correctVlanForThisMAC" );
        }
    }
    return $correctVlanForThisMAC;
}

# don't act on configured uplinks
sub custom_doWeActOnThisTrap {
    my ( $this, $switch, $ifIndex, $trapType ) = @_;
    my $logger = Log::Log4perl->get_logger();
    Log::Log4perl::MDC->put( 'tid', threads->self->tid() );

    my $weActOnThisTrap = 0;

    my $ifType = $switch->getIfType($ifIndex);
    if ( ( $ifType == 6 ) || ( $ifType == 117 ) ) {
        my @upLinks = $switch->getUpLinks();
        if ( $upLinks[0] == -1 ) {
            $logger->info(
                "can not determine uplinks for the switch -> do nothing");
        } else {
            if ( grep( { $_ == $ifIndex } @upLinks ) == 0 ) {
                $weActOnThisTrap = 1;
            } else {
                $logger->info( "$trapType trap received on "
                        . $switch->{_ip}
                        . " ifindex $ifIndex which is uplink and we don't manage uplinks"
                );
            }
        }
    } else {
        $logger->info( "$trapType trap received on "
                . $switch->{_ip}
                . " ifindex $ifIndex which is not ethernetCsmacd" );
    }
    return $weActOnThisTrap;
}

sub custom_getCorrectVlan {

    #$switch_ip is the ip of the switch
    #$ifIndex is the ifIndex of the computer connected to
    #$mac is the mac connected
    #$status is the node's status in the database
    #$vlan is the vlan set for this node in the database
    #$pid is the owner of this node in the database
    my ( $this, $switch_ip, $ifIndex, $mac, $status, $vlan, $pid ) = @_;
    my $logger = Log::Log4perl->get_logger();
    Log::Log4perl::MDC->put( 'tid', threads->self->tid() );

#   if ($vlan eq '') {
#        $logger->info("MAC: $mac is registered but VLAN is not set; setting into registration VLAN");
#        $vlan = $switch->{_registrationVlan};
#    }
    return $vlan;
}

sub custom_isClientAlive {
    my ( $this, $mac, $switch_ip, $ifIndex, $currentVlan, $isolationVlan,
        $mysql_connection )
        = @_;
    my $logger = Log::Log4perl->get_logger();
    Log::Log4perl::MDC->put( 'tid', threads->self->tid() );

    my $ip;
    my $returnValue = 0;
    my $src_ip      = undef;

    # find ip for oldMac
    my @ipLog
        = $mysql_connection->selectrow_array(
        "SELECT ip FROM iplog WHERE mac='$mac' AND start_time <> 0 AND (end_time = 0 OR end_time > now())"
        );
    if (@ipLog) {
        $ip = $ipLog[0];
        $logger->debug("mac $mac has IP $ip");
    } else {
        $logger->error("coudn't find ip for $mac in table iplog.");
        return 0;
    }

    my @lines  = `/sbin/ip address show`;
    my $lineNb = 0;
    while ( ( $lineNb < scalar(@lines) ) && ( !defined($src_ip) ) ) {
        my $line = $lines[$lineNb];
        if ( $line
            =~ /inet ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\/([0-9]+)/
            )
        {
            my $tmp_src_ip   = $1;
            my $tmp_src_bits = $2;
            my $block        = new Net::Netmask("$tmp_src_ip/$tmp_src_bits");
            if ( $block->match($ip) ) {
                $src_ip = $tmp_src_ip;
                $logger->debug(
                    "found $ip in Network $tmp_src_ip/$tmp_src_bits");
            }
        }
        $lineNb++;
    }

    my $count = 1;
    while ( ( $returnValue != 1 ) && ( $count < 6 ) ) {
        my $ping = Net::Ping->new();
        if ( defined($src_ip) ) {
            $ping->bind($src_ip);
            $logger->debug("binding ping src IP to $src_ip for icmp ping");
        }

        if ( $ping->ping( $ip, 2 ) ) {
            $returnValue = 1;
            $logger->debug("$ip is alive (ping).");
        }
        $ping->close();
        $count++;
    }

    return $returnValue;
}

sub custom_getNodeInfo {
    my ( $this, $switch_ip, $switch_port, $mac, $vlan, $isPhone,
        $mysql_connection )
        = @_;
    my $new = {};
    $new->{'switch'} = $switch_ip;
    $new->{'port'}   = $switch_port;
    if ($isPhone) {
        $new->{'dhcp_fingerprint'} = '1,3,6,15,42,66,150';
    }

    return $new;
}

sub custom_getNodeInfoForAutoReg {
    my ( $this, $switch_ip, $switch_port, $mac, $vlan, $isPhone,
        $mysql_connection )
        = @_;
    my $new;
    $new->{'pid'}        = 'PF';
    $new->{'user_agent'} = 'AUTO-REGISTERED';
    $new->{'status'}     = 'reg';
    $new->{'vlan'}       = 1;
    if ($isPhone) {
        $new->{'dhcp_fingerprint'} = '1,3,6,15,42,66,150';
    }
    return $new;
}

sub custom_shouldAutoRegister {
    my ( $this, $mac, $isPhone ) = @_;
    return $isPhone;
}

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2009 Inverse groupe conseil

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
