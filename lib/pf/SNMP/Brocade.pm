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

=item Mac Authentication without VoIP

=back

Stacked switch support has not been tested.

=back

Tested on a Brocade ICX 6450 Version 07.4.00T311.

=head1 BUGS AND LIMITATIONS

We cannot clear a 802.1X session using SNMP (no PAE MIB)

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP');

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
sub rewriteAccessAccept { return $TRUE; }


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

    return $runtimeSwVersion;
}

=item _dot1xPortReauthenticate

Actual implementation. 
Allows callers to refer to this implementation even though someone along the way override the above call.

=cut

sub dot1xPortReauthenticate {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));


    my $oid_dot1xPaePortReauthenticate = "1.3.6.1.4.1.1991.1.1.3.38.3.1.1.1"; # from brcdlp

    if (!$this->connectWrite()) {
        return 0;
    }

	$logger->trace("SNMP set_request force port in unauthorized mode on ifIndex: $ifIndex");    
	my $result = $this->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_dot1xPaePortReauthenticate.$ifIndex", Net::SNMP::INTEGER, 1
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force 802.1x re-authentication: ".$this->{_sessionWrite}->error);
    }

    if (!$this->connectWrite()) {
        return 0;
    }

    $logger->trace("SNMP set_request force port in auto mode on ifIndex: $ifIndex");
    $result = $this->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_dot1xPaePortReauthenticate.$ifIndex", Net::SNMP::INTEGER, 2
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force 802.1x re-authentication: ".$this->{_sessionWrite}->error);
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

    $logger->debug("trap ignored, not useful for wireless controller");
    $trapHashRef->{'trapType'} = 'unknown';

    return $trapHashRef;
}

=item getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

TODO: Use Egress-VLANID instead. See: http://wiki.freeradius.org/HP#RFC+4675+%28multiple+tagged%2Funtagged+VLAN%29+Assignment

=cut

sub getVoipVsa {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    return (
        'Foundry-802_1x-enable' => "0",
        'Tunnel-Type'               => $RADIUS::VLAN,
        'Tunnel-Medium-Type'        => $RADIUS::ETHERNET,
        'Tunnel-Private-Group-ID'   => "T:".$this->getVlanByName('voiceVlan'),
    );
}

=item isVoIPEnabled

Supports VoIP if enabled.

=cut

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

=item * _shouldRewriteAccessAccept

If this returns true we will call _rewriteAccessAccept() and overwrite the
Access-Accept attributes by it's return value.

This is meant to be overridden in L<pf::radius::custom>.

=cut

sub _shouldRewriteAccessAccept {
    my ($this, $RAD_REPLY_REF, $vlan, $mac, $port, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    return $TRUE;
}

=item returnRadiusAccessAccept

Overloading L<pf::SNMP>'s implementation because to send vsa in the radius reponse.

=cut

sub returnRadiusAccessAccept {
    my ($self, $vlan, $mac, $port, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # VLAN enforcement
    my $radius_reply_ref = {
        #'Foundry-802_1x-enable' => "1",
	'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
        'Tunnel-Type' => $RADIUS::VLAN,
        'Tunnel-Private-Group-ID' => $vlan,
    };


    $logger->info("Returning ACCEPT with VLAN: $vlan");
    return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
}

=back

=head1 AUTHOR

Fabrice Durand <fdurand@inverse.ca>
Francois Gaudreault <fgaudreault@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse Inc.

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
