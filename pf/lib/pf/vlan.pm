package pf::vlan;

=head1 NAME

pf::vlan - Object oriented module for VLAN isolation oriented functions 

=head1 SYNOPSIS

The pf::vlan module contains the functions necessary for the VLAN isolation.
All the behavior contained here can be overridden in lib/pf/vlan/custom.pm.

=cut

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;
use pf::config;
use pf::node qw(node_view node_add_simple node_exist);
use pf::util;
use pf::violation qw(violation_count_trap violation_exist_open violation_view_top);
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
    my ( $this, $mac, $switch, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::vlan');
    Log::Log4perl::MDC->put( 'tid', threads->self->tid() );

    my $correctVlanForThisMAC;
    my $open_violation_count = violation_count_trap($mac);

    if ( $open_violation_count > 0 ) {
        $logger->info("$mac has $open_violation_count open violations(s) with action=trap; ". 
                      "it might belong into another VLAN (isolation or other).");

        # By default we assume that we put the user in isolationVlan unless proven otherwise
        my $vlan = "isolationVlan";

        # fetch top violation
        $logger->debug("What is the highest priority violation for this host?");
        my $top_violation = violation_view_top($mac);
        if ($top_violation && defined($top_violation->{'vid'})) {

            # get violation id
            my $vid=$top_violation->{'vid'};

            # find violation class based on violation id
            require pf::class;
            my $class=pf::class::class_view($vid);
            if ($class && defined($class->{'vlan'})) {

                # override violation destination vlan
                $vlan = $class->{'vlan'};
                $logger->debug("Found target vlan parameter for this violation: $vlan");

            } else {
                $logger->warn("Could not find class entry for violation $vid. ".
                              "Setting target vlan to switches.conf's isolationVlan");
            }
        } else {
            $logger->warn("Could not find highest priority open violation for $mac. ".
                          "Setting target vlan to switches.conf's isolationVlan");
        }

        # Asking the switch to give us its configured vlan number for the vlan returned for the violation
        # TODO: get rid of the _ character for the vlan variables (refactoring)
        $correctVlanForThisMAC = $switch->{"_".$vlan};
    } else {
        if ( !node_exist($mac) ) {
            $logger->info("node $mac does not yet exist in PF database. Adding it now");
            node_add_simple($mac);
        }
        my $node_info = node_view($mac);
        if ( isenabled( $Config{'trapping'}{'registration'} ) ) {
            if (   ( !defined($node_info) )
                || ( $node_info->{'status'} eq 'unreg' ) )
            {
                $logger->info("MAC: $mac is unregistered; belongs into registration VLAN");
                $correctVlanForThisMAC = $switch->{_registrationVlan};
            } else {

                #TODO: find a way to cleanly wrap this
                $correctVlanForThisMAC = $this->custom_getCorrectVlan( $switch, $ifIndex, $mac, $node_info->{status}, $node_info->{vlan}, $node_info->{pid} );
                $logger->info( "MAC: $mac, PID: " . $node_info->{pid} . ", Status: " . $node_info->{status} . ", VLAN: $correctVlanForThisMAC" );
            }
        } else {
            #TODO: find a way to cleanly wrap this
            $correctVlanForThisMAC = $this->custom_getCorrectVlan( $switch, $ifIndex, $mac, $node_info->{status}, ( $node_info->{vlan} || $switch->{_normalVlan} ), $node_info->{pid} );
            $logger->info( "MAC: $mac, PID: " . $node_info->{pid} . ", Status: " . $node_info->{status} . ", VLAN: $correctVlanForThisMAC" );
        }
    }
    return $correctVlanForThisMAC;
}

