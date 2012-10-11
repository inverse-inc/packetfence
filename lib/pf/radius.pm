package pf::radius;

=head1 NAME

pf::radius - Module that deals with everything RADIUS related

=head1 SYNOPSIS

The pf::radius module contains the functions necessary for answering RADIUS queries.
RADIUS is the network access component known as AAA used in 802.1x, MAC authentication, etc.
This module acts as a proxy between our FreeRADIUS perl module's SOAP requests 
(packetfence.pm) and PacketFence core modules.

All the behavior contained here can be overridden in lib/pf/radius/custom.pm.

=cut

use strict;
use warnings;

use Log::Log4perl;

use pf::config;
use pf::locationlog;
use pf::node;
use pf::SNMP;
use pf::SwitchFactory;
use pf::util;
use pf::vlan::custom $VLAN_API_LEVEL;
# constants used by this module are provided by
use pf::radius::constants;

our $VERSION = 1.02;

=head1 SUBROUTINES

=over

=cut

=item * new - get a new instance of the pf::radius object
 
=cut
sub new {
    my $logger = Log::Log4perl::get_logger("pf::radius");
    $logger->debug("instantiating new pf::radius object");
    my ( $class, %argv ) = @_;
    my $this = bless {}, $class;
    return $this;
}

=item * authorize - handling the RADIUS authorize call

Returns an arrayref (tuple) with element 0 being a response code for Radius and second element an hash meant 
to fill the Radius reply (RAD_REPLY). The arrayref is to workaround a quirk in SOAP::Lite and have everything in result()

See http://search.cpan.org/~byrne/SOAP-Lite/lib/SOAP/Lite.pm#IN/OUT,_OUT_PARAMETERS_AND_AUTOBINDING

