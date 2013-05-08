package pf::SNMP::Brocade;

=head1 NAME

pf::SNMP::Brocade - Object oriented module to access SNMP enabled Brocade Switches

=head1 SYNOPSIS

The pf::SNMP::Brocade module implements an object oriented interface
to access SNMP enabled Brocade switches.

=head1 STATUS

=over 

=item Supports

=over

=item 802.1X and MAC-Authentication with and without VoIP

=back

Stacked switch support has not been tested.

=back

Tested on a Brocade ICX 6450 Version 07.4.00T311.

=head1 BUGS AND LIMITATIONS

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

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP');

sub description { 'Brocade Switches' }

# importing switch constants
use pf::SNMP::constants;
use pf::util;
use pf::config;

=head1 SUBROUTINES

=over

=cut
# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
sub supportsRadiusDynamicVlanAssignment { return $TRUE; }
sub supportsRadiusVoip { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }


=item getVersion

=cut

sub getVersion {
    my ($this) = @_;
    my $oid_snAgImgVer = '.1.3.6.1.4.1.1991.1.1.2.1.11';          #Proprietary Brocade MIB 1.3.6.1.4.1.1991 -> brcdIp
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace(
        "SNMP get_request for oid_snAgImgVer: $oid_snAgImgVer"
    );
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid_snAgImgVer] );
    my $runtimeSwVersion = ( $result->{$oid_snAgImgVer} || '' );

    # Error handling
    if ( !defined($result) ) {
        $logger->warn("Asking for software version failed with " . $this->{_sessionRead}->error());
        return;
    }

    return $runtimeSwVersion;
}

=item _dot1xPortReauthenticate

Actual implementation.
 
Allows callers to refer to this implementation even though someone along the way override the above call.

=cut

sub dot1xPortReauthenticate {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));


    my $oid_brcdDot1xAuthPortConfigPortControl = "1.3.6.1.4.1.1991.1.1.3.38.3.1.1.1"; # from brcdlp

    if (!$this->connectWrite()) {
        return 0;
    }

    $logger->trace("SNMP set_request force port in unauthorized mode on ifIndex: $ifIndex");    
    my $result = $this->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_brcdDot1xAuthPortConfigPortControl.$ifIndex", Net::SNMP::INTEGER, $BROCADE::FORCE_UNAUTHORIZED
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force 802.1x unauthorized: ".$this->{_sessionWrite}->error);
    }

    $logger->trace("SNMP set_request force port in auto mode on ifIndex: $ifIndex");
    $result = $this->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_brcdDot1xAuthPortConfigPortControl.$ifIndex", Net::SNMP::INTEGER, $BROCADE::CONTROLAUTO
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force 802.1x control auto: ".$this->{_sessionWrite}->error);
    }
    return (defined($result));
}


=item parseTrap

All traps ignored

=cut

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->debug("trap ignored, not useful for switch");
    $trapHashRef->{'trapType'} = 'unknown';

    return $trapHashRef;
}

=item getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    return (
        'Foundry-MAC-Authent-needs-802.1x' => $FALSE,
        'Tunnel-Type'               => $RADIUS::VLAN,
        'Tunnel-Medium-Type'        => $RADIUS::ETHERNET,
        'Tunnel-Private-Group-ID'   => "T:".$this->getVlanByName('voice'),
    );
}

=item isVoIPEnabled

Supports VoIP if enabled.

=cut

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

=item returnRadiusAccessAccept

Overloading L<pf::SNMP>'s implementation to send vsa in the radius reponse.

It's optional, but we can force the 802.1x authentication by sending Foundry-MAC-Authent-needs-802.1x at 1.
Disabled by default.

=cut

sub returnRadiusAccessAccept {
    my ($self, $vlan, $mac, $port, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # VLAN enforcement
    my $radius_reply_ref = {
        #'Foundry-MAC-Authent-needs-802.1x' => $TRUE,
        'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
        'Tunnel-Type' => $RADIUS::VLAN,
        'Tunnel-Private-Group-ID' => $vlan,
    };


    $logger->info("Returning ACCEPT with VLAN: $vlan");
    return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
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
