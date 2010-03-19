package pf::radius;

=head1 NAME

pf::radius - Module that deals with everything radius related

=head1 SYNOPSIS

The pf::radius module contains the functions necessary for answering radius queries.
Radius is the network access component known as AAA used in 802.1x, MAC authentication, 
MAC authentication bypass (MAB), etc. This module acts as a proxy between our radius 
perl module's SOAP requests (rlm_perl_packetfence.pl) and PacketFence core modules.

All the behavior contained here can be overridden in lib/pf/radius/custom.pm.

=cut

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;

use pf::config;
use pf::locationlog;
use pf::node;
use pf::SNMP;
use pf::SwitchFactory;
use pf::util;

# Constants copied out of the radius rlm_perl module

use constant    RLM_MODULE_REJECT=>    0;#  /* immediately reject the request */
use constant    RLM_MODULE_FAIL=>      1;#  /* module failed, don't reply */
use constant    RLM_MODULE_OK=>        2;#  /* the module is OK, continue */
use constant    RLM_MODULE_HANDLED=>   3;#  /* the module handled the request, so stop. */
use constant    RLM_MODULE_INVALID=>   4;#  /* the module considers the request invalid. */
use constant    RLM_MODULE_USERLOCK=>  5;#  /* reject the request (user is locked out) */
use constant    RLM_MODULE_NOTFOUND=>  6;#  /* user not found */
use constant    RLM_MODULE_NOOP=>      7;#  /* module succeeded without doing anything */
use constant    RLM_MODULE_UPDATED=>   8;#  /* OK (pairs modified) */
use constant    RLM_MODULE_NUMCODES=>  9;#  /* How many return codes there are */

=head1 SUBROUTINES

=over

=cut

=item * new - get a new instance of the radius object
 
=cut
sub new {
    my $logger = Log::Log4perl::get_logger("pf::radius");
    $logger->debug("instantiating new pf::radius object");
    my ( $class, %argv ) = @_;
    my $this = bless {}, $class;
    return $this;
}

=item * authorize - handling the radius authorize call

Returns an arrayref (tuple) with element 0 being a response code for Radius and second element an hash meant 
to fill the Radius reply (RAD_REPLY). The arrayref is to workaround a quirk in SOAP::Lite and have everything in result()

See http://search.cpan.org/~byrne/SOAP-Lite/lib/SOAP/Lite.pm#IN/OUT,_OUT_PARAMETERS_AND_AUTOBINDING

