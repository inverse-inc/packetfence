package pf::Switch::Brocade;

=head1 NAME

pf::Switch::Brocade

=head1 SYNOPSIS

Base module for Brocade network equipment

=head1 STATUS

=head2 SUPPORTS

=over

=item MAC-Authentication - with and without VoIP

=item 802.1x - with and without VoIP

=item RADIUS CoA (requires at least 08.0.30d)

=back

=head2 BUGS AND LIMITATIONS

=over

=item Limitations with 802.1X to MAC-Auth fallback

There is no automatic fallback from 802.1X to MAC-Authentication supported by
the vendor at this time. However there is a means for RADIUS to explicitly
say to the switch not to require 802.1X. This has the implication that
PacketFence must be aware of all non-802.1X capable devices connecting to the
switch (if 802.1X enforcement is required) and that it tells the switch to
not require 802.1X for these devices.

The workaround implemented in the Brocade code is such that VoIP devices will
fallback to MAC-Auth if they have been pre-registered in PacketFence (see
voip attribute under node). All other device categories (Game consoles,
appliances, etc.) that don't support 802.1X will have problem in a Brocade
setup. Customer specific workarounds in L<pf::radius::custom> could be made
for that.

Vendor is aware of the problem and is working to support 802.1X to MAC-Auth
fallback.

=back

=head2 NOTES

=over

=item Stacked switch support has not been tested.

=item Tested on a Brocade ICX 6450 Version 07.4.00T311.

=back

=cut

use strict;
use warnings;

use Net::SNMP;

use base ('pf::Switch');

sub description { 'Brocade Switches' }

# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::constants;
use pf::config qw(
    $MAC
    $PORT
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);
use pf::constants::role qw($VOICE_ROLE);
use pf::locationlog;

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    RadiusDynamicVlanAssignment
    RadiusVoip
    Lldp
    FloatingDevice
    MABFloatingDevices
    ~AccessListBasedEnforcement
);
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

=item getVersion

=cut

sub getVersion {
    my ($self) = @_;
    my $oid_snAgImgVer = '.1.3.6.1.4.1.1991.1.1.2.1.11';          #Proprietary Brocade MIB 1.3.6.1.4.1.1991 -> brcdIp
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace(
        "SNMP get_request for oid_snAgImgVer: $oid_snAgImgVer"
    );
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_snAgImgVer] );
    my $runtimeSwVersion = ( $result->{$oid_snAgImgVer} || '' );

    # Error handling
    if ( !defined($result) ) {
        $logger->warn("Asking for software version failed with " . $self->{_sessionRead}->error());
        return;
    }

    return $runtimeSwVersion;
}

=item _dot1xPortReauthenticate

Actual implementation.

Allows callers to refer to this implementation even though someone along the way override the above call.

=cut

sub dot1xPortReauthenticate {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = $self->logger;


    my $oid_brcdDot1xAuthPortConfigPortControl = "1.3.6.1.4.1.1991.1.1.3.38.3.1.1.1"; # from brcdlp

    if (!$self->connectWrite()) {
        return 0;
    }

    $logger->trace("SNMP set_request force port in unauthorized mode on ifIndex: $ifIndex");
    my $result = $self->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_brcdDot1xAuthPortConfigPortControl.$ifIndex", Net::SNMP::INTEGER, $BROCADE::FORCE_UNAUTHORIZED
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force 802.1x unauthorized: ".$self->{_sessionWrite}->error);
    }

    $logger->trace("SNMP set_request force port in auto mode on ifIndex: $ifIndex");
    $result = $self->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_brcdDot1xAuthPortConfigPortControl.$ifIndex", Net::SNMP::INTEGER, $BROCADE::CONTROLAUTO
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force 802.1x control auto: ".$self->{_sessionWrite}->error);
    }
    return (defined($result));
}

=item getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($self) = @_;
    my $logger = $self->logger;
    return (
        'Foundry-MAC-Authent-needs-802.1x' => $FALSE,
        'Tunnel-Type'               => $RADIUS::VLAN,
        'Tunnel-Medium-Type'        => $RADIUS::ETHERNET,
        'Tunnel-Private-Group-ID'   => "T:".$self->getVlanByName($VOICE_ROLE),
    );
}

=item isVoIPEnabled

Supports VoIP if enabled.

=cut

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

=item wiredeauthTechniques

Returns the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'dot1xPortReauthenticate',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::SNMP => 'handleReAssignVlanTrapForWiredMacAuth',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
}

=item deauthenticateMacRadius

Deauthenticate a wired endpoint using RADIUS CoA

=cut

sub deauthenticateMacRadius {
    my ($self, $ifIndex,$mac) = @_;

    $self->radiusDisconnect($mac);
}

=item getPhonesLLDPAtIfIndex

Copied from Cisco Catalyst 2960

=cut

