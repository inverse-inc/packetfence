package pf::vlan;

=head1 NAME

pf::vlan - Object oriented module for VLAN isolation oriented functions 

=head1 SYNOPSIS

The pf::vlan module contains the functions necessary for the VLAN isolation.
All the behavior contained here can be overridden in lib/pf/vlan/custom.pm.

=cut

use strict;
use warnings;

use Log::Log4perl;
use threads;
use threads::shared;

use pf::config;
use pf::node qw(node_attributes node_exist);
use pf::SNMP::constants;
use pf::util;
use pf::violation qw(violation_count_trap violation_exist_open violation_view_top);

use pf::authentication;
use pf::Authentication::constants;

our $VERSION = 1.04;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

=item new

Constructor.
Usually you don't want to call this constructor but use the pf::vlan::custom subclass instead.

=cut
sub new {
    my $logger = Log::Log4perl::get_logger("pf::vlan");
    $logger->debug("instantiating new pf::vlan object");
    my ( $class, %argv ) = @_;
    my $this = bless {}, $class;
    return $this;
}

=item fetchVlanForNode

Answers the question: What VLAN should a given node be put into?

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default 
version doesn't do the right thing for you. However it is very generic, 
maybe what you are looking for needs to be done in getViolationVlan, 
getRegistrationVlan or getNormalVlan.