=cut
# WARNING: You cannot change the return structure of this sub unless you also update its clients (like the SOAP 802.1x 
# module). This is because of the way perl mangles a returned hash as a list. Clients would get confused if you add a
# scalar return without updating the clients.
sub authorize {
    my ($this, $radius_request) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    my ($nas_port_type, $switch_ip, $eap_type, $mac, $port, $user_name) = $this->_parseRequest($radius_request);

    $logger->trace("received a radius authorization request with parameters: ".
        "nas port type => $nas_port_type, switch_ip => $switch_ip, EAP-Type => $eap_type, ".
        "mac => $mac, port => $port, username => $user_name");

    my $connection_type = $this->_identifyConnectionType($nas_port_type, $eap_type, $mac, $user_name);

    # TODO maybe it's in there that we should do all the magic that happened in the FreeRADIUS module
    # meaning: the return should be decided by _doWeActOnThisCall, not always $RADIUS::RLM_MODULE_NOOP
    my $weActOnThisCall = $this->_doWeActOnThisCall($connection_type, $switch_ip, $mac, $port, $user_name);
    if ($weActOnThisCall == 0) {
        $logger->info("We decided not to act on this radius call. Stop handling request from $switch_ip.");
        return [ $RADIUS::RLM_MODULE_NOOP, ('Reply-Message' => "Not acting on this request") ];
    }

    $logger->info("handling radius autz request: from switch_ip => $switch_ip, " 
        . "connection_type => " . connection_type_to_str($connection_type) . " "
        . "mac => $mac, port => $port, username => $user_name");

    #add node if necessary
    if ( !node_exist($mac) ) {
        $logger->info("node $mac does not yet exist in database. Adding it now");
        node_add_simple($mac);
    }

    # There is activity from that mac, call node wakeup
    node_mac_wakeup($mac);

    $logger->debug("instantiating switch");
    my $switch = pf::SwitchFactory->getInstance()->instantiate($switch_ip);

    # is switch object correct?
    if (!$switch) {
        $logger->warn(
            "Can't instantiate switch $switch_ip. This request will be failed. "
            ."Are you sure your switches.conf is correct?"
        );
        return [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "Switch is not managed by PacketFence") ];
    }

    # verify if switch supports this connection type
    if (!$this->_isSwitchSupported($switch, $connection_type)) { 
        # if not supported, return
        return $this->_switchUnsupportedReply($switch);
    }

    # switch-specific information retrieval
    my $ssid;
    $port = $this->_translateNasPortToIfIndex($connection_type, $switch, $port);
    if (($connection_type & $WIRELESS) == $WIRELESS) {
        $ssid = $switch->extractSsid($radius_request);
        $logger->debug("SSID resolved to: $ssid") if (defined($ssid));
    }

    # determine if we need to perform automatic registration
    my $isPhone = $switch->isPhoneAtIfIndex($mac, $port);

    my $vlan_obj = new pf::vlan::custom();
    # should we auto-register? let's ask the VLAN object
    if ($vlan_obj->shouldAutoRegister($mac, $switch->isRegistrationMode(), 0, $isPhone,
        $connection_type, $user_name, $ssid)) {

        # automatic registration
        my %autoreg_node_defaults = $vlan_obj->getNodeInfoForAutoReg($switch->{_ip}, $port,
            $mac, undef, $switch->isRegistrationMode(), $FALSE, $isPhone, $connection_type, $user_name, $ssid);

        $logger->debug("auto-registering node $mac");
        if (!node_register($mac, $autoreg_node_defaults{'pid'}, %autoreg_node_defaults)) {
            $logger->error("auto-registration of node $mac failed");
        }
    }

    # if it's an IP Phone, let _authorizeVoip decide (extension point)
    if ($isPhone) {
        return $this->_authorizeVoip($connection_type, $switch, $mac, $port, $user_name, $ssid);
    }

    # if switch is not in production, we don't interfere with it: we log and we return OK
    if (!$switch->isProductionMode()) {
        $logger->warn("Should perform access control on switch $switch_ip for mac $mac but the switch "
            ."is not in production -> Returning ACCEPT");
        $switch->disconnectRead();
        $switch->disconnectWrite();
        return [ $RADIUS::RLM_MODULE_OK, ('Reply-Message' => "Switch is not in production, so we allow this request") ];
    }

    # grab vlan
    my $vlan = $vlan_obj->fetchVlanForNode($mac, $switch, $port, $connection_type, $user_name, $ssid);

    # should this node be kicked out?
    if (defined($vlan) && $vlan == -1) {
        $logger->info("According to rules in fetchVlanForNode this node must be kicked out. Returning USERLOCK");
        $switch->disconnectRead();
        $switch->disconnectWrite();
        return [ $RADIUS::RLM_MODULE_USERLOCK, ('Reply-Message' => "This node is not allowed to use this service") ];
    }

    if ($this->isInlineTrigger($switch,$port,$mac,$ssid)) {
        $logger->info("Inline trigger match, the node is in inline mode, returning Access-Accept");
        if (defined($switch->{_inlineVlan})) {
            my $RAD_REPLY_REF = $switch->returnRadiusAccessAccept($switch->{_inlineVlan}, $mac, $port, $connection_type, $user_name, $ssid);
            return $RAD_REPLY_REF;
        }
        return [ $RADIUS::RLM_MODULE_OK, ('Reply-Message' => "Returning Access-Accept because trigger match for inline mode") ];
    }

    if (!$switch->isManagedVlan($vlan)) {
        $logger->warn("new VLAN $vlan is not a managed VLAN -> Returning FAIL. "
                     ."Is the target vlan in the vlans=... list?");
        $switch->disconnectRead();
        $switch->disconnectWrite();
        return [ $RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "New VLAN is not a managed VLAN") ];
    }

    #closes old locationlog entries and create a new one if required
    locationlog_synchronize($switch_ip, $port, $vlan, $mac, 
        $isPhone ? $VOIP : $NO_VOIP, $connection_type, $user_name, $ssid
    );

    # does the switch support Dynamic VLAN Assignment
    if (!$switch->supportsRadiusDynamicVlanAssignment()) {
        $logger->info(
            "Switch doesn't support Dynamic VLAN assignment. " . 
            "Setting VLAN with SNMP on " . $switch->{_ip} . " ifIndex $port to $vlan"
        );
        # WARNING: passing empty switch-lock for now
        # When the _setVlan of a switch who can't do RADIUS VLAN assignment uses the lock we will need to re-evaluate
        $switch->_setVlan( $port, $vlan, undef, {} );
    }

    my $RAD_REPLY_REF = $switch->returnRadiusAccessAccept($vlan, $mac, $port, $connection_type, $user_name, $ssid);

    if ($this->_shouldRewriteAccessAccept($RAD_REPLY_REF, $vlan, $mac, $port, $connection_type, $user_name, $ssid)) {
        $RAD_REPLY_REF = $this->_rewriteAccessAccept(
            $RAD_REPLY_REF, $vlan, $mac, $port, $connection_type, $user_name, $ssid
        );
    }

    # cleanup
    $switch->disconnectRead();
    $switch->disconnectWrite();

    return $RAD_REPLY_REF;
}

