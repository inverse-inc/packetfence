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

=head2 VSTP and RADIUS dynamic VLAN assignment

Currently, these two technologies cannot be enabled at the same time on the ports and VLANs on which PacketFence is enabled.

=cut

use strict;
use warnings;

use base ('pf::Switch::Juniper');

use pf::constants;
use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);
sub description { 'Juniper EX 2200 Series' }

# importing switch constants
use pf::Switch::constants;
use pf::accounting qw(node_accounting_current_sessionid);
use pf::node qw(node_attributes);
use pf::util::radius qw(perform_disconnect);
use Try::Tiny;
use pf::util;

sub supportsWiredMacAuth { return $TRUE; }
sub supportsRadiusVoip { return $TRUE; }
# special features
sub supportsFloatingDevice {return $TRUE}
sub supportsMABFloatingDevices { return $TRUE }
sub isVoIPEnabled {return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }

# We overide it here because it's expensive and useless for this specific module
# as it can do everything using RADIUS
sub NasPortToIfIndex {return undef}
sub getIfIndexByNasPortId{return $_[1]}


=head2 getVoipVsa

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).
For now it returns the voiceVlan untagged since Juniper supports multiple untagged VLAN in the same interface

=cut

sub getVoipVsa{
    my ($self) = @_;
    my $logger = $self->logger;
    my $voiceVlan = $self->{'_voiceVlan'};
    $logger->info("Accepting phone with untagged Access-Accept on voiceVlan $voiceVlan");

    # Return the normal response except we force the voiceVlan to be sent
    return (
        'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
        'Tunnel-Type' => $RADIUS::VLAN,
        'Tunnel-Private-Group-ID' => "$voiceVlan",
    );

}


=head2 deauthenticateMacRadius

Method to deauth a wired node with RADIUS Disconnect.

=cut

sub deauthenticateMacRadius {
    my ($self, $ifIndex,$mac) = @_;
    my $logger = $self->logger;

    $self->radiusDisconnect($mac );
}

=head2 radiusDisconnect

Send a Disconnect request to disconnect a mac

=cut

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger;

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
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
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

    return $TRUE if ( ($response->{'Code'} eq 'Disconnect-ACK') || ($response->{'Code'} eq 'CoA-ACK') );

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
   my ($self, $method, $connection_type) = @_;
   my $logger = $self->logger;

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

=head2 _commandSSH

Execute a command on an SSH channel with a timeout

HACK Alert: This is necessary (mandatory even) for the Juniper Switches as Net::SSH2 and the Juniper switches don't seem to understand themselves as the return data channel from the Juniper never closes (even after it prints its output) so all commands will last the specified timeout.

=cut

sub _commandSSH{
    my ($self, $chan, $command, $timeout) = @_;
    my $logger = $self->logger;
    $timeout //= 5;
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm $timeout;
        print $chan "$command\n";
        $logger->debug("SSH output : $_") while <$chan>;
        alarm 0;
    };
}

=head2 _connectSSH

Connect to the switch using SSH

=cut

sub _connectSSH {
    my ($self) = @_;
    
    my $ssh;
    eval {
        require Net::SSH2;
        $ssh = Net::SSH2->new();
        $ssh->connect($self->{_ip}, 22 ) or die "Cannot connect $!"  ;
        $ssh->auth_password($self->{_cliUser},$self->{_cliPwd}) or die "Cannot authenticate" ;
    };

    if($@) {
        $self->logger->error("Error connecting through SSH: $@");
    }
    return $ssh;

}

=head2 enableMABFloatingDevice

Enable the MAB floating device mode on a switch port

=cut

sub enableMABFloatingDevice{
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    my $ssh = $self->_connectSSH();

    return unless($ssh);

    my $port = $ifIndex;

    my $command_mac_limit = "set ethernet-switching-options secure-access-port interface $port mac-limit 16383";
    my $command_disconnect_flap = "delete protocols dot1x authenticator interface $port mac-radius flap-on-disconnect";

    my $chan = $ssh->channel();
    $chan->shell();
    $self->_commandSSH($chan, "configure");
    $self->_commandSSH($chan, $command_mac_limit);
    $self->_commandSSH($chan, $command_disconnect_flap);
    $self->_commandSSH($chan, 'commit comment "configured floating device on '.$port.'"', 30);

    $ssh->disconnect();

    $logger->info("Completed configuration of floating device on $port");

    return 1;
}

