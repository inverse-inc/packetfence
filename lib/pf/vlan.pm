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

use pf::log;

use pf::constants;
use pf::constants::trigger qw($TRIGGER_ID_PROVISIONER $TRIGGER_TYPE_PROVISIONER);
use pf::config;
use pf::node qw(node_attributes node_exist node_modify);
use pf::Switch::constants;
use pf::util;
use pf::config::util;
use pf::violation qw(violation_count_reevaluate_access violation_exist_open violation_view_top violation_trigger violation_add);
use pf::floatingdevice::custom;
use pf::constants::scan qw($POST_SCAN_VID);
use pf::authentication;
use pf::Authentication::constants;
use pf::Portal::ProfileFactory;
use pf::access_filter::vlan;
use pf::person;
use pf::lookup::person;
use Time::HiRes;
use pf::util::statsd qw(called);
use pf::StatsD;

our $VERSION = 1.04;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=cut

=head2 new

Constructor.
Usually you don't want to call this constructor but use the pf::vlan::custom subclass instead.

=cut

sub new {
    my ( $class, %argv ) = @_;
    my $logger = $class->get_logger();
    $logger->debug("instantiating new pf::vlan object");
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
    my ( $this, $mac, $switch, $ifIndex, $connection_type, $user_name, $ssid, $radius_request, $realm, $stripped_user_name, $autoreg, $connection_sub_type ) = @_;
    my $logger = $this->logger;
    my $start = Time::HiRes::gettimeofday();

    my $node_info = node_attributes($mac);

    if ($this->isInlineTrigger($switch,$ifIndex,$mac,$ssid)) {
        $logger->info("Inline trigger match, the node is in inline mode");
        my $inline = $this->getInlineVlan($switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request, $realm, $stripped_user_name, $autoreg, $connection_sub_type);
        $logger->info("PID: \"" .$node_info->{pid}. "\", Status: " .$node_info->{status}. ". Returned VLAN: $inline");
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25);
        return ( $inline, 1 );
    }

    # radius floating device handling
    if( $switch->supportsMABFloatingDevices ){
        my $floatingDeviceManager = new pf::floatingdevice::custom();
        if (exists($ConfigFloatingDevices{$mac})){
            my $floating_config = $ConfigFloatingDevices{$mac};
            $logger->info("Floating device has plugged into $switch->{_ip} port $ifIndex. Returned VLAN : $floating_config->{pvid}");
            $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25);
            return $floating_config->{'pvid'};
        }
        my $floating_mac = $floatingDeviceManager->portHasFloatingDevice($switch->{_ip}, $ifIndex);
        if($floating_mac){
            $logger->debug("Device $mac is plugged into a floating enabled port (Device $floating_mac). Determining if trunk.");
            my $floating_config = $ConfigFloatingDevices{$floating_mac};
            if( ! $floating_config->{'trunkPort'} ){
                $logger->info("PID: $node_info->{pid} has just plugged in an access floating device enabled port. Returned VLAN $floating_config->{pvid}");
                $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25);
                return $floating_config->{'pvid'};
            }
        }
    }

    my ($violation,$registration,$role);
    # violation handling
    ($violation,$role) = $this->getViolationVlan($switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request, $realm, $stripped_user_name, $autoreg, $connection_sub_type);
    if (defined($violation) && $violation ne "0" ) {
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25);
        return ( $violation, 0, $role);
    } elsif (!defined($violation)) {
        return ( $violation, 0, $role);
    }

    # there were no violation, now onto registration handling
    ($registration,$role) = $this->getRegistrationVlan($switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request, $realm, $stripped_user_name, $autoreg, $connection_sub_type);
    if (defined($registration) && $registration ne "0") {
        if ( $connection_type && ($connection_type & $WIRELESS_MAC_AUTH) == $WIRELESS_MAC_AUTH ) {
            if (isenabled($node_info->{'autoreg'})) {
                $logger->info("Connection type is WIRELESS_MAC_AUTH and the device was coming from a secure SSID with auto registration");
                node_modify($mac, ('autoreg' => 'no'));
            }
        }
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25);
        return ( $registration, 0, $role );
    }

    # no violation, not unregistered, we are now handling a normal vlan
    my ($vlan, $user_role) = $this->getNormalVlan($switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request, $realm, $stripped_user_name, $autoreg, $connection_sub_type);
    $logger->info("PID: \"" .$node_info->{pid}. "\", Status: " .$node_info->{status}. " Returned VLAN: ".(defined $vlan ? $vlan : "(undefined)").", Role: " . (defined $user_role ? $user_role : "(undefined)") );
    $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
    return ( $vlan, 0, $user_role );
}

