package pf::task::pfsnmp;

=head1 NAME

pf::task::pfsnmp -

=cut

=head1 DESCRIPTION

pf::task::pfsnmp

=cut

use strict;
use warnings;
use pf::log;
use pf::SwitchFactory;
use pf::role::custom;
use pf::locationlog;
use pf::inline::custom;
use pf::floatingdevice::custom;
use pf::config qw(
    $NO_VOIP
    %ConfigFloatingDevices
    $WIRED_SNMP_TRAPS
    %Config
    $WIPS_VID
);
use pf::constants qw($TRUE $FALSE);
use pf::violation;
use pf::node;
use pf::util;

my %switch_locker;

=head2 doTask

Handle the setvlan task

=cut

my $logger = get_logger();

sub doTask {
    my ($self, $args) = @_;
    use Data::Dumper;get_logger->info(Dumper($args));
    my ($trapInfo, $variables) = @$args;
    my $switch_id = $trapInfo->{switchIp};
    unless (defined $switch_id) {
        $logger->error("No switch found in trap");
        return;
    }

    my $switch = pf::SwitchFactory->instantiate($switch_id);
    unless ($switch) {
        $logger->error("Can not instantiate switch $switch_id !");
        return;
    }

    my $trap = $switch->normalizeTrap($args);
    unless ($trap) {
        $logger->error("Unable to normalize trap sent from $switch_id ");
        return;
    }
    
    # Set default values
    for my $key (qw(trapVlan trapOperation trapMac trapSSID trapClientUserName trapIfIndex trapConnectionType)) {
        $trap->{$key} //= '';
    }

    unless ($switch->handleTrap($trap)) {
        $logger->error("Skipping general trap handling for $switch_id");
        return;
    }

    return $self->handleTrap($switch, $trap);
}

our %TRAP_HANDLERS = (
    up                            => \&handleUpTrap,
    mac                           => \&handleMacTrap,
    down                          => \&handleDownTrap,
    roaming                       => \&handleRoamingTrap,
    wirelessIPS                   => \&handleWirelessIPS,
    reAssignVlan                  => \&handleReAssignVlanTrap,
    desAssociate                  => \&handleDesAssociateTrap,
    firewallRequest               => \&handleFirewallRequestTrap,
    dot11Deauthentication         => \&handleDot11DeauthenticationTrap,
    secureMacAddrViolation        => \&handleSecureMacAddrViolationTrap,
    secureDynamicMacAddrViolation => \&handleSecureDynamicMacAddrViolationTrap,
);


=head2 handleTrap

Handle trap

=cut

sub handleTrap {
    my ($self, $switch, $trap) = @_;
    my $trapType = $trap->{trapType};
    my $switch_id = $switch->{_id};
    if ($trapType eq 'unknown') {
        $logger->debug("ignoring unknown trap for switch_id");
        return;
    }

    my $trapMac = $trap->{trapMac};
    if ( defined($trapMac) && $switch->isFakeMac($trapMac) ) {
        $logger->info("MAC $trapMac is a fake MAC. Stop $trapType handling");
        return;
    }

    my $role_obj = new pf::role::custom();
    my $switch_port = $trap->{trapIfIndex};
    my $weActOnThisTrap = $role_obj->doWeActOnThisTrap($switch, $switch_port, $trapType);
    if ($weActOnThisTrap == 0 ) {
        $logger->info("doWeActOnThisTrap returns false. Stop $trapType handling");
        return;
    }

    unless (exists $TRAP_HANDLERS{$trapType}) {
        $logger->error("There is no handling for $trapType");
        return;
    }

    eval {
        $TRAP_HANDLERS{$trapType}->($self, $switch, $trap);
    };
    if($@) {
        $logger->error("Error occured while handling trap : $@");
    }
    $switch->disconnectRead();
    $switch->disconnectWrite();
    return;
}

=head2 handleUpTrap

handle a up trap sent by a switch

=cut