=head2 disableMABFloatingDevice

Disable the MAB floating device mode on a switch port

=cut

sub disableMABFloatingDevice{
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    my $ssh = $self->_connectSSH();

    return unless($ssh);

    my $port = $ifIndex;

    my $command_mac_limit = "delete ethernet-switching-options secure-access-port interface $port mac-limit";
    my $command_disconnect_flap = "set protocols dot1x authenticator interface $port mac-radius flap-on-disconnect";

    my $chan = $ssh->channel();
    $chan->shell();
    $self->_commandSSH($chan, "configure");
    $self->_commandSSH($chan, $command_mac_limit);
    $self->_commandSSH($chan, $command_disconnect_flap);
    $self->_commandSSH($chan, 'commit comment "de-configured floating device on '.$port.'"', 30);

    $ssh->disconnect();
    
    $logger->info("Completed de-configuration of floating device on $port");

    return 1;
}

# LLDP detection is INCREDIBLY SLOW
# FIRST we need to sleep for 2 seconds while the LLDP table gets populated
# SECOND SNMP is slow on Juniper so response time is 10 times higher than usual
# Uncomment the two next methods to activate it.
#sub supportsLldp { return $TRUE; }
#sub getPhonesLLDPAtIfIndex {
#    my ( $self, $ifIndex ) = @_;
#    my $logger = $self->logger;
#
#    # if can't SNMP read abort
#    return if ( !$self->connectRead() );
#
#    # LLDP info takes a few seconds to appear in the SNMP table after the switch makes the radius request
#    # Sleep for 2 seconds to make sure the info is there
#    sleep(2);
#
#    # SNMP index for LLDP info is 1 more than the usual SNMP index
#    # Ex : 520 becomes 521
#    my $lldpPort = $ifIndex+"1";
#
#    my $oid_lldpRemPortId = '1.0.8802.1.1.2.1.4.1.1.7';
#    my $oid_lldpRemSysCapEnabled = '1.0.8802.1.1.2.1.4.1.1.12';
#
#    $logger->trace(
#        "SNMP get_next_request for lldpRemSysCapEnabled: "
#        . "$oid_lldpRemSysCapEnabled"
#    );
#    my $result = $self->{_sessionRead}->get_table(
#        -baseoid => "$oid_lldpRemSysCapEnabled"
#    );
#    # Cap entries look like this:
#    # iso.0.8802.1.1.2.1.4.1.1.12.0.10.29 = Hex-STRING: 24 00
#    # We want to validate that the telephone capability bit is turned on.
#    my @phones = ();
#    foreach my $oid ( keys %{$result} ) {
#
#        # grab the lldpRemIndex
#        if ( $oid =~ /^$oid_lldpRemSysCapEnabled\.([0-9]+)\.$lldpPort\.([0-9]+)$/ ) {
#
#            my $lldpRemTimeMark = $1;
#            my $lldpRemIndex = $2;
#            # make sure that what is connected is a VoIP phone based on lldpRemSysCapEnabled information
#            if ( $self->getBitAtPosition($result->{$oid}, $SNMP::LLDP::TELEPHONE) ) {
#                $logger->debug("Found phone on lldp port : ".$lldpPort);
#                # we have a phone on the port. Get the MAC
#                $logger->trace(
#                    "SNMP get_request for lldpRemPortId: "
#                    . "$oid_lldpRemPortId.$lldpRemTimeMark.$lldpPort.$lldpRemIndex"
#                );
#                my $portIdResult = $self->{_sessionRead}->get_request(
#                    -varbindlist => [
#                        "$oid_lldpRemPortId.$lldpRemTimeMark.$lldpPort.$lldpRemIndex"
#                    ]
#                );
#                next if (!defined($portIdResult));
#
#                if ($portIdResult->{"$oid_lldpRemPortId.$lldpRemTimeMark.$lldpPort.$lldpRemIndex"}
#                        =~ /^([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})\:[0-9A-Z]+$/i) {
#                    push @phones, lc("$1:$2:$3:$4:$5:$6");
#                }
#            }
#        }
#    }
#    return @phones;
#}



=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