=head2 doWeActOnThisTrap

Don't act on uplinks, unkown interface types or some traps we are not interested in.

This sub is meant to be overridden in lib/pf/vlan/custom.pm if the default
version doesn't do the right thing for you.

=cut

sub doWeActOnThisTrap {
    my ( $this, $switch, $ifIndex, $trapType ) = @_;
    my $logger = $this->logger;

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
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request, $realm, $stripped_user_name, $autoreg, $connection_sub_type) = @_;
    my $logger = $this->logger;
    my $start = Time::HiRes::gettimeofday();

    my $open_violation_count = violation_count_reevaluate_access($mac);
    if ($open_violation_count == 0) {
        $pf::StatsD::statsd->end(called() . ".timing" , $start);
        return 0;
    }

    $logger->debug("has $open_violation_count open violations(s) with action=trap; ".
                   "it might belong into another VLAN (isolation or other).");

    # Vlan Filter
    my ($result,$role) = $this->filterVlan('ViolationVlan',$switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    if ($result) {
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
        return ($result,$role);
    }

    # By default we assume that we put the user in isolation vlan unless proven otherwise
    my $vlan = "isolation";

    # fetch top violation
    $logger->trace("What is the highest priority violation for this host?");
    my $top_violation = violation_view_top($mac);
    # fetching top violation failed
    if (!$top_violation || !defined($top_violation->{'vid'})) {

        $logger->warn("Could not find highest priority open violation. ".
                      "Setting target vlan to switches.conf's isolationVlan");
        $pf::StatsD::statsd->increment(called() . ".error" );
        $pf::StatsD::statsd->end(called() . ".timing" , $start);
        return ($switch->getVlanByName($vlan), $vlan);
    }

    # get violation id
    my $vid = $top_violation->{'vid'};

    # Scan violation that must be done in the production vlan
    if ($vid == $POST_SCAN_VID) { 
        $pf::StatsD::statsd->end(called() . ".timing" , $start);
        return $FALSE;
    }

    # find violation class based on violation id
    require pf::class;
    my $class = pf::class::class_view($vid);
    # finding violation class based on violation id failed
    if (!$class || !defined($class->{'vlan'})) {

        $logger->warn("Could not find class entry for violation $vid. ".
                      "Setting target vlan to switches.conf's isolationVlan");
        $pf::StatsD::statsd->increment(called() . ".error" );
        $pf::StatsD::statsd->end(called() . ".timing" , $start);
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
        $logger->info("highest priority violation is $vid. Target VLAN for violation: $vlan ($vlan_number)");
    }

    $pf::StatsD::statsd->end(called() . ".timing" , $start);
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
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request, $realm, $stripped_user_name, $autoreg, $connection_sub_type) = @_;
    my $logger = $this->logger;
    my $start = Time::HiRes::gettimeofday();

    # trapping on registration is enabled

    if (!isenabled($Config{'trapping'}{'registration'})) {
        $logger->debug("Registration trapping disabled: skipping node is registered test");
        return 0;
    }

    if (!defined($node_info)) {
        # Vlan Filter
        my ($result,$role) = $this->filterVlan('RegistrationVlan',$switch, $ifIndex, $mac, undef, $connection_type, $user_name, $ssid, $radius_request);
        if ($result) {
            $logger->info("doesn't have a node entry; belongs into $role VLAN");
            $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
            return ($result,$role);
        }
        $logger->info("doesn't have a node entry; belongs into registration VLAN");
        my $vlan = $switch->getVlanByName('registration');
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
        return ($vlan ,'registration');
    }

    my $n_status = $node_info->{'status'};
    if ($n_status eq $pf::node::STATUS_UNREGISTERED || $n_status eq $pf::node::STATUS_PENDING) {
        # Vlan Filter
        my ($result,$role) = $this->filterVlan('RegistrationVlan',$switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
        if ($result) {
            $logger->info("is of status $n_status; belongs into $role VLAN");
            $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
            return ($result,$role);
        }
        $logger->info("is of status $n_status; belongs into registration VLAN");
        my $vlan = $switch->getVlanByName('registration');
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
        return ($vlan ,'registration');
    }
    $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
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
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request, $realm, $stripped_user_name, $autoreg, $connection_sub_type) = @_;
    my $logger = $this->logger;
    my $start = Time::HiRes::gettimeofday();

    my $options = {};
    $options->{'last_connection_sub_type'} = $connection_sub_type if (defined( $connection_sub_type));
    $options->{'last_connection_type'} = connection_type_to_str($connection_type) if (defined( $connection_type));
    $options->{'last_switch'}          = $switch->{_id} if (defined($switch->{_id}));
    $options->{'last_port'}            = $ifIndex if (defined($ifIndex));
    $options->{'last_ssid'}            = $ssid if (defined($ssid));
    $options->{'last_dot1x_username'}  = $user_name if (defined($user_name));
    $options->{'realm'}                = $realm if (defined($realm));

    my $profile = pf::Portal::ProfileFactory->instantiate($mac,$options);

    my ($vlan, $role, $result);

    my $provisioner = $profile->findProvisioner($mac,$node_info);
    if (defined($provisioner) && $provisioner->{enforce}) {
        $logger->info("Triggering provisioner check");
        violation_trigger($mac, $TRIGGER_ID_PROVISIONER, $TRIGGER_TYPE_PROVISIONER);
    }

    my $scan = $profile->findScan($mac,$node_info);
    if (defined($scan) && isenabled($scan->{'post_registration'})) {
        $logger->info("Triggering scan check");
        violation_add( $mac, $POST_SCAN_VID );
    }

    $vlan = _check_bypass($mac, $node_info, $switch);
    if( $vlan ) {
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
        return $vlan;
    }

    $logger->debug("Trying to determine VLAN from role.");

    # Vlan Filter
    ($result,$role) = $this->filterVlan('NormalVlan',$switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    if ( $result ) {
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
        return ($result,$role);
    }

    # Try MAC_AUTH, then other EAP methods and finally anything else.
    if ( $connection_type && ($connection_type & $WIRED_MAC_AUTH) == $WIRED_MAC_AUTH ) {
        $logger->info("Connection type is WIRED_MAC_AUTH. Getting role from node_info" );
        $role = $node_info->{'category'};
    } elsif ( $connection_type && ($connection_type & $WIRELESS_MAC_AUTH) == $WIRELESS_MAC_AUTH ) {
        $logger->info("Connection type is WIRELESS_MAC_AUTH. Getting role from node_info" );
        $role = $node_info->{'category'};


        if (isenabled($node_info->{'autoreg'})) {
            $logger->info("Device is comming from a secure connection and has been auto registered, we unreg it and forward it to the portal" );
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
        if ( isdisabled($profile->dot1xRecomputeRoleFromPortal) ) {
            $logger->info("Role has already been computed and we don't want to recompute it. Getting role from node_info" );
            $role = $node_info->{'category'};
        } else {
            my @sources = ($profile->getInternalSources, $profile->getExclusiveSources );
            my $stripped_user = '';
            $stripped_user = $stripped_user_name if(defined($stripped_user_name));
            my $params = {
                username => $user_name,
                connection_type => connection_type_to_str($connection_type),
                SSID => $ssid,
                stripped_user_name => $stripped_user,
                rule_class => 'authentication',
            };
            my $source;
            $role = &pf::authentication::match([@sources], $params, $Actions::SET_ROLE, \$source);
            # create a person entry for pid if it doesn't exist
            if ( !pf::person::person_exist($user_name) ) {
                $logger->info("creating person $user_name because it doesn't exist");
                pf::person::person_add($user_name);
            } else {
                $logger->debug("person $user_name already exists");
            }
            pf::person::person_modify($user_name,
                'source'  => $source,
                'portal'  => $profile->getName,
            );
            my %info = (
                'autoreg' => 'no',
                'pid' => $user_name,
            );
            if (defined $role) {
                %info = (%info, (category => $role));
            }
            node_modify($mac,%info);
        }
    }
    # If a user based role has been found by matching authentication sources rules, we return it
    if ( defined($role) && $role ne '' ) {
        $logger->info("Username was defined \"$user_name\" - returning role '$role'");
    # Otherwise, we return the node based role matched with the node MAC address
    } else {
        $role = $node_info->{'category'};
        $logger->info("Username was NOT defined or unable to match a role - returning node based role '$role'");
    }
    $vlan = $switch->getVlanByName($role);

    $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
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
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request, $realm, $stripped_user_name, $autoreg, $connection_sub_type) = @_;
    my $logger = $this->logger;
    my $start = Time::HiRes::gettimeofday();

    my ($result,$role) = $this->filterVlan('InlineVlan',$switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    if ( $result ) {
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
        return $result;
    }

    $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
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
    my ($this, $switch, $switch_port, $mac, $vlan,
        $switch_in_autoreg_mode, $violation_autoreg, $isPhone, $conn_type, $user_name, $ssid, $eap_type, $radius_request, $realm, $stripped_user_name, $connection_sub_type) = @_;
    my $logger = $this->logger();
    my $start = Time::HiRes::gettimeofday();

    #define the current connection value to instantiate the correct portal
    my $options = {};
    $options->{'last_connection_sub_type'} = $connection_sub_type if (defined($connection_sub_type));
    $options->{'last_connection_type'} = connection_type_to_str($conn_type) if (defined($conn_type));
    $options->{'last_switch'}          = $switch->{_id} if (defined($switch->{_id}));
    $options->{'last_port'}            = $switch_port if (defined($switch_port));
    $options->{'last_vlan'}            = $vlan if (defined($vlan));
    $options->{'last_ssid'}            = $ssid if (defined($ssid));
    $options->{'last_dot1x_username'}  = $user_name if (defined($user_name));
    $options->{'realm'}                = $realm if (defined($realm));

    my $profile = pf::Portal::ProfileFactory->instantiate($mac,$options);
    my $node_info = node_attributes($mac);

    my ($result, $role) = $this->filterVlan('NodeInfoForAutoReg', $switch, $switch_port, $mac, $node_info, $conn_type, $user_name, $ssid, $radius_request);

    # we do not set a default VLAN here so that node_register will set the default normalVlan from switches.conf
    my %node_info = (
        pid             => $default_pid,
        notes           => 'AUTO-REGISTERED',
        status          => 'reg',
        auto_registered => 1, # tells node_register to autoreg
        autoreg         => 'yes',
        voip            => 'no',
    );
    if (defined($role)) {
        $node_info{'category'} = $role;
    }

    # if we are called from a violation with action=autoreg, say so
    if (defined($violation_autoreg) && $violation_autoreg) {
        $node_info{'notes'} = 'AUTO-REGISTERED by violation';
        $node_info{'autoreg'} = 'no'; # This flag has not to be used for violation autoreg
    }

    # this might look circular but if a VoIP dhcp fingerprint was seen, we'll set node.voip to VOIP
    if ($isPhone) {
        $node_info{'voip'} = $VOIP;
    }

    # under 802.1X EAP, we trust the username provided since it authenticated
    if (defined($conn_type) && (($conn_type & $EAP) == $EAP) && defined($user_name)) {
        $logger->debug("EAP connection with a username \"$user_name\". Trying to match rules from authentication sources.");
        my @sources = ($profile->getInternalSources, $profile->getExclusiveSources );
        my $stripped_user = '';
        $stripped_user = $stripped_user_name if(defined($stripped_user_name));
        my $params = {
            username => $user_name,
            connection_type => connection_type_to_str($conn_type),
            SSID => $ssid,
            stripped_user_name => $stripped_user,
        };

        my $source;
        # Don't override vlan filter role
        if (!defined($role)) {
            $role = &pf::authentication::match([@sources], $params, $Actions::SET_ROLE, \$source);
        }
        my $value = &pf::authentication::match([@sources], $params, $Actions::SET_UNREG_DATE);

        if (defined $value) {
            $node_info{'unregdate'} = $value;
            if (defined $role) {
                %node_info = (%node_info, (category => $role));
            }
            %node_info = (%node_info, (source  => $source, portal => $profile->getName));
        }
        $node_info{'pid'} = $user_name;
    }

    # set the eap_type if it exist
    if (defined($eap_type)) {
        $node_info{'eap_type'} = $eap_type;
    }

    $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
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
    my $logger = $this->logger;
    my $start = Time::HiRes::gettimeofday();

    $logger->trace("asked if should auto-register device");

    # handling switch-config first because I think it's the most important to honor
    if (defined($switch_in_autoreg_mode) && $switch_in_autoreg_mode) {
        $logger->trace("returned yes because it's from the switch's config (" . $switch->{_id} . ")");
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
        return 1;

    # if we have a violation action set to autoreg
    } elsif (defined($violation_autoreg) && $violation_autoreg) {
        $logger->trace("returned yes because it's from a violation with action autoreg");
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
        return 1;
    }

    if ($isPhone) {
        $logger->trace("returned yes because it's an ip phone");
        $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
        return $isPhone;
    }
    my $node_info = node_attributes($mac);
    my ($result,$role) = $this->filterVlan('AutoRegister',$switch, $port, $mac, $node_info, $conn_type, $user_name, $ssid, $radius_request);
    if ($result) {
        if ($switch->getVlanByName($role) eq -1) {
            return 0;
        } else {
            return $result;
        }
    }

    # otherwise don't autoreg
    $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.25 );
    return 0;
}