# don't act on configured uplinks
sub custom_doWeActOnThisTrap {
    my ( $this, $switch, $ifIndex, $trapType ) = @_;
    my $logger = Log::Log4perl->get_logger();
    Log::Log4perl::MDC->put( 'tid', threads->self->tid() );

    # TODO we should rethink the position of this code, it's in the wrong test but at the good spot in the flow
    my $weActOnThisTrap = 0;
    if ( $trapType eq 'desAssociate' ) {
        return 1;
    }
    if ( $trapType eq 'dot11Deauthentication' ) {
        # we no longer act on dot11Deauth traps see bug #880
        # http://www.packetfence.org/mantis/view.php?id=880
        return 0;
    }

    my $ifType = $switch->getIfType($ifIndex);
    if ( ( $ifType == 6 ) || ( $ifType == 117 ) ) {
        my @upLinks = $switch->getUpLinks();
        if ( $upLinks[0] == -1 ) {
            $logger->warn("Can't determine Uplinks for the switch -> do nothing");
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

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default 
version doesn't do the right thing for you. By default it will return the 
normal vlan for the given switch if defined, otherwise it will return the normal
vlan for the whole network.

=cut
sub custom_getCorrectVlan {

    #$switch is the switch object (pf::SNMP)
    #$ifIndex is the ifIndex of the computer connected to
    #$mac is the mac connected
    #$status is the node's status in the database
    #$vlan is the vlan set for this node in the database
    #$pid is the owner of this node in the database
    my ( $this, $switch, $ifIndex, $mac, $status, $vlan, $pid ) = @_;
    my $logger = Log::Log4perl->get_logger();
    Log::Log4perl::MDC->put( 'tid', threads->self->tid() );

    # if switch object not correct, return default vlan
    if (ref($switch) ne 'HASH' || !defined($switch->{_normalVlan})) {
        $logger->warn("Did not return correct VLAN: Invalid switch. Will return default VLAN as a fallback");

        # Grab switch config
        my $switchFactory = new pf::SwitchFactory(-configFile => "$conf_dir/switches.conf");
        my %Config = %{$switchFactory->{_config}};

        return $Config{'default'}{'normalVlan'};
    }

    # return switch-specific normal vlan or default normal vlan (if switch-specific normal vlan not defined)
    return $switch->{_normalVlan};
}

=item getNodeUpdatedInfo - updated fields when a node changed status

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default 
version doesn't do the right thing for you. By default it will return the 
switch_ip and the switch_port to update the node table entry.

=cut
sub getNodeUpdatedInfo {
    my ($this, $switch_ip, $switch_port, $mac, $vlan, $isPhone) = @_;

    my %node_info = (
        switch => $switch_ip,
        port   => $switch_port,
    );

    # example of customization: set dhcpfingerprint when isPhone is == 1
    # if ($isPhone) {
    #    $node_info{'dhcp_fingerprint'} = '1,3,6,15,42,66,150';
    #}

    return %node_info;
}

=item getNodeInfoForAutoReg - basic information returned for auto-registered node

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default 
version doesn't do the right thing for you.

$origin is the string representing where the autoregistration is comming from. Possibles values are:
switch-config or violation.

$isPhone is set to 1 if device is considered an IP Phone.

=cut 
sub getNodeInfoForAutoReg {
    my ($this, $switch_ip, $switch_port, $mac, $vlan, $origin, $isPhone) = @_;

    # we do not set a default VLAN here so that node_register will set the default normalVlan from switches.conf
    my %node_info = (
        pid             => $default_pid,
        notes           => 'AUTO-REGISTERED',
        status          => 'reg',
        auto_registered => 1, # tells node_register to autoreg
    );

    # if we are called from pfsetvlan (autoreg for switch-config), we can set switch and vlan info
    if ($origin =~ /^switch-config$/) {
        $node_info{'switch'} = $switch_ip;
        $node_info{'port'}   = $switch_port;
        $node_info{'vlan'}   = $vlan;
    }

    # put a phone dhcp fingerprint if it's a phone
    if ($isPhone) {
        $node_info{'dhcp_fingerprint'} = '1,3,6,15,42,66,150';
    }

    return %node_info;
}

=item shouldAutoRegister - do we auto-register this node?

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default 
version doesn't do the right thing for you.

$origin is the string representing where the autoregistration is comming from. Possibles values are:
switch-config or violation.

$isPhone is set to 1 if device is considered a IP Phone.

returns 1 if we should register, 0 otherwise

=cut
sub shouldAutoRegister {
    my ($this, $mac, $origin, $isPhone) = @_;
    my $logger = Log::Log4perl->get_logger();

    $logger->trace("asked if should auto-register device");
    # handling switch-config first because I think it's the most important to honor
    if (defined($origin) && $origin =~ /^switch-config$/) {
        $logger->trace("returned yes because it's from the switch's config");
        return 1;

    # if we have a violation action set to autoreg
    } elsif (defined($origin) && $origin =~ /^violation$/) {
        $logger->trace("returned yes because it's from a violation");
        return 1;
    }

    if ($isPhone) {
        $logger->trace("returned yes because it's an ip phone");
        return $isPhone;
    }

    # otherwise don't autoreg
    return 0;
}

=back

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2010 Inverse inc.

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