sub handleUpTrap {
    my ($self, $switch, $trap) = @_;
    my $switch_id   = $switch->{_id};
    my $switch_port = $trap->{trapIfIndex};
    my $trapType = $trap->{trapType};
    $logger->info("$trapType trap received on $switch_id ifIndex $switch_port");

    # continue only if security traps are not available on this port
    if ($switch->isPortSecurityEnabled($switch_port)) {
        $logger->info("security traps are configured on this switch port. Stopping UP trap handling here");
        return;
    }

    # floating network devices handling
    # if the last device pluggoed in that port is a floating network device then we handle it
    my @locationlog_switchport = locationlog_view_open_switchport_no_VoIP($switch_id, $switch_port);
    my $valid_locationlog_entry = (@locationlog_switchport && ref($locationlog_switchport[0]) eq 'HASH');
    if ($valid_locationlog_entry && (exists($ConfigFloatingDevices{$locationlog_switchport[0]->{mac}}))) {
        $logger->info("The logs shows that the last device pluged was a floating network device. We may have missed"
              . "the LinkDown trap. Disabling floating network device configuration on the port.");
        my $floatingDeviceManager = new pf::floatingdevice::custom();

        # shut the port down
        $logger->debug("Shuting down port $switch_port");
        if (!$switch->setAdminStatus($switch_port, $SNMP::DOWN)) {
            $logger->error("An error occured while shuting down port $switch_port. The port may not work!");
        }

        my $result = $floatingDeviceManager->disablePortConfig($locationlog_switchport[0]->{mac},
            $switch, $switch_port, \%switch_locker);

        if (!$result) {
            $logger->error("An error occured while disabling floating network device configuration on port "
                  . " $switch_port. The port may not work!");
        }

        # open the port
        $logger->debug("Re-opening port $switch_port");
        if (!$switch->setAdminStatus($switch_port, $SNMP::UP)) {
            $logger->error("An error occured while opening port $switch_port. The port may not work!");
        }
        return;
    }

    # set into MAC detection VLAN
    $logger->info("setting $switch_id port $switch_port to MAC detection VLAN");
    $switch->setMacDetectionVlan($switch_port, \%switch_locker, 1);

    # continue only if MAC learnt traps are not available on this port
    if ($switch->isLearntTrapsEnabled($switch_port)) {
        $logger->info("MAC learnt traps are configured on this switch port. Stopping UP trap handling here");
        return;
    }

    my $start    = time;
    my @macArray = ();
    my $secureMacAddrHashRef;
    my $nbAttempts = 0;

    #Rework retry logic blocking logic
    @macArray = $switch->_getMacAtIfIndex($switch_port);

    if (scalar(@macArray) == 0) {
        if ($nbAttempts >= $switch->{_macSearchesMaxNb}) {
            $logger->warn("Tried to grab MAC address at ifIndex $switch_port "
                  . "on switch "
                  . $switch->{_id} . " "
                  . $switch->{_macSearchesMaxNb}
                  . " times and failed");
        }
        else {
            $logger->warn("Tried to grab MAC address at ifIndex $switch_port "
                  . "on switch "
                  . $switch->{_id}
                  . " for 2 minutes and failed");
        }
    }

    # node_update_PF
    my @tmpMacArray = ();
    if (scalar(@macArray) > 0) {

        #remove VoIP phones from list

        foreach my $currentMac (@macArray) {
            if ($switch->isPhoneAtIfIndex($currentMac, $switch_port)) {

                #this Mac is a phone
                $logger->debug("$currentMac is a phone");
                node_update_PF($switch, $switch_port, $currentMac, '', $TRUE, $switch->isRegistrationMode());
            }
            else {
                push(@tmpMacArray, $currentMac);
                node_update_PF($switch, $switch_port, $currentMac, '', $FALSE, $switch->isRegistrationMode());
            }
        }
    }
    @macArray = @tmpMacArray;

    # number of MACs found > 1
    if (scalar(@macArray) > 1) {
        $logger->info("several MACs found. Do nothing");

    }
    elsif (scalar(@macArray) == 1) {

        my $mac = lc($macArray[0]);

        do_port_security($mac, $switch, $switch_port, $trapType);

        node_determine_and_set_into_VLAN($mac, $switch, $switch_port, $WIRED_SNMP_TRAPS);

    }
    else {
        $logger->info("cannot find MAC (maybe we found a VoIP, but they don't count here). Do nothing");
    }

}

=head2 handleMacTrap

handle a mac trap sent by a switch

=cut

sub handleMacTrap {
    my ($self, $switch, $trap) = @_;
}

=head2 handleDownTrap

handle a down trap sent by a switch

=cut