=item * _parseRequest

Takes FreeRADIUS' RAD_REQUEST hash and process it to return 
  NAS Port type (Ethernet, Wireless, etc.)
  Network Device IP
  EAP
  MAC
  NAS-Port (port)
  User-Name

=cut
sub _parseRequest {
    my ($this, $radius_request) = @_;

    my $mac = clean_mac($radius_request->{'Calling-Station-Id'});
    # freeradius 2 provides the client IP in NAS-IP-Address not Client-IP-Address (non-standard freeradius1 attribute)
    my $networkdevice_ip = $radius_request->{'NAS-IP-Address'} || $radius_request->{'Client-IP-Address'};
    my $user_name = $radius_request->{'User-Name'};
    my $nas_port_type = $radius_request->{'NAS-Port-Type'};
    my $port = $radius_request->{'NAS-Port'};

    my $eap_type = 0;
    if (exists($radius_request->{'EAP-Type'})) {
        $eap_type = 1;
    }

    return ($nas_port_type, $networkdevice_ip, $eap_type, $mac, $port, $user_name);
}

=item * _doWeActOnThisCall

Is this request of any interest?

returns 0 for no, 1 for yes

=cut
sub _doWeActOnThisCall {
    my ($this, $connection_type, $switch_ip, $mac, $port, $user_name) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->trace("_doWeActOnThisCall called");

    # lets assume we don't act
    my $do_we_act = 0;

    # TODO we could implement some way to know if the same request is being worked on and drop right here

    # is it wired or wireless? call sub accordingly
    if (defined($connection_type)) {

        if (($connection_type & $WIRELESS) == $WIRELESS) {
            $do_we_act = $this->_doWeActOnThisCallWireless($connection_type, $switch_ip, $mac, $port, $user_name);

        } elsif (($connection_type & $WIRED) == $WIRED) {
            $do_we_act = $this->_doWeActOnThisCallWired($connection_type, $switch_ip, $mac, $port, $user_name);
        } else {
            $do_we_act = 0;
        } 

    } else {
        # we won't act on an unknown request type
        $do_we_act = 0;
    }
    return $do_we_act;
}

=item * _doWeActOnThisCallWireless

Is this wireless request of any interest?

returns 0 for no, 1 for yes

=cut
sub _doWeActOnThisCallWireless {
    my ($this, $connection_type, $switch_ip, $mac, $port, $user_name) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->trace("_doWeActOnThisCallWireless called");

    # for now we always act on wireless radius authorize
    return 1;
}

=item * _doWeActOnThisCallWired - is this wired request of any interest?

Pass all the info you can
        
returns 0 for no, 1 for yes
    
=cut
sub _doWeActOnThisCallWired {
    my ($this, $connection_type, $switch_ip, $mac, $port, $user_name) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->trace("_doWeActOnThisCallWired called");

    # for now we always act on wired radius authorize
    return 1;
}


=item * _identifyConnectionType

Identify the connection type based information provided by RADIUS call

Returns the constants $WIRED or $WIRELESS. Undef if unable to identify.

=cut
sub _identifyConnectionType {
    my ($this, $nas_port_type, $eap_type, $mac, $user_name) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $eap_type = 0 if (not defined($eap_type));
    if (defined($nas_port_type)) {
    
        if ($nas_port_type =~ /^Wireless-802\.11$/) {

            if ($eap_type) {
                return $WIRELESS_802_1X;
            } else {
                return $WIRELESS_MAC_AUTH;
            }
    
        } elsif ($nas_port_type =~ /^Ethernet$/) {

            if ($eap_type) {

                # some vendor do EAP-based Wired MAC Authentication, as far as PacketFence is concerned
                # this is still MAC Authentication so we need to cheat a little bit here
                # TODO: consider moving this logic later once the switch is initialized so we can ask it
                # (supportsEAPMacAuth?)
                $mac =~ s/://g;
                if ($mac eq $user_name) {
                    return $WIRED_MAC_AUTH;
                } else {
                    return $WIRED_802_1X;
                }

            } else {
                return $WIRED_MAC_AUTH;
            }

        } else {
            # we didn't recognize request_type, this is a problem
            $logger->warn("Unknown connection_type. NAS-Port-Type: $nas_port_type, EAP-Type: $eap_type.");
            return;
        }
    } else {
        $logger->warn("Request type was not set. There is a problem with the NAS, your radius config "
            ."or rlm_perl packetfence.pm FreeRADIUS module.");
        return;
    }
}

