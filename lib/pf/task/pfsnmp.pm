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
    $VOIP
);
use pf::constants qw($TRUE $FALSE);
use pf::security_event;
use pf::node;
use pf::util;
use pf::config::util;
use pf::Connection::ProfileFactory;
use pf::pfqueue::producer::redis;
use pf::Redis;
use pf::rate_limiter;

my %switch_locker;

=head2 doTask

Handle the setvlan task

=cut

my $logger = get_logger();

sub doTask {
    my $timer = pf::StatsD::Timer->new;
    my ($self, $trap) = @_;
    my $switch_id = $trap->{switchId};
    unless (defined $switch_id) {
        $logger->error("No switch found in trap");
        return;
    }

    my $switch = pf::SwitchFactory->instantiate($switch_id);
    unless ($switch) {
        $logger->error("Can not instantiate switch $switch_id !");
        return;
    }

    my $lock = $self->lockSwitch($switch, $trap);

    unless ($lock) {
        $logger->debug("cannot get a lock on the switch $switch_id");
        return;
    }
    return $self->handleTrap($switch, $trap);
}

our %TRAP_HANDLERS = (
    up                            => \&handleUpTrap,
    mac                           => \&handleMacTrap,
    down                          => \&handleDownTrap,
    roaming                       => \&handleRoamingTrap,
    dot11Deauthentication         => \&handleDot11DeauthenticationTrap,
    secureMacAddrViolation        => \&handleSecureMacAddrViolationTrap,
);


=head2 handleTrap

Handle trap

=cut