=cut
# WARNING: You cannot change the return value of this sub unless you also update its clients (like the SOAP 802.1x 
# module). This is because of the way perl mangles a returned hash as a list. Clients would get confused if you add a
# scalar return without updating the clients.
# FIXME: no way of saying DENY on violation, more refactoring out of pf::vlan to come
sub authorize {
    my ($this, $nas_port_type, $switch_ip, $request_is_eap, $mac, $port, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $logger->trace("received a radius authorization request with parameters: ".
        "nas port type => $nas_port_type, switch_ip => $switch_ip, EAP => $request_is_eap, ".
        "mac => $mac, port => $port, username => $user_name, ssid => $ssid");

    my $connection_type = $this->_identify_connection_type($nas_port_type, $request_is_eap);

    # FIXME maybe it's in there that we should do all the magic that happened in rlm_perl_packetfence_sql
    # meaning: the return should be decided by doWeActOnThisCall, not always RLM_MODULE_NOOP
    my $weActOnThisCall = $this->doWeActOnThisCall($connection_type, $switch_ip, $mac, $port, $user_name, $ssid);
    if ($weActOnThisCall == 0) {
        $logger->info("We decided not to act on this radius call. Stop handling request from $switch_ip.");
        return [RLM_MODULE_NOOP, undef];
    }

    $logger->info("handling radius autz request: from switch_ip => $switch_ip, " 
        . "connection_type =>" . connection_type_to_str($connection_type) . " "
        . "mac => $mac, port => $port, username => $user_name, ssid => $ssid");

    #add node if necessary
    if ( !node_exist($mac) ) {
        $logger->info("node $mac does not yet exist in database. Adding it now");
        node_add_simple($mac);
    }

    # There is activity from that mac, call node wakeup
    node_mac_wakeup($mac);

    # FIXME: this here won't scale.. :(
    # potential avenues: 
    # - HEAP MySQL table
    # - Cache::FileCache
    # - proper mod_perl
    # - shared mem (IPC::MM)
    # - memcached
    # http://www.slideshare.net/acme/scaling-with-memcached
    my $switchFactory = new pf::SwitchFactory(-configFile => $install_dir.'/conf/switches.conf');

    $logger->debug("instantiating switch");
    my $switch = $switchFactory->instantiate($switch_ip);
          
    if (!$switch) {
        $logger->error("Can't instantiate switch $switch_ip! "
                      ."Are you sure your network equipement configuration is complete?");
        return [RLM_MODULE_FAIL, undef];
    }

    # determine if we need to perform automatic registration
    my $isPhone = $switch->isPhoneAtIfIndex($mac);

    my $vlan_obj = new pf::vlan::custom();
    # should we auto-register? let's ask the VLAN object
    if ($vlan_obj->shouldAutoRegister($mac, $switch->isRegistrationMode(), 0, $isPhone, $connection_type)) {

        # automatic registration
        my %autoreg_node_defaults = $vlan_obj->getNodeInfoForAutoReg($switch->{_ip}, $port,
            $mac, undef, $switch->isRegistrationMode(), $isPhone, $connection_type);

        $logger->debug("auto-registering node $mac");
        if (!node_register($mac, $autoreg_node_defaults{'pid'}, %autoreg_node_defaults)) {
            $logger->error("auto-registration of node $mac failed");
        }
    }

    # TODO IP Phones authentication over Radius not supported
    if ($switch->isVoIPEnabled() && $isPhone) {

        # we would probably need to change the Tunnel-Medium-Type or Tunnel-Type for proper VoIP 802.1x or VoIP MAB
        $logger->warn("Radius authentication of IP Phones is not supported yet. ");
        return [RLM_MODULE_FAIL, undef];
    }

    my $vlan = $vlan_obj->vlan_determine_for_node($mac, $switch, $port);

    # if switch is not in production, we don't interfere with it: we log and we return OK
    if (!$switch->isProductionMode()) {
        $logger->warn("Should return VLAN $vlan to mac $mac but the switch is not in production -> Returning ACCEPT");
        return [RLM_MODULE_OK, undef];
    }

    if (!$switch->isManagedVlan($vlan)) {
        $logger->warn("new VLAN $vlan is not a managed VLAN -> Returning FAIL. "
                     ."Is the target vlan in the vlans=... list?");
        return [RLM_MODULE_FAIL, undef];
    }

    #closes old locationlog entries and create a new one if required
    locationlog_synchronize($switch_ip, $port, $vlan, $mac, NO_VOIP, $connection_type);

    # we are all set now

    # cleanup
    $switch->disconnectRead();
    $switch->disconnectWrite();

    my %RAD_REPLY;
    $RAD_REPLY{'Tunnel-Medium-Type'} = 6;
    $RAD_REPLY{'Tunnel-Type'} = 13;
    $RAD_REPLY{'Tunnel-Private-Group-ID'} = $vlan;
    $logger->info("Returning ACCEPT with VLAN: $vlan");
    return [RLM_MODULE_OK, %RAD_REPLY];
}

=item * doWeActOnThisCall - is this request of any interest?

Pass all the info you can

returns 0 for no, 1 for yes

=cut
sub doWeActOnThisCall {
    my ($this, $connection_type, $switch_ip, $mac, $port, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->trace("doWeActOnThisCall called");

    # lets assume we don't act
    my $do_we_act = 0;

    # TODO we could implement some way to know if the same request is being worked on and drop right here

    # is it wired or wireless? call sub accordingly
    if (defined($connection_type)) {

        if (($connection_type & WIRELESS) == WIRELESS) {
            $do_we_act = $this->doWeActOnThisCall_wireless($connection_type, $switch_ip, $mac, 
                $port, $user_name, $ssid);

        } elsif (($connection_type & WIRED) == WIRED) {
            $do_we_act = $this->doWeActOnThisCall_wired($connection_type, $switch_ip, $mac, $port, $user_name, $ssid);
        } else {
            $do_we_act = 0;
        } 

    } else {
        # we won't act on an unknown request type
        $do_we_act = 0;
    }
    return $do_we_act;
}

=item * doWeActOnThisCall_wireless - is this wireless request of any interest?

Pass all the info you can

returns 0 for no, 1 for yes

=cut
sub doWeActOnThisCall_wireless {
    my ($this, $nas_port_type, $switch_ip, $request_is_eap, $mac, $port, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->trace("doWeActOnThisCall_wireless called");

    # for now we always act on wireless radius authorize
    return 1;
}

=item * doWeActOnThisCall_wired - is this wired request of any interest?

Pass all the info you can
        
returns 0 for no, 1 for yes
    
=cut
sub doWeActOnThisCall_wired {
    my ($this, $nas_port_type, $switch_ip, $request_is_eap, $mac, $port, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->trace("doWeActOnThisCall_wired called");

    # for now we always act on wired radius authorize
    return 1;
}


=item * _identify_connection_type - identify the connection type based information provided by radius call

Need radius' NAS-Port-Type and EAP-Type

Returns the constants WIRED or WIRELESS. Undef if unable to identify.

=cut
sub _identify_connection_type {
    my ($this, $nas_port_type, $request_is_eap) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $request_is_eap = 0 if (not defined($request_is_eap));
    if (defined($nas_port_type)) {
    
        if ($nas_port_type =~ /^Wireless-802\.11$/) {

            if ($request_is_eap) {
                return WIRELESS_802_1X;
            } else {
                return WIRELESS_MAC_AUTH;
            }
    
        } elsif ($nas_port_type =~ /^Ethernet$/) {

            if ($request_is_eap) {
                return WIRED_802_1X;
            } else {
                return WIRED_MAC_AUTH_BYPASS;
            }

        } else {
            # we didn't recognize request_type, this is a problem
            $logger->warn("Unknown connection_type. NAS-Port-Type: $nas_port_type, EAP-Type: $request_is_eap.");
            return;
        }
    } else {
        $logger->warn("Request type was not set. There is a problem with the NAS, your radius config "
            ."or rlm_perl_packetfence module.");
        return;
    }
}
=back

=head1 BUGS AND LIMITATIONS

Authentication of IP Phones (VoIP) over radius is not supported yet.

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009, 2010 Inverse inc.

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