sub handleDownTrap {
    my ($self, $switch, $trap) = @_;
    my $switch_id = $switch->{_id};
    my $switch_port = $trap->{trapIfIndex};
    $logger->info("$trap->{trapType} trap received on $switch_id ifIndex $switch_port");

    # continue only if security traps are not available on this port 
    if ($switch->isPortSecurityEnabled($switch_port)) {
        $logger->info("security traps are configured on this switch port. Stopping DOWN trap handling here");
        return;
    }

    # floating network devices handling
    # if the last device pluggoed in that port is a floating network device then we handle it
    my @locationlog_switchport = locationlog_view_open_switchport_no_VoIP($switch_id, $switch_port);
    my $valid_locationlog_entry = (@locationlog_switchport && ref($locationlog_switchport[0]) eq 'HASH');
    if ($valid_locationlog_entry && (exists($ConfigFloatingDevices{$locationlog_switchport[0]->{mac}}))) {
        my $mac = $locationlog_switchport[0]->{mac};
        $logger->info("The floating network device $mac has just unplugged from $switch_id port $switch_port. "
              . "Disabling floating network device configuration on the port.");
        my $floatingDeviceManager = new pf::floatingdevice::custom();

        my $result = $floatingDeviceManager->disablePortConfig($mac, $switch, $switch_port, \%switch_locker);
        if (!$result) {
            $logger->info("An error occured while disabling floating network device configuration on port "
                  . "$switch_port. The port may not work!");
        }
        return;
    }

    # set into MAC detection VLAN
    $logger->info("setting $switch_id port $switch_port to MAC detection VLAN");
    $switch->setMacDetectionVlan($switch_port, \%switch_locker, 1);
}

=head2 handleRoamingTrap

handle a down roaming sent by a switch

=cut

sub handleRoamingTrap {
    my ($self, $switch, $trap) = @_;
    locationlog_synchronize($switch->{_id}, $switch->{_ip}, $switch->{_switchMac}, $trap->{trapIfIndex}, $trap->{trapVlan}, $trap->{trapMac}, $NO_VOIP, $trap->{trapConnectionType}, undef, $trap->{trapClientUserName}, $trap->{trapSSID} );
}

=head2 handleReAssignVlanTrap

=cut

sub handleReAssignVlanTrap {
    my ($self, $switch, $trap) = @_;
}

=head2 handleDesAssociateTrap

=cut

sub handleDesAssociateTrap {
    my ($self, $switch, $trap) = @_;
}

=head2 handleFirewallRequestTrap

=cut

sub handleFirewallRequestTrap {
    my ($self, $switch, $trap) = @_;
    my $trapMac = $trap->{trapMac};
    $logger->info("$trap->{trapType} trap received for inline client: $trapMac. Modifying firewall.");

    # verify if firewall rule is ok
    my $inline = new pf::inline::custom();
    $inline->performInlineEnforcement($trapMac);
}

=head2 handleDot11DeauthenticationTrap

=cut

sub handleDot11DeauthenticationTrap {
    my ($self, $switch, $trap) = @_;
    my $mac = $trap->{trapMac};
    $logger->info("$trap->{trapType} trap received on $switch->{_id} for wireless client $mac. closing locationlog entry");

    # we close the line opened for the mac. If there is no line, this won't do anything
    locationlog_update_end_mac( $mac );
}

=head2 handleSecureMacAddrViolationTrap

=cut

sub handleSecureMacAddrViolationTrap {
    my ($self, $switch, $trap) = @_;
}

=head2 handleSecureDynamicMacAddrViolationTrap

=cut

sub handleSecureDynamicMacAddrViolationTrap {
    my ($self, $switch, $trap) = @_;
}

=head2 handleWirelessIPS

handle a wirelessIPS trap for a switch

=cut

sub handleWirelessIPS {
    return if (isdisabled($Config{'trapping'}{'wireless_ips'}));
    my ($self, $switch, $trap) = @_;
    my $trapMac = clean_mac($trap->{trapMac});

    # Grab the OUI part
    $trapMac =~ /^([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}).*$/;
    my $mac   = $1;
    my @nodes = node_search($mac);
    unless($nodes[0]) {
        $logger->info("WIPS: Cannot find a valid match for $trapMac in the database, do nothing");
        return;
    }

    #compare the strings, and output the percentage of match
    my $match;
    my %matchingNodes;
    my $threshold = $Config{'trapping'}{'wireless_ips_threshold'};

    foreach (@nodes) {
        for (my $i = 8 ; $i <= length($trapMac) ; $i++) {
            $match = substr($trapMac, 1, $i);

            if ($_ !~ /$match/) {
                my $percent = ($i / 16) * 100;
                my $rounded = floor(floor($percent) / 5) * 5;
                if ($rounded >= $threshold) {
                    $matchingNodes{$_} = $rounded;
                }
                else {
                    $logger->info(
"WIPS: Found a valid MAC $_ , but the reliability is below the configured threshold, do nothing"
                    );
                }
                last;
            }
        }
    }

    #TODO
    #For each matching nodes, fire an internal WIDS violation
    foreach my $keys (keys %matchingNodes) {
        $logger->info("We will isolate $keys, threshold is $matchingNodes{$keys} percent");
        violation_trigger({'mac' => $keys, 'tid' => $WIPS_VID, 'type' => 'INTERNAL'});
    }

    return;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

1;

