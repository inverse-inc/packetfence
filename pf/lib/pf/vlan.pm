package pf::vlan;

=head1 NAME

pf::vlan - Object oriented module for VLAN isolation oriented functions 

=head1 SYNOPSIS

The pf::vlan module contains the functions necessary for the VLAN isolation.

=cut

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;
use pf::config;
use pf::node qw(node_view node_add_simple node_exist);
use pf::util;
use pf::violation qw(violation_count_trap violation_exist_open violation_view_top);
use pf::SwitchFactory;
use threads;
use threads::shared;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

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
        $logger->info("$mac has $open_violation_count open violations(s) with action=trap;
                      it might belong into another VLAN (isolation or other).");

        # By default we assume that we put the user in isolationVlan unless proven otherwise
        my $vlan = "isolationVlan";

        # fetch top violation
        $logger->debug("What is the highest priority violation for this host?");
        my $top_violation = violation_view_top($mac);
        if ($top_violation) {

            # get violation id
            my $vid=$top_violation->{'vid'};

            # find violation class based on violation id
            require pf::class;
            my $class=pf::class::class_view($vid);
            if ($class) {

                # override violation destination vlan
                $vlan = $class->{'vlan'};
                $logger->debug("Found target vlan parameter for this violation: $vlan");

            } else {
                $logger->warn("Could not find class entry for violation $vid.
                              Setting target vlan to switches.conf's isolationVlan");
            }
        } else {
            $logger->warn("Could not find highest priority open violation for $mac.
                          Setting target vlan to switches.conf's isolationVlan");
        }

        # Asking the switch to give us its configured vlan number for the vlan returned for the violation
        my $switchFactory = new pf::SwitchFactory(
            -configFile => "$conf_dir/switches.conf" );
        my $switch = $switchFactory->instantiate($switch_ip);
        # TODO: get rid of the _ character for the vlan variables (refactoring)
        $correctVlanForThisMAC = $switch->{"_".$vlan};
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
    if ( $trapType eq 'desAssociate' ) {
        return 1;
    }
    if ( $trapType eq 'dot11Deauthentication' ) {
        return 1;
    }

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

=item custom_getCorrectVlan - returns normal vlan

This sub is meant to be overloaded in lib/pf/vlan/custom.pm if the default 
version doesn't do the right thing for you. By default it will return the 
normal vlan for the given switch if defined, otherwise it will return the normal
vlan for the whole network.

=cut
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

    # Grab switch config
    my $switchFactory = new pf::SwitchFactory(-configFile => "$conf_dir/switches.conf");
    my %Config = %{$switchFactory->{_config}};

    # return switch-specific normal vlan or default normal vlan (if switch-specific normal vlan not defined)
    return ($Config{$switch_ip}{'normalVlan'} || $Config{'default'}{'normalVlan'});
}

sub custom_getNodeInfo {
    my ( $this, $switch_ip, $switch_port, $mac, $vlan, $isPhone,
        $mysql_connection )
        = @_;
    my $new = {};
    $new->{'switch'} = $switch_ip;
    $new->{'port'}   = $switch_port;
    if ($isPhone) {
        #$new->{'dhcp_fingerprint'} = '1,3,6,15,42,66,150';
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

=back

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