=cut
sub fetchVlanForNode {
    my ( $this, $mac, $switch, $ifIndex, $connection_type, $user_name, $ssid ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::vlan');

    my $node_info = node_attributes($mac);

    if ($this->isInlineTrigger($switch,$ifIndex,$mac,$ssid)) {
        $logger->info("Inline trigger match, the node is in inline mode");
        my $inline = $this->getInlineVlan($switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid);
        $logger->info("MAC: $mac, PID: " .$node_info->{pid}. ", Status: " .$node_info->{status}. ". Returned VLAN: $inline");
        return ( $inline , 1 );
    }

    # violation handling
    my $violation = $this->getViolationVlan($switch, $ifIndex, $mac, $connection_type, $user_name, $ssid);
    if (defined($violation) && $violation != 0) {
        return ( $violation, 0 );
    } elsif (!defined($violation)) {
        $logger->warn("There was a problem identifying vlan for violation. Will act as if there was no violation.");
    }

    # there were no violation, now onto registration handling
    my $registration = $this->getRegistrationVlan($switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid);
    if (defined($registration) && $registration != 0) {
        return ( $registration , 0 );
    }

    # no violation, not unregistered, we are now handling a normal vlan
    my $vlan = $this->getNormalVlan($switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid);
    if (!defined($vlan)) {
        $logger->warn("Resolved VLAN for node is not properly defined: Replacing with macDetectionVlan");
        $vlan = $switch->getVlanByName('macDetection');
    }
    $logger->info("MAC: $mac, PID: " .$node_info->{pid}. ", Status: " .$node_info->{status}. ". Returned VLAN: $vlan");
    return ( $vlan, 0 );
}

=item doWeActOnThisTrap  

Don't act on uplinks, unkown interface types or some traps we are not interested in.

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default 
version doesn't do the right thing for you. 

=cut
sub doWeActOnThisTrap {
    my ( $this, $switch, $ifIndex, $trapType ) = @_;
    my $logger = Log::Log4perl->get_logger();

    # TODO we should rethink the position of this code, it's in the wrong test but at the good spot in the flow
    my $weActOnThisTrap = 0;
    if ( $trapType eq 'desAssociate' || $trapType eq 'firewallRequest' || $trapType eq 'roaming') {
        return 1;
    }
    if ( $trapType eq 'dot11Deauthentication' ) {
        # we no longer act on dot11Deauth traps see bug #880
        # http://www.packetfence.org/mantis/view.php?id=880
        return 0;
    }

    # ifTypes: http://www.iana.org/assignments/ianaiftype-mib
    my $ifType = $switch->getIfType($ifIndex);
    # see ifType documentation in pf::SNMP::constants
    if ( ( $ifType == $SNMP::ETHERNET_CSMACD ) || ( $ifType == $SNMP::GIGABIT_ETHERNET ) ) {
        my @upLinks = $switch->getUpLinks();
        if ( @upLinks && $upLinks[0] == -1 ) {
            $logger->warn("Can't determine Uplinks for the switch $switch->{_ip} -> do nothing");
        } else {
            if ( grep( { $_ == $ifIndex } @upLinks ) == 0 ) {
                $weActOnThisTrap = 1;
            } else {
                $logger->info( "$trapType trap received on $switch->{_ip} "
                    . "ifindex $ifIndex which is uplink and we don't manage uplinks"
                );
            }
        }
    } else {
        $logger->info( "$trapType trap received on $switch->{_ip} "
            . "ifindex $ifIndex which is not ethernetCsmacd"
        );
    }
    return $weActOnThisTrap;
}

=item getViolationVlan

Returns the violation vlan for a node (if any)
        
This sub is meant to be overridden in lib/pf/vlan/custom.pm if you have specific isolation needs.
    
Return values:
    
=over 6 
        
=item * -1 means kick-out the node (not always supported)
    
=item * 0 means no violation for this node
    
=item * undef means there was an error
    
=item * anything else is either a VLAN name string or a VLAN number
    
=back

=cut
sub getViolationVlan {
    # $switch is the switch object (pf::SNMP)
    # $ifIndex is the ifIndex of the computer connected to
    # $mac is the mac connected
    # $conn_type is set to the connnection type expressed as the constant in pf::config
    # $user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    # $ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
    my ($this, $switch, $ifIndex, $mac, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl->get_logger();

    my $open_violation_count = violation_count_trap($mac);
    if ($open_violation_count == 0) {
        return 0;
    }

    $logger->debug("$mac has $open_violation_count open violations(s) with action=trap; ".
                   "it might belong into another VLAN (isolation or other).");

    # By default we assume that we put the user in isolation vlan unless proven otherwise
    my $vlan = "isolation";

    # fetch top violation
    $logger->trace("What is the highest priority violation for this host?");
    my $top_violation = violation_view_top($mac);
    # fetching top violation failed
    if (!$top_violation || !defined($top_violation->{'vid'})) {
    
        $logger->warn("Could not find highest priority open violation for $mac. ".
                      "Setting target vlan to switches.conf's isolationVlan");
        return $switch->getVlanByName($vlan);
    }   
        
    # get violation id
    my $vid = $top_violation->{'vid'};
    
    # find violation class based on violation id
    require pf::class;
    my $class = pf::class::class_view($vid);
    # finding violation class based on violation id failed
    if (!$class || !defined($class->{'vlan'})) {

        $logger->warn("Could not find class entry for violation $vid. ".
                      "Setting target vlan to switches.conf's isolationVlan");
        return $switch->getVlanByName($vlan);
    }

    # override violation destination vlan
    $vlan = $class->{'vlan'};

    # example of a specific violation that packetfence should block instead of isolate
    # ex: block iPods / iPhones because they tend to overload controllers, radius and captive portal in isolation vlan
    # if ($vid == '1100004') { return -1; }

    # Asking the switch to give us its configured vlan number for the vlan returned for the violation
    my $vlan_number = $switch->getVlanByName($vlan);
    if (defined($vlan_number)) {
        $logger->info("highest priority violation for $mac is $vid. Target VLAN for violation: $vlan ($vlan_number)");
    }
    return $vlan_number;
}


=item getRegistrationVlan

Returns the registration vlan for a node if registration is enabled and node is unregistered or pending.

This sub is meant to be overridden in lib/pf/vlan/custom.pm if you have specific registration needs.

Return values:

=over 6

=item * 0 means node is already registered

=item * undef means there was an error

=item * anything else is either a VLAN name string or a VLAN number
    
=back

=cut
sub getRegistrationVlan {
    #$switch is the switch object (pf::SNMP)
    #$ifIndex is the ifIndex of the computer connected to
    #$mac is the mac connected
    #$node_info is the node info hashref (result of pf::node's node_attributes on $mac)
    #$conn_type is set to the connnection type expressed as the constant in pf::config 
    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl->get_logger();

    # trapping on registration is enabled
    if (!isenabled($Config{'trapping'}{'registration'})) {
        $logger->debug("Registration trapping disabled: skipping node is registered test");
        return 0;
    }

    if (!defined($node_info)) {
        $logger->info("MAC: $mac doesn't have a node entry; belongs into registration VLAN");
        return $switch->getVlanByName('registration');
    }

    my $n_status = $node_info->{'status'};
    if ($n_status eq $pf::node::STATUS_UNREGISTERED || $n_status eq $pf::node::STATUS_PENDING) {
        $logger->info("MAC: $mac is of status $n_status; belongs into registration VLAN");
        return $switch->getVlanByName('registration');
    }
    return 0;
}

=item getNormalVlan

Returns normal vlan

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default 
version doesn't do the right thing for you. By default it will return the 
normal vlan for the given switch if defined, otherwise it will return the normal
vlan for the whole network.

Return values:

=over 6

=item * -1 means kick-out the node (not always supported)

=item * 0 means node is already registered

=item * undef means there was an error

=item * anything else is either a VLAN name string or a VLAN number
    
=back

=cut
# Note: if you add more examples here, remember to sync them in pf::vlan::custom
sub getNormalVlan {
    #$switch is the switch object (pf::SNMP)
    #$ifIndex is the ifIndex of the computer connected to
    #$mac is the mac connected
    #$node_info is the node info hashref (result of pf::node's node_attributes on $mac)
    #$conn_type is set to the connnection type expressed as the constant in pf::config 
    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl->get_logger();
    my $role = "";

    $logger->debug("Trying to determine VLAN from role.");
    if (defined $user_name && (($connection_type & $EAP) == $EAP)) {
        my $params =
          {
           username => $user_name,
           connection_type => connection_type_to_str($connection_type),
           SSID => $ssid,
          };
        $role = &pf::authentication::match(undef, $params, $Actions::SET_ROLE);
        $logger->debug("Username was defined ($user_name) - got role $role");
    } else {
        $role = $node_info->{'category'};
        $logger->debug("Username was NOT defined - got role $role");
    }

    return $switch->getVlanByName($role);

    # custom example: simple guest user 
    # return guestVlan for pid=guest
    #if (defined($node_info->{pid}) && $node_info->{pid} =~ /^guest$/i) {
    #    return $switch->getVlanByName('guest');
    #}

    # custom example: enforce a node's bypass VLAN 
    # If node record has a bypass_vlan prefer it over normalVlan 
    # Note: It might be made the default behavior one day
    #if (defined($node_info->{'bypass_vlan'}) && $node_info->{'bypass_vlan'} ne '') {
    #    return $node_info->{'bypass_vlan'};
    #}

    #return $switch->getVlanByName('normal');
}

=item getInlineVlan

Handling the Inline VLAN Assignment

=item * -1 means kick-out the node (not always supported)

=item * 0 means use native vlan

=item * undef means there was an error

=item * anything else is either a VLAN name string or a VLAN number

=cut
sub getInlineVlan {
    #$switch is the switch object (pf::SNMP)
    #$ifIndex is the ifIndex of the computer connected to
    #$mac is the mac connected
    #$node_info is the node info hashref (result of pf::node's node_attributes on $mac)
    #$conn_type is set to the connnection type expressed as the constant in pf::config
    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl->get_logger();

    return $switch->getVlanByName('inline');
}

=item getNodeInfoForAutoReg

Basic information returned for an auto-registered node

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default 
version doesn't do the right thing for you.

Returns an anonymous hash that is meant for node_register()

=cut 
sub getNodeInfoForAutoReg {
    #$switch_in_autoreg_mode is set to 1 if switch is in registration mode
    #$violation_autoreg is set to 1 if called from a violation with autoreg action
    #$isPhone is set to 1 if device is considered an IP Phone.
    #$conn_type is set to the connnection type expressed as the constant in pf::config
    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$ssid is set to the wireless ssid (will be empty if radius and not wireless, undef if not radius)
    my ($this, $switch_ip, $switch_port, $mac, $vlan, 
        $switch_in_autoreg_mode, $violation_autoreg, $isPhone, $conn_type, $user_name, $ssid, $eap_type) = @_;

    # we do not set a default VLAN here so that node_register will set the default normalVlan from switches.conf
    my %node_info = (
        pid             => $default_pid,
        notes           => 'AUTO-REGISTERED',
        status          => 'reg',
        auto_registered => 1, # tells node_register to autoreg
    );

    # if we are called from a violation with action=autoreg, say so
    if (defined($violation_autoreg) && $violation_autoreg) {
        $node_info{'notes'} = 'AUTO-REGISTERED by violation';
    }

    # this might look circular but if a VoIP dhcp fingerprint was seen, we'll set node.voip to VOIP
    if ($isPhone) {
        $node_info{'voip'} = $VOIP;
    }

    # under 802.1X EAP, we trust the username provided since it authenticated
    if (defined($conn_type) && (($conn_type & $EAP) == $EAP) && defined($user_name)) {
        $node_info{'pid'} = $user_name;
    }

    # set the eap_type if it exist
    if (defined($eap_type)) {
        $node_info{'eap_type'} = $eap_type;
    }

    return %node_info;
}

=item shouldAutoRegister

Do we auto-register this node?

By default we register automatically when the switch is configured to (registration mode),
when there is a violation with action autoreg and when the device is a phone.

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default 
version doesn't do the right thing for you.

returns 1 if we should register, 0 otherwise

=cut
# Note: if you add more examples here, remember to sync them in pf::vlan::custom
sub shouldAutoRegister {
    #$mac is MAC address
    #$switch_in_autoreg_mode is set to 1 if switch is in registration mode
    #$violation_autoreg is set to 1 if called from a violation with autoreg action
    #$isPhone is set to 1 if device is considered an IP Phone.
    #$conn_type is set to the connnection type expressed as the constant in pf::config
    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$ssid is set to the wireless ssid (will be empty if radius and not wireless, undef if not radius)
    my ($this, $mac, $switch_in_autoreg_mode, $violation_autoreg, $isPhone, $conn_type, $user_name, $ssid, $eap_type) = @_;
    my $logger = Log::Log4perl->get_logger();

    $logger->trace("asked if should auto-register device");
    # handling switch-config first because I think it's the most important to honor
    if (defined($switch_in_autoreg_mode) && $switch_in_autoreg_mode) {
        $logger->trace("returned yes because it's from the switch's config");
        return 1;

    # if we have a violation action set to autoreg
    } elsif (defined($violation_autoreg) && $violation_autoreg) {
        $logger->trace("returned yes because it's from a violation with action autoreg");
        return 1;
    }

    if ($isPhone) {
        $logger->trace("returned yes because it's an ip phone");
        return $isPhone;
    }

    # custom example: auto-register 802.1x users
    # Since they already have validated credentials through EAP to do 802.1X
    #if (defined($conn_type) && (($conn_type & $EAP) == $EAP)) {
    #    $logger->trace("returned yes because it's a 802.1X client that successfully authenticated already");
    #    return 1;
    #}

    # otherwise don't autoreg
    return 0;
}

=item * isInlineTrigger

Return true if a radius properties match with the inline trigger

=cut
sub isInlineTrigger {
    my ($self, $switch, $port, $mac, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($self));
    if (defined($switch->{_inlineTrigger}) && $switch->{_inlineTrigger} ne '') {
        foreach my $trigger (@{$switch->{_inlineTrigger}})  {

            # TODO we should refactor this into objects where trigger types provide their own matchers
            # at first, we are liberal in what we accept
            if ($trigger !~ /^\w+::(.*)$/) {
                $logger->warn("Invalid trigger id ($trigger)");
                return $FALSE;
            }

            my ( $type, $tid ) = split( /::/, $trigger );
            $type = lc($type);
            $tid =~ s/\s+$//; # trim trailing whitespace

            return $TRUE if ($type eq $ALWAYS);

            # make sure trigger is a valid trigger type
            # TODO refactor into an ListUtil test or an hash lookup (see Perl Best Practices)
            if ( !grep( { lc($_) eq $type } $switch->inlineCapabilities ) ) {
                $logger->warn("Invalid trigger type ($type), this is not supported by this switch");
                return $FALSE;
            }
            return $TRUE if (($type eq $MAC) && ($mac eq $tid));
            return $TRUE if (($type eq $PORT) && ($port eq $tid));
            return $TRUE if (($type eq $SSID) && ($ssid eq $tid));
        }
    }
}

=back

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
