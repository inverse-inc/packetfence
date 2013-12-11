package pf::SNMP::ArubaSwitch;

=head1 NAME

pf::SNMP::ArubaSwitch - Object oriented module to access SNMP enabled Aruba Switches

=head1 SYNOPSIS

The pf::SNMP::ArubaSwitch module implements an object oriented interface
to access SNMP enabled Aruba switches.

=head1 STATUS

=over 

=item Supports

=over

=item 802.1X and MAC-Authentication with and without VoIP

=back

Stacked switch support has not been tested.

=back


=head1 BUGS AND LIMITATIONS

=over

=back

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;
use Try::Tiny;
use base ('pf::SNMP');

sub description { 'Aruba Switches' }

# importing switch constants
use pf::SNMP::constants;
use pf::util;
use pf::config;

=head1 SUBROUTINES

=over

=cut
# CAPABILITIES
# access technology supported
sub supportsRoleBasedEnforcement { return $TRUE; }
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
sub supportsRadiusDynamicVlanAssignment { return $TRUE; }
# sub supportsRadiusVoip { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }


=item getVersion

=cut

sub getVersion {
    my ($this)       = @_;
    my $oid_sysDescr = '1.3.6.1.2.1.1.1.0';
    my $logger       = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_sysDescr");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid_sysDescr] );
    my $sysDescr = ( $result->{$oid_sysDescr} || '' );
    if ( $sysDescr =~ m/V(\d{1}\.\d{2}\.\d{2})/ ) {
        return $1;
    } elsif ( $sysDescr =~ m/Version (\d+\.\d+\([^)]+\)[^,\s]*)(,|\s)+/ ) {
        return $1;
    } else {
        return $sysDescr;
    }
}

=item _dot1xPortReauthenticate

Actual implementation.
 
Allows callers to refer to this implementation even though someone along the way override the above call.

=cut

sub dot1xPortReauthenticate {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    return;
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

=head2 getIfIndexByNasPortId

Fetch the ifindex on the switch by NAS-Port-Id radius attribute

=cut


sub getIfIndexByNasPortId {
    my ($this, $ifDesc_param) = @_;

    if ( !$this->connectRead() ) {
        return 0;
    }

    my @ifDescTemp = split(':',$ifDesc_param);
    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_ifDesc );
    foreach my $key ( keys %{$result} ) {
        my $ifDesc = $result->{$key};
        if ( $ifDesc =~ /$ifDescTemp[1]$/i ) {
            $key =~ /^$OID_ifDesc\.(\d+)$/;
            return $1;
        }
    }
}

=item deauthenticateMacRadius

Method to deauth a wired node with CoA.

=cut
sub deauthenticateMacRadius {
    my ($this, $ifIndex,$mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));


    # perform CoA
    $this->radiusDisconnect($mac);
}

=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($this) = @_;

    return 'Aruba-User-Role';
}

=item wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($this, $method, $connection_type) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => \&dot1xPortReauthenticate,
            $SNMP::RADIUS => \&deauthenticateMacRadius,
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => \&handleReAssignVlanTrapForWiredMacAuth,
            $SNMP::RADIUS => \&deauthenticateMacRadius,
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Default implementation.

=cut

sub returnRadiusAccessAccept {
    my ($self, $vlan, $mac, $port, $connection_type, $user_name, $ssid, $wasInline, $user_role) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # Inline Vs. VLAN enforcement
    my $radius_reply_ref = {};

    if (!$wasInline || ($wasInline && $vlan != 0)) {
        $radius_reply_ref = {
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => $vlan,
        };
    }

    # TODO this is experimental
    try {
        if ($self->supportsRoleBasedEnforcement()) {
            $logger->debug("network device supports roles. Evaluating role to be returned");
            my $role = "";
            if ( defined($user_role) && $user_role ne "" ) {
                $role = $self->getRoleByName($user_role);
            }
            if ( defined($role) && $role ne "" ) { 
                $radius_reply_ref = {};
                $radius_reply_ref->{$self->returnRoleAttribute()} = $role;
                $logger->info(
                    "Added role $role to the returned RADIUS Access-Accept under attribute " . $self->returnRoleAttribute()
                );
            }
            else {
                $logger->debug("received undefined role. No Role added to RADIUS Access-Accept");
            }
        }
    }
    catch {
        chomp($_);
        $logger->debug(
            "Exception when trying to resolve a Role for the node. No Role added to RADIUS Access-Accept. "
            . "Exception: $_"
        );
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