=item * _authorizeVoip - RADIUS authorization of VoIP

All of the parameters from the authorize method call are passed just in case someone who override this sub 
need it. However, connection_type is passed instead of nas_port_type and eap_type and the switch object 
instead of switch_ip.

Returns the same structure as authorize(), see it's POD doc for details.

=cut
sub _authorizeVoip {
    my ($this, $connection_type, $switch, $mac, $port, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    if (!$switch->supportsRadiusVoip()) {
        $logger->warn("Returning failure to RADIUS.");
        $switch->disconnectRead();
        $switch->disconnectWrite();

        return [
            $RADIUS::RLM_MODULE_FAIL, 
            ('Reply-Message' => "Server reported: VoIP authorization over RADIUS not supported for this network device")
        ];
    }

    locationlog_synchronize(
        $switch->{_ip}, $port, $switch->{_voiceVlan}, $mac, $VOIP, $connection_type, $user_name, $ssid
    );

    my %RAD_REPLY = $switch->getVoipVsa();
    $switch->disconnectRead();
    $switch->disconnectWrite();
    return [$RADIUS::RLM_MODULE_OK, %RAD_REPLY];
}

=item * _translateNasPortToIfIndex - convert the number in NAS-Port into an ifIndex only when relevant

=cut
sub _translateNasPortToIfIndex {
    my ($this, $conn_type, $switch, $port) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    if (($conn_type & $WIRED) == $WIRED) {
        $logger->trace("translating NAS-Port to ifIndex for proper accounting");
        return $switch->NasPortToIfIndex($port);
    } elsif (($conn_type & $WIRELESS) == $WIRELESS && !defined($port)) {
        $logger->debug("got empty NAS-Port parameter, setting 0 to avoid breakage");
        $port = 0;
    }
    return $port;
}

=item * _isSwitchSupported

Determines if switch is supported by current connection type.

=cut
sub _isSwitchSupported {
    my ($this, $switch, $conn_type) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    if ($conn_type == $WIRED_MAC_AUTH) {
        return $switch->supportsWiredMacAuth();
    } elsif ($conn_type == $WIRED_802_1X) {
        return $switch->supportsWiredDot1x();
    } elsif ($conn_type == $WIRELESS_MAC_AUTH) {
        # TODO implement supportsWirelessMacAuth (or supportsWireless)
        $logger->trace("Wireless doesn't have a supports...() call for now, always say it's supported");
        return $TRUE;
    } elsif ($conn_type == $WIRELESS_802_1X) {
        # TODO implement supportsWirelessMacAuth (or supportsWireless)
        $logger->trace("Wireless doesn't have a supports...() call for now, always say it's supported");
        return $TRUE;
    }
}

=item * _switchUnsupportedReply - what is sent to RADIUS when a switch is unsupported

=cut
sub _switchUnsupportedReply {
    my ($this, $switch) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $logger->warn("Sending REJECT since switch is unspported");
    $switch->disconnectRead();
    $switch->disconnectWrite();
    return [$RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "Network device does not support this mode of operation")];
}

=item * _shouldRewriteAccessAccept

If this returns true we will call _rewriteAccessAccept() and overwrite the 
Access-Accept attributes by it's return value.

This is meant to be overridden in L<pf::radius::custom>.

=cut
sub _shouldRewriteAccessAccept {
    my ($this, $RAD_REPLY_REF, $vlan, $mac, $port, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    return $FALSE;
}

=item * _rewriteAccessAccept

Allows to rewrite the Access-Accept RADIUS atributes arbitrarily.

Return type should match L<pf::radius::authorize()>'s return type. See its 
documentation for details.

This is meant to be overridden in L<pf::radius::custom>.

=cut
sub _rewriteAccessAccept {
    my ($this, $RAD_REPLY_REF, $vlan, $mac, $port, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    return $RAD_REPLY_REF;
}

=item * isInlineTrigger

Return true if a radius properties match with the inline trigger

=cut
sub isInlineTrigger {
    my ($self, $switch, $port, $mac, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($self));
    if (defined($switch->{_inlineTrigger})) {
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

=head1 BUGS AND LIMITATIONS

None reported yet ;)

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Fabrice Durand <fdurand@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009-2012 Inverse inc.

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
# vim: set tabstop=4:
# vim: set backspace=indent,eol,start:
