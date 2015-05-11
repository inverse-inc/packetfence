package pf::Connection;

use Moose;

use pf::constants;
use pf::config;
use pf::log;

has 'type'          => (is => 'rw', isa => 'Str');                  # Printable string to display the type of a connection
has 'subType'       => (is => 'rw', isa => 'Str');                  # Printable string to display the sub type of a connection
has 'transport'     => (is => 'rw', isa => 'Str');                  # Wired or wireless
has 'isEAP'         => (is => 'rw', isa => 'Bool', default => 0);   # 0: NoEAP / 1: EAP
has 'isSNMP'        => (is => 'rw', isa => 'Bool', default => 0);   # 0: NoSNMP | 1: SNMP
has 'isMacAuth'     => (is => 'rw', isa => 'Bool', default => 0);   # 0: NoMacAuth | 1: MacAuth
has 'is8021X'       => (is => 'rw', isa => 'Bool', default => 0);   # 0: No8021X | 1: 8021X
has '8021XAuth'     => (is => 'rw', isa => 'Str');                  # Authentication used for 8021X connection
has 'enforcement'   => (is => 'rw', isa => 'Str');                  # PacketFence enforcement technique

our $logger = get_logger();

=head1 METHODS

=head2 _attributesToString

We create a printable string based on the connection attributes which will be used for display purposes and
database storage purpose.

=cut

sub _attributesToString {
    my ( $this ) = @_;

    # We first set the transport type
    my $type = $this->transport;

    # SNMP is kind of unique and can only apply on a wired connection without anything else
    $type .= ( (lc($this->transport) eq "wired") && ($this->isSNMP) ) ? "-SNMP" : "";

    # Handling mac authentication for both NoEAP and EAP connections
    if ( $this->isMacAuth ) {
        $type .= "-MacAuth";
        $type .= ( $this->isEAP ) ? "-EAP" : "-NoEAP";
    }

    # Handling 802.1X
    $type .= ( $this->is8021X ) ? "-8021X" : "";

    $this->type($type);
}

=head2 _stringToAttributes

We set the according attributes based on the printable string received in parameter.

=cut

sub _stringToAttributes {
    my ( $this, $type ) = @_;

    # We set the transport type
    ( lc($type) =~ /^wireless/ ) ? $this->transport("Wireless") : $this->transport("Wired");

    # We check if SNMP
    ( (lc($type) =~ /^wired/) && (lc($type) =~ /^snmp/) ) ? $this->isSNMP($TRUE) : $this->isSNMP($FALSE);

    # We check if mac authentication
    ( lc($type) =~ /^macauth/ ) ? $this->isMacAuth($TRUE) : $this->isMacAuth($FALSE);

    # We check if EAP
    # (We do this check using NoEAP because we don't want to fetch EAP in NoEAP string... you know!)
    ( lc($type) =~ /^noeap/ ) ? $this->isEAP($FALSE) : $this->isEAP($TRUE);

    # We check if 802.1X
    ( lc($type) =~ /^8021x/ ) ? $this->is8021X($TRUE) : $this->is8021X($FALSE);
}

=head2 attributesToBackwardCompatible

Only for backward compatibility while we introduce the new connection types.

=cut

sub attributesToBackwardCompatible {
    my ( $this ) = @_;

    # Wireless MacAuth
    return $WIRELESS_MAC_AUTH if ( (lc($this->transport) eq "wireless") && ($this->isMacAuth) );

    # Wireless 802.1X
    return $WIRELESS_802_1X if ( (lc($this->transport) eq "wireless") && ($this->is8021X) );

    # Wired MacAuth
    return $WIRED_MAC_AUTH if ( (lc($this->transport) eq "wired") && ($this->isMacAuth) );

    # Wired 802.1X
    return $WIRED_802_1X if ( (lc($this->transport) eq "wired") && ($this->is8021X) );

    # Default
    return;
}

=head2 identifyType

=cut

sub identifyType {
    my ( $this, $nas_port_type, $eap_type, $mac, $user_name, $switch ) = @_;

    # We first identify the transport mode using the NAS-Port-Type attribute of the RADIUS Access-Request as per RFC2875
    # Assumption: If NAS-Port-Type is either undefined or does not contain "Wireless", we treat is as "Wired"
    ( (defined($nas_port_type)) && (lc($nas_port_type) =~ /^wireless/) ) ? $this->transport("Wireless") : $this->transport("Wired");

    # Handling EAP connection
    if(defined($eap_type) && ($eap_type ne 0)) {
        $this->isEAP($TRUE);
        $this->subType($eap_type);
    }
    else {
        $this->isEAP($FALSE);
    }

    # Handling mac authentication versus 802.1X connection
    # In most cases, when EAP is used we can assume we are dealing with 802.1X connection. Unfortunately, some vendors are doing
    # mac authentication over EAP.
    # We use the User-Name RADIUS Access-Request attribute to differentiate both of theses scenarios. Since mac authentication use
    # the mac address as username, we can assume that we are dealing with a mac authentication connection if these two attributes
    # are equals.
    if ( $this->isEAP ) {
        $mac =~ s/[^[:xdigit:]]//g;
        ( lc($mac) eq lc($user_name) ) ? $this->isMacAuth($TRUE) : $this->is8021X($TRUE);
    }
    # We can safely assume that every NoEAP connection in a RADIUS context is a mac authentication connection
    else {
        $this->isMacAuth($TRUE);
    }

    # Override connection type using custom switch module
    $switch->identifyConnectionType($this);

    # We create the printable string for type
    $this->_attributesToString;
}

__PACKAGE__->meta->make_immutable;


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
