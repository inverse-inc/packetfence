package pf::Switch::Juniper::EX2200;

=head1 NAME

pf::SNMP::Juniper::EX2200 - Object oriented module to manage Juniper's EX Series switches

=head1 STATUS

Supports 
 MAC Authentication (MAC RADIUS in Juniper's terms)
 802.1X

Developed and tested on Juniper ex2200 running on JUNOS 12.6
Tested on ex4200 running on JUNOS 13.2

=head1 BUGS AND LIMITATIONS

=head2 VoIP is only supported in untagged mode

VoIP devices will use the defined voiceVlan but in untagged mode.
A computer and a phone in the same port can still be on two different VLANs since Juniper supports multiple VLANs per port.

=cut

use strict;
use warnings;

use base ('pf::Switch::Juniper');
use Log::Log4perl;
use Net::Appliance::Session;

use pf::constants;
use pf::config;
sub description { 'Juniper EX 2200 Series' }

# importing switch constants
use pf::Switch::constants;
use pf::accounting qw(node_accounting_current_sessionid);
use pf::node qw(node_attributes);
use pf::util::radius qw(perform_coa perform_disconnect);
use Try::Tiny;
use pf::util;

sub supportsWiredMacAuth { return $TRUE; }
sub supportsRadiusVoip { return $TRUE; }
# special features
sub supportsFloatingDevice {return $TRUE}
sub supportsMABFloatingDevices { return $TRUE }
sub supportsLldp { return $TRUE; }
sub isVoIPEnabled {return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }

=head2 getVoipVsa

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).
For now it returns the voiceVlan untagged since Juniper supports multiple untagged VLAN in the same interface

=cut

sub getVoipVsa{
    my ($this) = @_; 
    my $logger = Log::Log4perl::get_logger( ref($this) ); 
    my $voiceVlan = $this->{'_voiceVlan'};
    $logger->info("Accepting phone with untagged Access-Accept on voiceVlan $voiceVlan");
    
    # Return the normal response except we force the voiceVlan to be sent
    return (
        'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
        'Tunnel-Type' => $RADIUS::VLAN,
        'Tunnel-Private-Group-ID' => $voiceVlan, 
    );
 
}

=head2 getIfIndexByNasPortId

Return the SNMP ifindex based on the Nas-Port-Id RADIUS attribute

=cut

sub getIfIndexByNasPortId{
    my ($this, $nas_port_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $nas_port_id =~ s/\.\d+$//g;

    my $OID_ifName = "1.3.6.1.2.1.2.2.1.2";
    if ( !$this->connectRead() ) {
        $logger->warn("Cannot connect to switch $this->{'_ip'} using SNMP");
    }
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => $OID_ifName );

    
    foreach my $key ( keys %{$result} ) {
        my $portName = $result->{$key}; 
        if ($portName eq $nas_port_id ){
            $key =~ /^$OID_ifName\.(\d+)$/;
            my $ifindex = $1;
            $logger->debug("Found ifindex $ifindex for nas port id $nas_port_id");
            return $ifindex;
        }
    }
    return $FALSE;
}

=head2 getPhonesLLDPAtIfIndex

Return list of MACs found through LLDP on a given ifIndex.

=cut

sub getPhonesLLDPAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # if can't SNMP read abort
    return if ( !$this->connectRead() );
    
    # LLDP info takes a few seconds to appear in the SNMP table after the switch makes the radius request
    # Sleep for 2 seconds to make sure the info is there
    sleep(2);

    # SNMP index for LLDP info is 1 more than the usual SNMP index
    # Ex : 520 becomes 521
    my $lldpPort = $ifIndex+"1";

    my $oid_lldpRemPortId = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemSysCapEnabled = '1.0.8802.1.1.2.1.4.1.1.12';
    
    $logger->trace(
        "SNMP get_next_request for lldpRemSysCapEnabled: "
        . "$oid_lldpRemSysCapEnabled"
    );
    my $result = $this->{_sessionRead}->get_table(
        -baseoid => "$oid_lldpRemSysCapEnabled"
    );
    # Cap entries look like this:
    # iso.0.8802.1.1.2.1.4.1.1.12.0.10.29 = Hex-STRING: 24 00
    # We want to validate that the telephone capability bit is turned on.
    my @phones = (); 
    foreach my $oid ( keys %{$result} ) {

        # grab the lldpRemIndex
        if ( $oid =~ /^$oid_lldpRemSysCapEnabled\.([0-9]+)\.$lldpPort\.([0-9]+)$/ ) {

            my $lldpRemTimeMark = $1;
            my $lldpRemIndex = $2;
            # make sure that what is connected is a VoIP phone based on lldpRemSysCapEnabled information
            if ( $this->getBitAtPosition($result->{$oid}, $SNMP::LLDP::TELEPHONE) ) {
                $logger->debug("Found phone on lldp port : ".$lldpPort);
                # we have a phone on the port. Get the MAC
                $logger->trace(
                    "SNMP get_request for lldpRemPortId: "
                    . "$oid_lldpRemPortId.$lldpRemTimeMark.$lldpPort.$lldpRemIndex"
                );
                my $portIdResult = $this->{_sessionRead}->get_request(
                    -varbindlist => [
                        "$oid_lldpRemPortId.$lldpRemTimeMark.$lldpPort.$lldpRemIndex"
                    ]
                );
                next if (!defined($portIdResult));

                if ($portIdResult->{"$oid_lldpRemPortId.$lldpRemTimeMark.$lldpPort.$lldpRemIndex"}
                        =~ /^([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})\:[0-9A-Z]+$/i) {
                    push @phones, lc("$1:$2:$3:$4:$5:$6");
                }
            }
        }
    }
    return @phones;
}


