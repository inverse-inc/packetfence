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
use pf::SNMP;
use pf::SwitchFactory;

# Constants for request types
use constant WIRED    => 1;
use constant WIRELESS => 2;
# FIXME also have some for 802.1x, MAB?

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

Returns VLAN string, VLAN number or undef. undef means the user is not authorized or the correct VLAN could not be found

=cut
sub authorize {
    my ($this, $nas_port_type, $switch_ip, $request_is_eap, $mac, $port, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->debug("TEST");

    # FIXME: this here won't scale.. :(
    # potential avenues: 
    # - HEAP MySQL table
    # - Cache::FileCache
    # - proper mod_perl
    # - shared mem (IPC::MM)
    # - memcached
    # http://www.slideshare.net/acme/scaling-with-memcached
    my $switchFactory = new pf::SwitchFactory(-configFile => $install_dir.'/conf/switches.conf');

    $logger->trace("received a radius authorization request with parameters: ".
        "nas port type => $nas_port_type, switch_ip => $switch_ip, EAP => $request_is_eap, ".
        "mac => $mac, port => $port, username => $user_name, ssid => $ssid");

    $logger->debug("instantiating switch");
    my $switch = $switchFactory->instantiate($switch_ip);
          
    if (!$switch) {
        $logger->error("Can't instantiate switch $switch_ip!");
        return;
    }

    my $weActOnThisCall = $this->doWeActOnThisCall($nas_port_type, $switch_ip, $request_is_eap, $mac, 
        $port, $user_name, $ssid);

    if ($weActOnThisCall == 0) {
        $logger->info("We decided not to act on this radius call. Stop handling request from $switch_ip.");
        return;
    }

    # TODO i'm here: identify request

}

=item * doWeActOnThisCall - is this request of any interest?

Pass all the info you can

returns 0 for no, 1 for yes

=cut
sub doWeActOnThisCall {
    my ($this, $nas_port_type, $switch_ip, $request_is_eap, $mac, $port, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->trace("doWeActOnThisCall called");

    # lets assume we don't act
    my $do_we_act = 0;

    # TODO we could implement some way to know if the same request is being worked on and drop right here

    # is it wired or wireless? call sub accordingly
    my $request_type = $this->_identify_request_type($nas_port_type);
    if (defined($request_type)) {

        if ($request_type == WIRELESS) {
            $do_we_act = $this->doWeActOnThisCall_wireless($nas_port_type, $switch_ip, $request_is_eap, $mac, 
                $port, $user_name, $ssid);

        } elsif ($request_type == WIRED) {
            $do_we_act = $this->doWeActOnThisCall_wired($nas_port_type, $switch_ip, $request_is_eap, $mac, 
                $port, $user_name, $ssid);
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


=item * identify_request_type - identify is the request is wired or wireless

Provide radius' NAS-Port-Type

Returns the constants WIRED or WIRELESS. Undef if unable to identify.

=cut
sub _identify_request_type {
    my ($this, $nas_port_type) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    if (defined($nas_port_type)) {
    
        if ($nas_port_type =~ /^Wireless-802\.11$/) {

            return $this->WIRELESS;
    
        } elsif ($nas_port_type =~ /^Ethernet$/) {

            return $this->WIRED;

        } else {
            # we didn't recognize request_type, this is a problem
            $logger->warn("Unknown request_type: $nas_port_type.");
            return;
        }
    } else {
        $logger->warn("Request type was not set. There is a problem with the NAS, your radius config "
            ."or rlm_perl_packetfence module.");
        return;
    }
}
=back

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
