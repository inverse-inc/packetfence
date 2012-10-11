package pf::SNMP::Cisco::WLC;
=head1 NAME

pf::SNMP::Cisco::WLC - Object oriented module to parse SNMP traps and manage
Cisco Wireless Controllers (WLC) and Wireless Service Modules (WiSM)

=head1 STATUS

Developed and tested on firmware version 4.2.130 altought the new RADIUS RFC3576 support requires firmware v5 and later.

=over

=item Supports

=over

=item Deauthentication with RADIUS Disconnect (RFC3576)

=item Deauthentication with SNMP

=back

=back

=head1 BUGS AND LIMITATIONS

=over

=item Version specific issues

=over

=item < 5.x

Issue with Windows 7: 802.1x+WPA2. It's not a PacketFence issue.

=item 6.0.182.0

We had intermittent issues with DHCP. Disabling DHCP Proxy resolved it. Not 
a PacketFence issue.

=item 7.0.116 and 7.0.220

SNMP deassociation is not working in WPA2.  It only works if using an Open 
(unencrypted) SSID.

NOTE: This is no longer relevant since we rely on RADIUS Disconnect by 
default now.

=item 7.2.103.0 (and maybe up but it is currently the latest firmware)

SNMP de-authentication no longer works. It it believed to be caused by the 
new firmware not accepting SNMP requests with 2 bytes request-id. Doing the 
same SNMP set with `snmpset` command issues a 4 bytes request-id and the 
controllers are happy with these. Not a PacketFence issue. I would think it
relates to the following open caveats CSCtw87226:
http://www.cisco.com/en/US/docs/wireless/controller/release/notes/crn7_2.html#wp934687

NOTE: This is no longer relevant since we rely on RADIUS Disconnect by 
default now.

=back

=item FlexConnect (H-REAP) limitations before firmware 7.2

Access Points in Hybrid Remote Edge Access Point (H-REAP) mode, now known as 
FlexConnect, don't support RADIUS dynamic VLAN assignments (AAA override).

Customer specific work-arounds are possible. For example: per-SSID 
registration, auto-registration, etc. The goal being that only one VLAN
is ever 'assigned' and that is the local VLAN set on the AP for the SSID.

Update: L<FlexConnect AAA Override support was introduced in firmware 7.2 series|https://supportforums.cisco.com/message/3605608#3605608>

=item FlexConnect issues with firmware 7.2.103.0

There's an issue with this firmware regarding the AAA Override functionality
required by PacketFence. The issue is fixed in 7.2.104.16 which is not 
released as the time of this writing.

The workaround mentioned by Cisco is to downgrade to 7.0.230.0 but it 
doesn't support the FlexConnect AAA Override feature...

So you can use 7.2.103.0 with PacketFence but not in FlexConnect mode.

Caveat CSCty44701

=back

=head1 SEE ALSO

=over 

=item L<Version 7.2 - Configuring AAA Overrides for FlexConnect|http://www.cisco.com/en/US/docs/wireless/controller/7.2/configuration/guide/cg_flexconnect.html#wp1247954>

=item L<Cisco's RADIUS Packet of Disconnect documentation|http://www.cisco.com/en/US/docs/ios/12_2t/12_2t8/feature/guide/ft_pod1.html>

=back

=cut
use strict;
use warnings;

use Log::Log4perl;
use Net::SNMP;
use Net::Telnet;

use base ('pf::SNMP::Cisco');

use pf::config;

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
sub supportsRoleBasedEnforcement { return $TRUE; }

# disabling special features supported by generic Cisco's but not on WLCs
sub supportsSaveConfig { return $FALSE; }
sub supportsCdp { return $FALSE; }
sub supportsLldp { return $FALSE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item deauthenticateMacDefault
    
De-authenticate a MAC address from wireless network (including 802.1x).
    
New implementation using RADIUS Disconnect-Request.

=cut
sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    
    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }
    
    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    # TODO push Login-User => 1 (RFC2865) in pf::radius::constants if someone ever reads this 
    # (not done because it doesn't exist in current branch)
    return $self->radiusDisconnect( $mac, { 'Service-Type' => 'Login-User'} );
}

=item _deauthenticateMacSNMP

deauthenticate a MAC address from wireless network (including 802.1x)

This implementation is deprecated since RADIUS Disconnect-Request (aka 
RFC3576 aka CoA) is better and also it no longer worked with firmware 7.2 and up.
See L<BUGS AND LIMITATIONS> for details.

=cut
sub _deauthenticateMacSnmp {
    my ( $this, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_bsnMobileStationDeleteAction = '1.3.6.1.4.1.14179.2.1.4.1.22';

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't write to the bnsMobileStationTable"
        );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    #format MAC
    if ( length($mac) == 17 ) {
        my @macArray = split( /:/, $mac );
        my $completeOid = $OID_bsnMobileStationDeleteAction;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        $logger->trace(
            "SNMP set_request for bsnMobileStationDeleteAction: $completeOid"
        );
        my $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [ $completeOid, Net::SNMP::INTEGER, 1 ] );
        # TODO: validate result
        $logger->info("deauthenticate mac $mac from controller: ".$this->{_ip});
        return ( defined($result) );
    } else {
        $logger->error(
            "ERROR: MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx"
        );
        return 1;
    }
}

sub blacklistMac {
    my ( $this, $mac, $description ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( length($mac) == 17 ) {

        my $session;
        eval {
            $session = Net::Telnet->new(
                Host    => $this->{_ip},
                Timeout => 5,
                Prompt  => '/[\$%#>]$/'
            );
            $session->waitfor('/User: /');
            $session->put( $this->{_cliUser} . "\n" );
            $session->waitfor('/Password:/');
            $session->put( $this->{_cliPwd} . "\n" );
            $session->waitfor( $session->prompt );
        };

        if ($@) {
            $logger->error(
                "ERROR: Can not connect to access point $this->{'_ip'} using telnet"
            );
            return 1;
        }
        $logger->info("Blacklisting mac $mac");
        $session->cmd("config exclusionlist add $mac");
        $session->cmd(
            "config exclusionlist description $mac \"$description\"");
        $session->close();
    }
    return 1;
}

sub isLearntTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub setLearntTrapsEnabled {
    my ( $this, $ifIndex, $trueFalse ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub isRemovedTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub setRemovedTrapsEnabled {
    my ( $this, $ifIndex, $trueFalse ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub getVmVlanType {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub setVmVlanType {
    my ( $this, $ifIndex, $type ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub isTrunkPort {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub getVlans {
    my ($this) = @_;
    my $vlans  = {};
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return $vlans;
}

sub isDefinedVlan {
    my ( $this, $vlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return 0;
}

sub isVoIPEnabled {
    my ($this) = @_;
    return 0;
}

=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut
sub returnRoleAttribute {
    my ($this) = @_;

    return 'Airespace-ACL-Name';
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($this, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => \&deauthenticateMacDefault,
        $SNMP::SNMP  => \&_deauthenticateMacSNMP,
    );

    if (!exists($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}


=back

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Fabrice Durand <fdurand@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2012 Inverse inc.

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