sub getPhonesLLDPAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    # if can't SNMP read abort
    return if ( !$self->connectRead() );

    #Transfer ifIndex to LLDP index
    my $lldpPort = $self->ifIndexToLldpLocalPort($ifIndex);
    if (!defined($lldpPort)) {
        $logger->info("Unable to lookup LLDP port from IfIndex. LLDP VoIP detection will not work. Is LLDP enabled?");
        return;
    }

    my $oid_lldpRemPortId = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemSysCapEnabled = '1.0.8802.1.1.2.1.4.1.1.12';
    my $baseoid = "$oid_lldpRemSysCapEnabled.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort";

    $logger->trace(sub {"SNMP get_next_request for lldpRemSysCapEnabled: $baseoid"});
    my $result = $self->cachedSNMPTable([-baseoid => $baseoid]);

    # Cap entries look like this:
    # iso.0.8802.1.1.2.1.4.1.1.12.0.10.29 = Hex-STRING: 24 00
    # We want to validate that the telephone capability bit is turned on.
    my @phones = ();
    foreach my $oid ( keys %{$result} ) {

        # grab the lldpRemIndex
        if ( $oid =~ /^$oid_lldpRemSysCapEnabled\.[0-9]+\.$lldpPort\.([0-9]+)$/ ) {

            my $lldpRemIndex = $1;

            # make sure that what is connected is a VoIP phone based on lldpRemSysCapEnabled information
            if ( $self->getBitAtPosition($result->{$oid}, $SNMP::LLDP::TELEPHONE) ) {
                # we have a phone on the port. Get the MAC
                $logger->trace(
                    "SNMP get_request for lldpRemPortId: "
                    . "$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"
                );
                my $portIdResult = $self->{_sessionRead}->get_request(
                    -varbindlist => [
                        "$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"
                    ]
                );
                next if (!defined($portIdResult));
                if ($portIdResult->{"$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"}
                        =~ /^(?:0x)?([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})(?::..)?$/i) {
                    push @phones, lc("$1:$2:$3:$4:$5:$6");
                }
            }
        }
    }
    return @phones;
}


=item returnAuthorizeWrite

Return radius attributes to allow write access

=cut

sub returnAuthorizeWrite {
   my ($self, $args) = @_;
   my $logger = $self->logger;
   my $radius_reply_ref = {};
   my $status;
   $radius_reply_ref->{'Foundry-Privilege-Level'} = '0';
   $radius_reply_ref->{'Reply-Message'} = "Switch enable access granted by PacketFence";
   $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with write access");
   my $filter = pf::access_filter::radius->new;
   my $rule = $filter->test('returnAuthorizeWrite', $args);
   ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
   return [$status, %$radius_reply_ref];

}

=item returnAuthorizeRead

Return radius attributes to allow read access

=cut

sub returnAuthorizeRead {
   my ($self, $args) = @_;
   my $logger = $self->logger;
   my $radius_reply_ref = {};
   my $status;
   $radius_reply_ref->{'Foundry-Privilege-Level'} = '5';
   $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
   $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
   my $filter = pf::access_filter::radius->new;
   my $rule = $filter->test('returnAuthorizeRead', $args);
   ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
   return [$status, %$radius_reply_ref];
}

sub find_ifdesc_in_locationlog {
    my ($self, $ifIndex) = @_;

   my @res =  pf::locationlog::_db_list({
        -where => {
            switch => $self->{_ip},
            port => $ifIndex,
        },
        -order_by => { -desc => 'start_time' },
        -limit => 1,
    });
    if(scalar(@res) > 0) {
        my $ifDesc = $res[0]->{ifDesc};
        $self->logger->info("Found ifDesc $ifDesc for ifIndex $ifIndex via locationlog on switch $self->{_ip}");
        return $ifDesc;
    }
    else {
        $self->logger->error("Unable to find ifDesc for ifIndex $ifIndex via locationlog on switch $self->{_ip}");
        return undef;
    }
}

=head2 _commandSSH

Execute a command on an SSH channel with a timeout

=cut

sub _commandSSH{
    my ($self, $chan, $command, $timeout) = @_;
    my $logger = $self->logger;
    $timeout //= 5;
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm $timeout;
        print $chan "$command\n";
        $logger->info("SSH output : $_") while <$chan>;
        alarm 0;
    };
}

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

sub recently_enabled_floating_key {
    my ($self, $port) = @_;
    return "recently_enabled_floating_key-$self->{_ip}-$port";
}

=head2 enableMABFloatingDevice

Enable the MAB floating device mode on a switch port

=cut

sub enableMABFloatingDevice{
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    my $ssh = $self->_connectSSH();

    return unless($ssh);

    my $port = $self->find_ifdesc_in_locationlog($ifIndex);
    return unless($port);

    if($self->cache_distributed->get($self->recently_enabled_floating_key($port))) {
        $logger->warn("Floating device mode was recently enabled on this port. Will not enable it again");
        return;
    }
    $self->cache_distributed->set($self->recently_enabled_floating_key($port), 1, '1m');

    my $chan = $ssh->channel();
    $chan->shell();
    $self->_commandSSH($chan, "enable");
    $self->_commandSSH($chan, $self->{_cliEnablePwd});
    $self->_commandSSH($chan, "configure t");
    $self->_commandSSH($chan, "interface ethernet $port");
    $self->_commandSSH($chan, "authentication max-sessions 1024");

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

    my $port = $self->find_ifdesc_in_locationlog($ifIndex);
    return unless($port);

    if($self->cache_distributed->get($self->recently_enabled_floating_key($port))) {
        $logger->warn("Floating device mode was recently enabled on this port. Will not disable since enabling this mode on the port causes all the devices to reauthenticate which calls this code (disableMABFloatingDevice)");
        return;
    }

    my $chan = $ssh->channel();
    $chan->shell();
    $self->_commandSSH($chan, "enable");
    $self->_commandSSH($chan, $self->{_cliEnablePwd});
    $self->_commandSSH($chan, "configure t");
    $self->_commandSSH($chan, "interface ethernet $port");
    $self->_commandSSH($chan, "no authentication max-sessions 1024");

    $ssh->disconnect();
    
    $logger->info("Completed de-configuration of floating device on $port");

    return 1;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