=head2 isInlineTrigger

Return true if a radius properties match with the inline trigger

=cut

sub isInlineTrigger {
    my ($self, $switch, $port, $mac, $ssid) = @_;
    my $logger = $self->logger;
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
                $logger->warn("Invalid trigger type ($type), this is not supported by this switch (" . $switch->{_id} . ")");
                return $FALSE;
            }
            return $TRUE if (($type eq $MAC) && ($mac eq $tid));
            return $TRUE if (($type eq $PORT) && ($port eq $tid));
            return $TRUE if (($type eq $SSID) && ($ssid eq $tid));
        }
    }
}

sub _check_bypass {
    my ( $mac, $node_info, $switch ) = @_;
    my $logger = get_logger();

    if ( @_ < 3 ) { return undef; }

    # Bypass VLAN/role is configured in node record so we return accordingly
    if ( defined( $node_info->{'bypass_vlan'} ) && ( $node_info->{'bypass_vlan'} ne '' ) ) {
        $logger->info( "A bypass VLAN is configured. Returning VLAN: " . $node_info->{'bypass_vlan'} );
        return $node_info->{'bypass_vlan'};
    }
    elsif ( defined( $node_info->{'bypass_role'} ) && ( $node_info->{'bypass_role'} ne '' ) ) {
        $logger->info( "A bypass Role is configured. Returning Role: " . $node_info->{'bypass_role'} );
        return $switch->getVlanByName( $node_info->{'bypass_role'} );
    }
    else {
        return undef;
    }
}

=head2 logger

Return the current logger for the switch

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}


=head2 filterVlan

Filter the vlan based off vlan filters

=cut

sub filterVlan {
    my ($self, $scope, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    my $start = Time::HiRes::gettimeofday();
    my $filter = pf::access_filter::vlan->new;
    my $args = {
        node_info       => $node_info,
        switch          => $switch,
        ifIndex         => $ifIndex,
        mac             => $mac,
        connection_type => $connection_type,
        username       => $user_name,
        ssid            => $ssid,
        owner           => person_view($node_info->{'pid'}),
        radius_request  => $radius_request
    };
    my @results = $filter->filter($scope, $args);
    $pf::StatsD::statsd->end(called() . ".timing" , $start, 0.1 );
    return @results;
}



=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