=head2 deauthenticateMacRadius

Method to deauth a wired node with RADIUS Disconnect.

=cut

sub deauthenticateMacRadius {
    my ($this, $ifIndex,$mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $this->radiusDisconnect($mac );
}

=head2 radiusDisconnect

Send a Disconnect request to disconnect a mac

=cut

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS Disconnect-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $management_network->tag('vip'),
        };
       
        my $acctsessionid = node_accounting_current_sessionid($mac);
        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'Acct-Session-Id' => $acctsessionid,
            'NAS-IP-Address' => $send_disconnect_to,

        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = perform_disconnect($connection_info, $attributes_ref, []);

    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS Disconnect-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'Disconnect-ACK');

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques { 
   my ($this, $method, $connection_type) = @_;
   my $logger = Log::Log4perl::get_logger( ref($this) );

    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    elsif ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::TELNET => 'handleReAssignVlanTrapForWiredMacAuth',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        ); 
        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    else{
        $logger->error("This authentication mode is not supported");
    }

}

=head2 enableMABFloatingDevice

Connects to the switch and configures the specified port to be RADIUS floating device ready

=cut

sub enableMABFloatingDevice{
    my ($this, $ifIndex) = @_; 
    my $logger = Log::Log4perl::get_logger( ref($this) );
    
    my $session;
    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 20,
            Transport => $this->{_cliTransport},        
            Platform  => "JUNOS",    
        );
        
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );  
    };  
    
    if ($@) {
        $logger->error("Unable to connect to ".$this->{'_ip'}." using ".$this->{_cliTransport}.". Failed with $@");
        return;
    }   

    my $port = $this->getIfName($ifIndex);

    my $command_mac_limit = "set ethernet-switching-options secure-access-port interface $port mac-limit 16383";
    my $command_disconnect_flap = "delete protocols dot1x authenticator interface $port mac-radius flap-on-disconnect";

    my @output;
    eval {
        # fake priviledged mode
        $session->in_privileged_mode(1);
        $session->begin_configure();

    
        @output = $session->cmd(String => $command_mac_limit, Timeout => '5');
        @output = $session->cmd(String => $command_disconnect_flap, Timeout => '5');
        @output = $session->cmd(String => 'commit comment "configured floating device"', Timeout => '30');

        $session->in_privileged_mode(0);
    };

    if ($@) {
        $logger->error("Unable to set mac limit for port $port: $@");
        $session->close();
        return;
    }
    $session->close();
    return 1;

}

=head2 disableMABFloatingDevice

Connects to the switch and removes the RADIUS floating device configuration

=cut

sub disableMABFloatingDevice{
    my ($this, $ifIndex) = @_; 
    my $logger = Log::Log4perl::get_logger( ref($this) );
    
    my $session;
    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 20,
            Transport => $this->{_cliTransport},        
            Platform  => "JUNOS",    
        );
        
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );  
    };  
    
    if ($@) {
        $logger->error("Unable to connect to ".$this->{'_ip'}." using ".$this->{_cliTransport}.". Failed with $@");
        return;
    }   

    my $port = $this->getIfName($ifIndex);

    my $command_mac_limit = "delete ethernet-switching-options secure-access-port interface $port mac-limit";
    my $command_disconnect_flap = "set protocols dot1x authenticator interface $port mac-radius flap-on-disconnect";
    my @output;
    eval {
        # fake priviledged mode
        $session->in_privileged_mode(1);
        $session->begin_configure();

    
        @output = $session->cmd(String => $command_mac_limit, Timeout => '5');
        @output = $session->cmd(String => $command_disconnect_flap, Timeout => '5');
        @output = $session->cmd(String => 'commit comment "deconfigured floating device"', Timeout => '30');

        $session->in_privileged_mode(0);
    };

    if ($@) {
        $logger->error("Unable to set mac limit for port $port: $@");
        $session->close();
        return;
    }
    $session->close();

    return 1;
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