sub handleTrap {
    my ($self, $switch, $trap) = @_;
    my $trapType = $trap->{trapType};
    my $switch_id = $switch->{_id};
    my $trapMac = $trap->{trapMac};
    Log::Log4perl::MDC->put('mac', $trapMac);
    if ( defined($trapMac) && $switch->isFakeMac($trapMac) ) {
        $logger->info("MAC $trapMac is a fake MAC. Stop $trapType handling");
        goto CLEANUP;
    }

    my $role_obj = new pf::role::custom();
    my $switch_port = $trap->{trapIfIndex};
    my $weActOnThisTrap = $role_obj->doWeActOnThisTrap($switch, $switch_port, $trapType);
    if ($weActOnThisTrap == 0 ) {
        $logger->info("doWeActOnThisTrap returns false. Stop $trapType handling");
        goto CLEANUP;
    }

    unless (exists $TRAP_HANDLERS{$trapType}) {
        $logger->error("There is no handling for $trapType");
        goto CLEANUP;
    }

    eval {
        $TRAP_HANDLERS{$trapType}->($self, $switch, $trap, $role_obj);
    };
    if($@) {
        $logger->error("Error occured while handling trap : $@");
    }

CLEANUP:
    removeKillSignal($switch, $trap);
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
    my $killKey = makeKillKey($switch, $trap);
    my $redis = pf::Redis->new;
    do {
        sleep( $switch->{_macSearchesSleepInterval} ) unless ( $nbAttempts == 0 );
        my $kill = $redis->get($killKey);
        if (defined $kill && $kill == 1) {
            $logger->info("Up trap processing stopped because we recieved the kill signal for $switch_id $switch_port");
            return;
        }
        @macArray = $switch->_getMacAtIfIndex($switch_port);
        $nbAttempts++;
    } while(($nbAttempts < $switch->{_macSearchesMaxNb}) && ((time-$start) < 120) && (scalar(@macArray) == 0));

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
    my ($self, $switch, $trap, $role_obj) = @_;
    my $trapVlan = $trap->{trapVlan};
    my $switch_port = $trap->{trapIfIndex};
    my $trapOperation = $trap->{trapOperation};
    my $switch_id = $switch->{_id};
    if( $trapVlan ne $switch->getVlan($switch_port) ) {
        $logger->info( "$trapOperation trap for VLAN $trapVlan on $switch_id ifIndex $switch_port. This port is no longer in this VLAN. Flush the trap");
        return;
    }

    my $trapMac = $trap->{trapMac};
    my $trapType = $trap->{trapType};
    my $mac  = lc($trapMac);
    my $vlan = $trapVlan;
    my $wasInline;

    $logger->info("$trapOperation trap received on $switch_id ifIndex $switch_port for $mac in VLAN $vlan");

    # test if port is still in current VLAN
    if ($vlan ne $switch->getVlan($switch_port)) {
        $logger->info("$switch_id ifIndex $switch_port is no longer in this VLAN -> Do nothing");
        return;
    }

    # node_updatePF
    my $isPhone = $switch->isPhoneAtIfIndex($mac, $switch_port);
    node_update_PF($switch, $switch_port, $mac, $vlan, $isPhone, $switch->isRegistrationMode());

    # trapOperation eq 'removed'
    if ($trapOperation eq 'removed') {
        locationlog_update_end_mac($mac);

        #do nothing if it's a phone
        if ($isPhone) {
            $logger->info("MAC $mac is a VoIP phone -> Do nothing");
            return;
        }

        #do we have an open entry in locationlog for switch/port ?
        my @locationlog = locationlog_view_open_switchport_no_VoIP($switch_id, $switch_port);
        if (   (@locationlog)
            && (scalar(@locationlog) > 0)
            && (defined($locationlog[0]->{'mac'}))
            && ($locationlog[0]->{'mac'} ne ''))
        {
            if ($switch->isMacInAddressTableAtIfIndex($mac, $switch_port)) {
                $logger->info("Removed trap for MAC $mac: MAC "
                      . $locationlog[0]->{'mac'}
                      . " is still present in mac-address-table; has probably already been relearned -> DO NOTHING");
            }
            else {
                $logger->info("Removed trap for MAC $mac: MAC "
                      . $locationlog[0]->{'mac'}
                      . " DEAD -> setting data VLAN on $switch_id ifIndex $switch_port to MAC detection VLAN");
                $switch->setMacDetectionVlan($switch_port, \%switch_locker, 0);
            }
        }
        else {

            #no open entry in locationlog for switch/port
            $logger->info("no line opened for MAC $mac in locationlog.");

            #try to determine if nothing is left on switch/port (VoIP phones dont' count)
            my $nothingLeftOnSwitchPort = 0;
            my @macArray                = $switch->_getMacAtIfIndex($switch_port);
            if (!@macArray) {
                $nothingLeftOnSwitchPort = 1;
            }
            elsif (scalar(@macArray) == 1) {
                my $onlyMacLeft = $macArray[0];
                $logger->debug("only MAC found is $onlyMacLeft");
                if ($switch->isPhoneAtIfIndex($onlyMacLeft, $switch_port)) {
                    $nothingLeftOnSwitchPort = 1;
                }
            }
            else {
                $logger->debug(scalar(@macArray) . " MACs found.");
            }

            if ($nothingLeftOnSwitchPort == 1) {
                $logger->info("setting data VLAN on $switch_id ifIndex $switch_port to MAC detection VLAN");
                $switch->setMacDetectionVlan($switch_port, \%switch_locker, 0);
            }
            else {
                $logger->info("no line in locationlog and MACs ("
                      . join(",", @macArray)
                      . ") still present on this port -> Do nothing");
            }
        }

        # trapOperation eq 'learnt'
    }
    elsif ($trapOperation eq 'learnt') {

        # port security handling
        do_port_security($mac, $switch, $switch_port, $trapType);

        #do nothing if it's a phone
        if ($isPhone) {
            $logger->info("MAC $mac is a VoIP phone -> Do nothing besides updating locationlog");
            locationlog_synchronize($switch->{_id}, $switch->{_ip}, $switch->{_switchMac}, $switch_port,
                $switch->getVoiceVlan($switch_port),
                $mac, $VOIP, $WIRED_SNMP_TRAPS);
            return;
        }

        my $changeVlan = 0;

        #do we have an open entry in locationlog for switch/port ?
        my @locationlog = locationlog_view_open_switchport_no_VoIP($switch_id, $switch_port);
        if (   (@locationlog)
            && (scalar(@locationlog) > 0)
            && (defined($locationlog[0]->{'mac'}))
            && ($locationlog[0]->{'mac'} ne ''))
        {
            if ($locationlog[0]->{'mac'} =~ /^$mac$/i) {
                my $role = $role_obj->fetchRoleForNode({
                        mac             => $mac,
                        node_info       => node_attributes($mac),
                        switch          => $switch,
                        ifIndex         => $switch_port,
                        connection_type => $WIRED_SNMP_TRAPS,
                        profile         => pf::Connection::ProfileFactory->instantiate($mac)});
                my $fetchedVlan = $role->{vlan} || $switch->getVlanByName($role->{role});
                if (   ($locationlog[0]->{'vlan'} == $vlan)
                    && ($vlan == $fetchedVlan))
                {
                    $logger->info("locationlog is already up2date. Do nothing");
                }
                else {
                    $changeVlan = 1;
                }
            }
            else {

                $logger->info("Learnt trap received for $mac. Old MAC "
                      . $locationlog[0]->{'mac'}
                      . " already connected to the port according to locationlog !");
                $changeVlan = 1;
            }
        }
        else {
            $changeVlan = 1;
        }

        if ($changeVlan == 1) {
            node_determine_and_set_into_VLAN($mac, $switch, $switch_port, $WIRED_SNMP_TRAPS);
        }
    }
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

handle a secureMacAddrViolation trap for a switch

=cut

sub handleSecureMacAddrViolationTrap {
    my ($self, $switch, $trap, $role_obj) = @_;
    my $switch_port = $trap->{trapIfIndex};
    my $trapType = $trap->{trapType};
    my $switch_id = $switch->{_id};
    my $trapMac = $trap->{trapMac};
    #Get a non blocking lock
    my $lock = $switch->getExclusiveLockForScope("$switch_port:$trapMac", 1);
    unless ($lock) {
        $logger->info("Skipping handling secureMacAddrViolation trap for switch $switch_id on device $trapMac for port $switch_port");
        return;
    }
    # continue only if security traps are available on this port
    if (!$switch->isPortSecurityEnabled($switch_port)) {
        $logger->info("$trapType trap on $switch_id ifIndex $switch_port. Port Security is no " .
                                          "longer configured on the port. Flush the trap");
        return;
    }

    $logger->info("$trapType trap received on $switch_id ifIndex $switch_port for $trapMac");

    # floating network devices handling
    if (exists($ConfigFloatingDevices{$trapMac})) {
        $logger->info(
"The floating network device $trapMac has just plugged into $switch_id  port $switch_port. Enabling floating network device configuration on the port."
        );
        my $floatingDeviceManager = new pf::floatingdevice::custom();

        my $result = $floatingDeviceManager->enablePortConfig($trapMac, $switch, $switch_port, \%switch_locker);
        if (!$result) {
            $logger->info(
"An error occured while enabling floating network device configuration on port $switch_port. It may not work!"
            );
        }

        return;
    }

    # generic port security handling
    my $secureMacAddrHashRef;
    if (do_port_security(lc($trapMac), $switch, $switch_port, $trapType) eq 'stopTrapHandling') {
        $logger->info(
"MAC $trapMac is already authorized on $switch_id ifIndex $switch_port. Stopping secureMacAddrViolation trap handling here"
        );
        return;
    }

    # node_update_PF
    my $isPhone = $switch->isPhoneAtIfIndex($trapMac, $switch_port);
    node_update_PF($switch, $switch_port, $trapMac, $trap->{trapVlan}, $isPhone, $switch->isRegistrationMode());

    # synchronize locationlog with secure MAC addresses found on switchport
    my $locationlog_phone = locationlog_view_open_switchport_only_VoIP($switch_id, $switch_port);
    my @locationlog_pc = locationlog_view_open_switchport_no_VoIP($switch_id, $switch_port);

    # close locationlog entries for MACs which are not present any more on the switch as secure MACs
    $secureMacAddrHashRef = $switch->getSecureMacAddresses($switch_port);
    if (defined($locationlog_phone)
        && (!exists($secureMacAddrHashRef->{$locationlog_phone->{'mac'}})))
    {
        # TODO: not so sure about this behavior
        $logger->debug($locationlog_phone->{'mac'}
              . " (VoIP phone) has open locationlog entry at $switch_id ifIndex $switch_port but is not a secure MAC address. Closing locationlog entry"
        );
        locationlog_update_end_switchport_only_VoIP($switch_id, $switch_port);
        $locationlog_phone = undef;
    }
    if (   (@locationlog_pc)
        && (scalar(@locationlog_pc) > 0)
        && (defined($locationlog_pc[0]->{'mac'}))
        && (!exists($secureMacAddrHashRef->{$locationlog_pc[0]->{'mac'}})))
    {
        $logger->debug($locationlog_pc[0]->{'mac'}
              . " has open locationlog entry at $switch_id ifIndex $switch_port but is not a secure MAC address. Closing locationlog entry"
        );
        locationlog_update_end_mac($locationlog_pc[0]->{'mac'});
        @locationlog_pc = ();
    }

    # if trap came from a VoIP phone
    if ($isPhone) {
        my $voiceVlan = $switch->getVoiceVlan($switch_port);
        $logger->debug("$trapType trap comes from VoIP $trapMac");

        #is another VoIP phone authorized here ?
        if (defined($locationlog_phone)) {
            my $oldVoIPPhone = $locationlog_phone->{'mac'};
            $logger->debug("VoIP $oldVoIPPhone has still open locationlog entry at $switch_id ifIndex $switch_port");
            if (exists($secureMacAddrHashRef->{$oldVoIPPhone})) {
                $logger->info(
"de-authorizing VoIP $oldVoIPPhone at old location $switch_id ifIndex $switch_port VLAN $voiceVlan"
                );
                my $fakeMac = $switch->generateFakeMac(1, $switch_port);
                $switch->authorizeMAC($switch_port, $oldVoIPPhone, $fakeMac, $voiceVlan, $voiceVlan);
            }
            $logger->debug(
                "closing VoIP $oldVoIPPhone locationlog entry at $switch_id ifIndex $switch_port VLAN $voiceVlan");
            locationlog_update_end_switchport_only_VoIP($switch_id, $switch_port);
        }

        #authorize MAC
        my $secureMacAddrHashRef = $switch->getSecureMacAddresses($switch_port);
        my $old_mac_to_remove    = undef;
        foreach my $old_mac (keys %$secureMacAddrHashRef) {
            my $old_isPhone = $switch->isPhoneAtIfIndex($old_mac, $switch_port);
            if ((grep({$_ == $voiceVlan} @{$secureMacAddrHashRef->{$old_mac}}) >= 1)
                || $old_isPhone)
            {
                $old_mac_to_remove = $old_mac;
            }
        }
        if (defined($old_mac_to_remove)) {
            $logger->info(
"authorizing VoIP $trapMac (old entry $old_mac_to_remove) at new location $switch_id ifIndex $switch_port VLAN $voiceVlan"
            );
            $switch->authorizeMAC($switch_port, $old_mac_to_remove, $trapMac, $voiceVlan, $voiceVlan);
        }
        else {
            $logger->info(
                "authorizing VoIP $trapMac at new location $switch_id ifIndex $switch_port VLAN $voiceVlan");
            $switch->authorizeMAC($switch_port, 0, $trapMac, 0, $voiceVlan);
        }

        locationlog_synchronize($switch->{_id}, $switch->{_ip}, $switch->{_switchMac}, $switch_port, $voiceVlan,
            $trapMac, $VOIP, $WIRED_SNMP_TRAPS);

        # if trap came from a PC
    }
    else {
        $logger->debug("$trapType trap comes from PC $trapMac");
        if (   (@locationlog_pc)
            && (defined($locationlog_pc[0]->{'mac'})))
        {
            my $oldPC = $locationlog_pc[0]->{'mac'};
            $logger->debug("$oldPC has still open locationlog entry at $switch_id ifIndex $switch_port. Closing it");
            locationlog_update_end_mac($oldPC);
            $logger->info("authorizing $trapMac (old entry $oldPC) at new location $switch_id ifIndex $switch_port");
            my $role = $role_obj->fetchRoleForNode({
                    mac             => $trapMac,
                    node_info       => node_attributes($trapMac),
                    switch          => $switch,
                    ifIndex         => $switch_port,
                    connection_type => $WIRED_SNMP_TRAPS,
                    profile         => pf::Connection::ProfileFactory->instantiate($trapMac)});
            my $correctVlanForThisNode = $role->{vlan} || $switch->getVlanByName($role->{role});
            $switch->authorizeMAC($switch_port, $oldPC, $trapMac, $switch->getVlan($switch_port),
                $correctVlanForThisNode);

            #set the right VLAN
            $logger->debug("setting correct VLAN for $trapMac at new location $switch_id ifIndex $switch_port");
            $switch->setVlan($switch_port, $correctVlanForThisNode, \%switch_locker, $trapMac);
        }
        else {

            #authorize MAC
            my $secureMacAddrHashRef = $switch->getSecureMacAddresses($switch_port);
            my $voiceVlan            = $switch->getVoiceVlan($switch_port);
            my $old_mac_to_remove    = undef;
            foreach my $old_mac (keys %$secureMacAddrHashRef) {
                my $old_isPhone = $switch->isPhoneAtIfIndex($old_mac, $switch_port);
                if (   (grep({$_ == $voiceVlan} @{$secureMacAddrHashRef->{$old_mac}}) == 0)
                    && (!$old_isPhone))
                {
                    $old_mac_to_remove = $old_mac;
                }
            }
            my $role = $role_obj->fetchRoleForNode({
                    mac             => $trapMac,
                    node_info       => node_attributes($trapMac),
                    switch          => $switch,
                    ifIndex         => $switch_port,
                    connection_type => $WIRED_SNMP_TRAPS,
                    profile         => pf::Connection::ProfileFactory->instantiate($trapMac)});
            my $correctVlanForThisNode = $role->{vlan} || $switch->getVlanByName($role->{role});
            if (defined($old_mac_to_remove)) {
                $logger->info(
"authorizing $trapMac (old entry $old_mac_to_remove) at new location $switch_id ifIndex $switch_port"
                );
                $switch->authorizeMAC($switch_port, $old_mac_to_remove, $trapMac, $switch->getVlan($switch_port),
                    $correctVlanForThisNode);
            }
            else {
                $logger->info("authorizing $trapMac at new location $switch_id ifIndex $switch_port");
                $switch->authorizeMAC($switch_port, 0, $trapMac, 0, $correctVlanForThisNode);
            }

            #set the right VLAN
            $logger->debug("setting correct VLAN for $trapMac at new location $switch_id ifIndex $switch_port");
            $switch->setVlan($switch_port, $correctVlanForThisNode, \%switch_locker, $trapMac);
        }
    }

}

=head2 do_port_security

=cut

sub do_port_security {
    my ( $mac, $switch, $switch_port, $trapType ) = @_;

    #determine if $mac is authorized elsewhere
    my $locationlog_mac = locationlog_view_open_mac($mac);
    if ( defined($locationlog_mac) &&
         ( exists(pf::SwitchFactory->config->{$locationlog_mac->{'switch'}}) )
       ) {
        my $old_switch = $locationlog_mac->{'switch'};
        my $old_port   = $locationlog_mac->{'port'};
        my $old_vlan   = $locationlog_mac->{'vlan'};
        my $is_old_voip = is_node_voip($mac);

    #we have to enter to 'if' always when trapType eq 'secureMacAddrViolation'
        if (   ( $old_switch ne $switch->{_id} )
            || ( $old_port != $switch_port )
            || ( $trapType eq 'secureMacAddrViolation' ) )
        {
            my $oldSwitch;
            $logger->debug(
                "$mac has still open locationlog entry at $old_switch ifIndex $old_port"
            );
            if ( $old_switch eq $switch->{_id} ) {
                $oldSwitch = $switch;
            } else {
                {
                    $oldSwitch = pf::SwitchFactory->instantiate($old_switch);
                }
            }

            if (!$oldSwitch) {
                $logger->error("Can not instantiate switch $old_switch !");
            } else {
                $logger->info("Will try to check on this node's previous switch if secured entry needs to be removed. ".
                    "Old Switch IP: $old_switch");
                my $secureMacAddrHashRef = $oldSwitch->getSecureMacAddresses($old_port);
                if ( exists( $secureMacAddrHashRef->{$mac} ) ) {
                    if (   ( $old_switch eq $switch->{_id} )
                        && ( $old_port == $switch_port )
                        && ( $trapType eq 'secureMacAddrViolation' ) )
                    {
                        return 'stopTrapHandling';
                    }
                    my $fakeMac = $oldSwitch->generateFakeMac( $is_old_voip, $old_port );
                    $logger->info("de-authorizing $mac (new entry $fakeMac) at old location $old_switch ifIndex $old_port");
                    $oldSwitch->authorizeMAC( $old_port, $mac, $fakeMac,
                        ( $is_old_voip ? $oldSwitch->getVoiceVlan($old_port) : $oldSwitch->getVlan($old_port) ),
                        ( $is_old_voip ? $oldSwitch->getVoiceVlan($old_port) : $oldSwitch->getVlan($old_port) ) );
                } else {
                    $logger->info("MAC not found on node's previous switch secure table or switch inaccessible.");
                }
                locationlog_update_end_mac($mac);
            }
        }
    }

    # check if $mac is not already secured on another port (in case locationlog is outdated)
    my $secureMacAddrHashRef = $switch->getAllSecureMacAddresses();
    if ( exists( $secureMacAddrHashRef->{$mac} ) ) {
        foreach my $ifIndex ( keys( %{ $secureMacAddrHashRef->{$mac} } ) ) {
            if ( $ifIndex == $switch_port ) {
                return 'stopTrapHandling';
            } else {
                foreach my $vlan (
                    @{ $secureMacAddrHashRef->{$mac}->{$ifIndex} } )
                {
                    my $is_voice_vlan = ($vlan == $switch->getVoiceVlan($ifIndex));
                    my $fakeMac = $switch->generateFakeMac($is_voice_vlan, $ifIndex);
                    $logger->info( "$mac is a secure MAC address at "
                            . $switch->{_id}
                            . " ifIndex $ifIndex VLAN $vlan. De-authorizing (new entry $fakeMac)"
                    );
                    $switch->authorizeMAC( $ifIndex, $mac, $fakeMac, $vlan,
                        $vlan );
                }
            }
        }
    }
    return 1;
}

# sub node_update_PF
sub node_update_PF {
    my ($switch, $switch_port, $mac, $vlan, $isPhone, $registrationMode) = @_;
    my $role_obj = new pf::role::custom();

    #lowercase MAC
    $mac = lc($mac);

    if ( $switch->isFakeMac($mac) ) {
        $logger->info("MAC $mac is fake. Stopping node_update_PF");
        return 0;
    }

    #add node if necessary
    if ( !node_exist($mac) ) {
        $logger->info(
            "node $mac does not yet exist in PF database. Adding it now");
        node_add_simple($mac);
    }

    #should we auto-register?
    if ($role_obj->shouldAutoRegister({mac => $mac, switch => $switch, security_event_autoreg => 0, isPhone => $isPhone, connection_type => $WIRED_SNMP_TRAPS})) {
        # auto-register
        my %autoreg_node_defaults = $role_obj->getNodeInfoForAutoReg({ switch => $switch, ifIndex => $switch_port,
            mac => $mac, vlan => $vlan, security_event_autoreg => 0, isPhone => $isPhone, connection_type => $WIRED_SNMP_TRAPS});
        $logger->debug("auto-registering node $mac");
        if (!node_register($mac, $autoreg_node_defaults{'pid'}, %autoreg_node_defaults)) {
            $logger->error("auto-registration of node $mac failed");
            return 0;
        }
    }
    return 1;
}

# sub node_determine_and_set_into_VLAN {{{1
sub node_determine_and_set_into_VLAN {
    my ( $mac, $switch, $ifIndex, $connection_type ) = @_;

    my $role_obj = new pf::role::custom();

    my $role = $role_obj->fetchRoleForNode({ mac => $mac, node_info => node_attributes($mac), switch => $switch, ifIndex => $ifIndex, connection_type => $connection_type, profile => pf::Connection::ProfileFactory->instantiate($mac)});
    my $vlan = $role->{vlan} || $switch->getVlanByName($role->{role});

    $switch->setVlan(
        $ifIndex,
        $vlan,
        \%switch_locker,
        $mac
    );
}

=head2 lockSwitch

lockSwitch

=cut

sub lockSwitch {
    my ($self, $switch, $trap) = @_;
    my $lock = $switch->getExclusiveLockForScope("ifindex:" . $trap->{trapIfIndex}, 1);
    unless ($lock) {
        # If IfIndex switch combo is being worked on requeue trap
        $self->requeueTrap($trap);
        $logger->debug("requeuing trap for $switch->{_id} : $trap->{trapIfIndex}");
        # If there is a down trap coming in then signal the up trap to stop
        if ($trap->{trapType} eq 'down') {
            my $redis = pf::Redis->new;
            my $key = makeKillKey($switch, $trap);
            $redis->set($key, 1);
        }
    }
    return $lock;
}

=head2 makeKillKey

makeKillKey

=cut

sub makeKillKey {
    my ($switch, $trap) = @_;
    my $key = "Kill:$switch->{_id}:$trap->{trapIfIndex}";
    return $key;
}

=head2 removeKillSignal

removeKillSignal

=cut

sub removeKillSignal {
    my ($switch, $trap) = @_;
    my $redis = pf::Redis->new();
    my $killKey = makeKillKey($switch, $trap);
    $redis->del($killKey);
    return ;
}

=head2 requeueTrap

requeueTrap

=cut

sub requeueTrap {
    my ($self, $args) = @_;
    my $client = pf::pfqueue::producer::redis->new();
    $client->submit("pfsnmp", "pfsnmp", $args);
    return ;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
