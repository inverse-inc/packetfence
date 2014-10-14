package pf::vlan;

=head1 NAME

pf::vlan - Object oriented module for VLAN isolation oriented functions

=head1 SYNOPSIS

The pf::vlan module contains the functions necessary for the VLAN isolation.
All the behavior contained here can be overridden in lib/pf/vlan/custom.pm.

=cut

# When adding a "use", remember to keep pf::vlan::custom up to date for easier customization.
use strict;
use warnings;

use Log::Log4perl;
use threads;
use threads::shared;

use pf::config;
use pf::node qw(node_attributes node_exist node_modify);
use pf::Switch::constants;
use pf::util;
use pf::violation qw(violation_count_trap violation_exist_open violation_view_top violation_trigger);

use pf::authentication;
use pf::Authentication::constants;
use pf::Portal::ProfileFactory;
use pf::vlan::filter;

our $VERSION = 1.04;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=cut

=head2 new

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

=head2 fetchVlanForNode

Answers the question: What VLAN should a given node be put into?

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default
version doesn't do the right thing for you. However it is very generic,
maybe what you are looking for needs to be done in getViolationVlan,
getRegistrationVlan or getNormalVlan.

=cut

sub fetchVlanForNode {
    my ( $this, $mac, $switch, $ifIndex, $connection_type, $user_name, $ssid, $radius_request) = @_;
    my $logger = Log::Log4perl::get_logger('pf::vlan');

    my $node_info = node_attributes($mac);

    if ($this->isInlineTrigger($switch,$ifIndex,$mac,$ssid)) {
        $logger->info("[$mac] Inline trigger match, the node is in inline mode");
        my $inline = $this->getInlineVlan($switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
        $logger->info("[$mac] PID: \"" .$node_info->{pid}. "\", Status: " .$node_info->{status}. ". Returned VLAN: $inline");
        return ( $inline, 1 );
    }

    my ($violation,$registration,$role);
    # violation handling
    ($violation,$role) = $this->getViolationVlan($switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    if (defined($violation) && $violation != 0) {
        return ( $violation, 0, $role);
    } elsif (!defined($violation)) {
        $logger->warn("[$mac] There was a problem identifying vlan for violation. Will act as if there was no violation.");
    }

    # there were no violation, now onto registration handling
    ($registration,$role) = $this->getRegistrationVlan($switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    if (defined($registration) && $registration != 0) {
        if ( $connection_type && ($connection_type & $WIRELESS_MAC_AUTH) == $WIRELESS_MAC_AUTH ) {
            if (isenabled($node_info->{'autoreg'})) {
                $logger->info("[$mac] Connection type is WIRELESS_MAC_AUTH and the device was coming from a secure SSID with auto registration");
                node_modify($mac, ('autoreg' => 'no'));
            }
        }
        return ( $registration, 0, $role );
    }

    # no violation, not unregistered, we are now handling a normal vlan
    my ($vlan, $user_role) = $this->getNormalVlan($switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    if (!defined($vlan)) {
        $logger->warn("[$mac] Resolved VLAN for node is not properly defined: Replacing with macDetectionVlan");
        $vlan = $switch->getVlanByName('macDetection');
    }
    $logger->info("[$mac] PID: \"" .$node_info->{pid}. "\", Status: " .$node_info->{status}. ". Returned VLAN: $vlan");
    return ( $vlan, 0, $user_role );
}

=head2 doWeActOnThisTrap

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
    # see ifType documentation in pf::Switch::constants
    if ( ( $ifType == $SNMP::ETHERNET_CSMACD ) || ( $ifType == $SNMP::GIGABIT_ETHERNET ) ) {
        my @upLinks = $switch->getUpLinks();
        if ( @upLinks && $upLinks[0] == -1 ) {
            $logger->warn("Can't determine Uplinks for the switch (" . $switch->{_id} . ") -> do nothing");
        } else {
            if ( grep( { $_ == $ifIndex } @upLinks ) == 0 ) {
                $weActOnThisTrap = 1;
            } else {
                $logger->info( "$trapType trap received on (" . $switch->{_id} . ") "
                    . "ifindex $ifIndex which is uplink and we don't manage uplinks"
                );
            }
        }
    } else {
        $logger->info( "$trapType trap received on (" . $switch->{_id} . ") "
            . "ifindex $ifIndex which is not ethernetCsmacd"
        );
    }
    return $weActOnThisTrap;
}

=head2 getViolationVlan

Returns the violation vlan for a node (if any)

This sub is meant to be overridden in lib/pf/vlan/custom.pm if you have specific isolation needs.

Return values:

=head2 * -1 means kick-out the node (not always supported)

=head2 * 0 means no violation for this node

=head2 * undef means there was an error

=head2 * anything else is either a VLAN name string or a VLAN number

=cut

sub getViolationVlan {
    # $switch is the switch object (pf::Switch)
    # $ifIndex is the ifIndex of the computer connected to
    # $mac is the mac connected
    # $conn_type is set to the connnection type expressed as the constant in pf::config
    # $user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    # $ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    my $logger = Log::Log4perl->get_logger();

    my $open_violation_count = violation_count_trap($mac);
    if ($open_violation_count == 0) {
        return 0;
    }

    $logger->debug("[$mac] has $open_violation_count open violations(s) with action=trap; ".
                   "it might belong into another VLAN (isolation or other).");

    # Vlan Filter
    my $filter = new pf::vlan::filter;
    my ($result,$role) = $filter->test('ViolationVlan',$switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    return ($result,$role) if $result;

    # By default we assume that we put the user in isolation vlan unless proven otherwise
    my $vlan = "isolation";

    # fetch top violation
    $logger->trace("[$mac] What is the highest priority violation for this host?");
    my $top_violation = violation_view_top($mac);
    # fetching top violation failed
    if (!$top_violation || !defined($top_violation->{'vid'})) {

        $logger->warn("[$mac] Could not find highest priority open violation. ".
                      "Setting target vlan to switches.conf's isolationVlan");
        return ($switch->getVlanByName($vlan), $vlan);
    }

    # get violation id
    my $vid = $top_violation->{'vid'};

    # find violation class based on violation id
    require pf::class;
    my $class = pf::class::class_view($vid);
    # finding violation class based on violation id failed
    if (!$class || !defined($class->{'vlan'})) {

        $logger->warn("[$mac] Could not find class entry for violation $vid. ".
                      "Setting target vlan to switches.conf's isolationVlan");
        return ($switch->getVlanByName($vlan),$vlan);
    }

    # override violation destination vlan
    $vlan = $class->{'vlan'};

    # example of a specific violation that packetfence should block instead of isolate
    # ex: block iPods / iPhones because they tend to overload controllers, radius and captive portal in isolation vlan
    # if ($vid == '1100004') { return -1; }

    # Asking the switch to give us its configured vlan number for the vlan returned for the violation
    my $vlan_number = $switch->getVlanByName($vlan);
    if (defined($vlan_number)) {
        $logger->info("[$mac] highest priority violation is $vid. Target VLAN for violation: $vlan ($vlan_number)");
    }
    return ($vlan_number,$vlan);
}


=head2 getRegistrationVlan

Returns the registration vlan for a node if registration is enabled and node is unregistered or pending.

This sub is meant to be overridden in lib/pf/vlan/custom.pm if you have specific registration needs.

Return values:

=head2 * 0 means node is already registered

=head2 * undef means there was an error

=head2 * anything else is either a VLAN name string or a VLAN number

=cut

sub getRegistrationVlan {
    #$switch is the switch object (pf::Switch)
    #$ifIndex is the ifIndex of the computer connected to
    #$mac is the mac connected
    #$node_info is the node info hashref (result of pf::node's node_attributes on $mac)
    #$conn_type is set to the connnection type expressed as the constant in pf::config
    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    my $logger = Log::Log4perl->get_logger();

    # trapping on registration is enabled

    # Vlan Filter
    my $filter = new pf::vlan::filter;
    my ($result,$role) = $filter->test('RegistrationVlan',$switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    return ($result,$role) if $result;

    if (!isenabled($Config{'trapping'}{'registration'})) {
        $logger->debug("[$mac] Registration trapping disabled: skipping node is registered test");
        return 0;
    }

    if (!defined($node_info)) {
        $logger->info("[$mac] doesn't have a node entry; belongs into registration VLAN");
        return ($switch->getVlanByName('registration'),'registration');
    }

    my $n_status = $node_info->{'status'};
    if ($n_status eq $pf::node::STATUS_UNREGISTERED || $n_status eq $pf::node::STATUS_PENDING) {
        $logger->info("[$mac] is of status $n_status; belongs into registration VLAN");
        my $vlan = $switch->getVlanByName('registration');
        return ($vlan ,'registration');
    }
    return 0;
}

=head2 getNormalVlan

Returns normal vlan

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default version doesn't do the right thing for you.
It will try to match a role based on a username (if provided) or on the node MAC address and return the according
VLAN for the given switch.

Return values:

=head2 * -1 means kick-out the node (not always supported)

=head2 * 0 means node is already registered

=head2 * undef means there was an error

=head2 * anything else is either a VLAN name string or a VLAN number

=cut

sub getNormalVlan {
    #$switch is the switch object (pf::Switch)
    #$ifIndex is the ifIndex of the computer connected to
    #$mac is the mac connected
    #$node_info is the node info hashref (result of pf::node's node_attributes on $mac)
    #$conn_type is set to the connnection type expressed as the constant in pf::config
    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    my $profile = pf::Portal::ProfileFactory->instantiate($mac);

    my $provisioner = $profile->findProvisioner($mac,$node_info);
    if (defined($provisioner) && $provisioner->{enforce}) {
        violation_trigger($mac, 'check', $TRIGGER_TYPE_PROVISIONER);
    }
    else{
        $logger->trace("Can't find provisioner for $mac");
    }

    # Bypass VLAN is configured in node record so we return accordingly
    if ( defined($node_info->{'bypass_vlan'}) && $node_info->{'bypass_vlan'} ne '' ) {
        $logger->info("[$mac] Bypass VLAN '" . $node_info->{'bypass_vlan'} . "' is configured.");
        return $node_info->{'bypass_vlan'};
    }

    $logger->debug("[$mac] Trying to determine VLAN from role.");

    # Vlan Filter
    my $filter = new pf::vlan::filter;
    my ($result,$role) = $filter->test('NormalVlan',$switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    return ($result,$role) if $result;

    # Try MAC_AUTH, then other EAP methods and finally anything else.
    if ( $connection_type && ($connection_type & $WIRED_MAC_AUTH) == $WIRED_MAC_AUTH ) {
        $logger->info("[$mac] Connection type is WIRED_MAC_AUTH. Getting role from node_info" );
        $role = $node_info->{'category'};
    } elsif ( $connection_type && ($connection_type & $WIRELESS_MAC_AUTH) == $WIRELESS_MAC_AUTH ) {
        $logger->info("[$mac] Connection type is WIRELESS_MAC_AUTH. Getting role from node_info" );
        $role = $node_info->{'category'};


        if (isenabled($node_info->{'autoreg'})) {
            $logger->info("[$mac] Device is comming from a secure connection and has been auto registered, we unreg it and forward it to the portal" );
            $role = 'registration';
            my %info = (
                'status' => 'unreg',
                'autoreg' => 'no',
            );
            node_modify($mac,%info);
        }
    }

    # If it's an EAP connection with a username, we try to match that username with authentication sources to calculate
    # the role based on the rules defined in the different authentication sources.
    # FIRST HIT MATCH
    elsif ( defined $user_name && $connection_type && ($connection_type & $EAP) == $EAP ) {
        $logger->debug("[$mac] EAP connection with a username \"$user_name\". Trying to match rules from authentication sources.");
        my $profile = pf::Portal::ProfileFactory->instantiate($mac);
        my @sources = ($profile->getInternalSources, $profile->getExclusiveSources );
        my $params = {
            username => $user_name,
            connection_type => connection_type_to_str($connection_type),
            SSID => $ssid,
        };
        $role = &pf::authentication::match([@sources], $params, $Actions::SET_ROLE);
        #Compute autoreg if we use autoreg
        if (isenabled($node_info->{'autoreg'})) {
            my $value = &pf::authentication::match([@sources], $params, $Actions::SET_ACCESS_DURATION);
            if (defined $value) {
                $logger->trace("No unregdate found - computing it from access duration");
                $value = access_duration($value);
            }
            else {
                $value = &pf::authentication::match([@sources], $params, $Actions::SET_UNREG_DATE);
            }
            if (defined $value) {
                my %info = (
                    'unregdate' => $value,
                    'category' => $role,
                    'autoreg' => 'yes',
                );
                if (defined $role) {
                    %info = (%info, (category => $role));
                }
                node_modify($mac,%info);
            }
        }
    }
    # If a user based role has been found by matching authentication sources rules, we return it
    if ( defined($role) && $role ne '' ) {
        $logger->info("[$mac] Username was defined \"$user_name\" - returning user based role '$role'");
    # Otherwise, we return the node based role matched with the node MAC address
    } else {
        $role = $node_info->{'category'};
        $logger->info("[$mac] Username was NOT defined or unable to match a role - returning node based role '$role'");
    }
    my $vlan = $switch->getVlanByName($role);
    return ($vlan, $role);
}

=head2 getInlineVlan

Handling the Inline VLAN Assignment

=head2 * -1 means kick-out the node (not always supported)

=head2 * 0 means use native vlan

=head2 * undef means there was an error

=head2 * anything else is either a VLAN name string or a VLAN number

=cut

sub getInlineVlan {
    #$switch is the switch object (pf::Switch)
    #$ifIndex is the ifIndex of the computer connected to
    #$mac is the mac connected
    #$node_info is the node info hashref (result of pf::node's node_attributes on $mac)
    #$conn_type is set to the connnection type expressed as the constant in pf::config
    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    my $logger = Log::Log4perl->get_logger();

    my $filter = new pf::vlan::filter;
    my ($result,$role) = $filter->test('InlineVlan',$switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    return $result if $result;

    return $switch->getVlanByName('inline');
}

=head2 getNodeInfoForAutoReg

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
        autoreg         => 'yes',
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

=head2 shouldAutoRegister

Do we auto-register this node?

By default we register automatically when the switch is configured to (registration mode),
when there is a violation with action autoreg and when the device is a phone.

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default
version doesn't do the right thing for you.

returns 1 if we should register, 0 otherwise

=cut

sub shouldAutoRegister {
    #$mac is MAC address
    #$switch_in_autoreg_mode is set to 1 if switch is in registration mode
    #$violation_autoreg is set to 1 if called from a violation with autoreg action
    #$isPhone is set to 1 if device is considered an IP Phone.
    #$conn_type is set to the connnection type expressed as the constant in pf::config
    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$ssid is set to the wireless ssid (will be empty if radius and not wireless, undef if not radius)
    my ($this, $mac, $switch_in_autoreg_mode, $violation_autoreg, $isPhone, $conn_type, $user_name, $ssid, $eap_type, $switch, $port, $radius_request) = @_;
    my $logger = Log::Log4perl->get_logger();

    $logger->trace("[$mac] asked if should auto-register device");

    # handling switch-config first because I think it's the most important to honor
    if (defined($switch_in_autoreg_mode) && $switch_in_autoreg_mode) {
        $logger->trace("[$mac] returned yes because it's from the switch's config (" . $switch->{_id} . ")");
        return 1;

    # if we have a violation action set to autoreg
    } elsif (defined($violation_autoreg) && $violation_autoreg) {
        $logger->trace("[$mac] returned yes because it's from a violation with action autoreg");
        return 1;
    }

    if ($isPhone) {
        $logger->trace("[$mac] returned yes because it's an ip phone");
        return $isPhone;
    }
    my $node_info = node_attributes($mac);
    my $filter = new pf::vlan::filter;
    my ($result,$role) = $filter->test('AutoRegister',$switch, $port, $mac, $node_info, $conn_type, $user_name, $ssid, $radius_request);
    return 1 if $role;

    # custom example: auto-register 802.1x users
    # Since they already have validated credentials through EAP to do 802.1X
    #if (defined($conn_type) && (($conn_type & $EAP) == $EAP)) {
    #    $logger->trace("returned yes because it's a 802.1X client that successfully authenticated already");
    #    return 1;
    #}

    # otherwise don't autoreg
    return 0;
}

=head2 isInlineTrigger

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
                $logger->warn("[$mac] Invalid trigger id ($trigger)");
                return $FALSE;
            }

            my ( $type, $tid ) = split( /::/, $trigger );
            $type = lc($type);
            $tid =~ s/\s+$//; # trim trailing whitespace

            return $TRUE if ($type eq $ALWAYS);

            # make sure trigger is a valid trigger type
            # TODO refactor into an ListUtil test or an hash lookup (see Perl Best Practices)
            if ( !grep( { lc($_) eq $type } $switch->inlineCapabilities ) ) {
                $logger->warn("[$mac] Invalid trigger type ($type), this is not supported by this switch (" . $switch->{_id} . ")");
                return $FALSE;
            }
            return $TRUE if (($type eq $MAC) && ($mac eq $tid));
            return $TRUE if (($type eq $PORT) && ($port eq $tid));
            return $TRUE if (($type eq $SSID) && ($ssid eq $tid));
        }
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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
