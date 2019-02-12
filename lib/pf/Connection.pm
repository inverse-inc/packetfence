package pf::Connection;

use Moose;

use pf::constants;
use pf::radius::constants;
use pf::config qw(
    $WIRELESS_MAC_AUTH
    $WIRELESS_802_1X
    $WIRED_MAC_AUTH
    $WIRED_802_1X
    $VIRTUAL_CLI
    $VIRTUAL_VPN
);
use pf::log;

has 'type'          => (is => 'rw', isa => 'Str');                  # Printable string to display the type of a connection
has 'subType'       => (is => 'rw', isa => 'Str');                  # Printable string to display the sub type of a connection
has 'transport'     => (is => 'rw', isa => 'Str');                  # Wired or Wireless or Virtual
has 'isEAP'         => (is => 'rw', isa => 'Bool', default => 0);   # 0: NoEAP / 1: EAP
has 'isSNMP'        => (is => 'rw', isa => 'Bool', default => 0);   # 0: NoSNMP | 1: SNMP
has 'isMacAuth'     => (is => 'rw', isa => 'Bool', default => 0);   # 0: NoMacAuth | 1: MacAuth
has 'is8021X'       => (is => 'rw', isa => 'Bool', default => 0);   # 0: No8021X | 1: 8021X
has 'isVPN'         => (is => 'rw', isa => 'Bool', default => 0);   # 0: NoVPN | 1: VPN
has 'isCLI'         => (is => 'rw', isa => 'Bool', default => 0);   # 0: NoCLI | 1: CLI
has '8021XAuth'     => (is => 'rw', isa => 'Str');                  # Authentication used for 8021X connection
has 'enforcement'   => (is => 'rw', isa => 'Str');                  # PacketFence enforcement technique


our $logger = get_logger();

=head1 METHODS

=head2 _attributesToString

We create a printable string based on the connection attributes which will be used for display purposes and
database storage purpose.

=cut

sub _attributesToString {
    my ( $self ) = @_;

    # We first set the transport type
    my $type = $self->transport;

    # SNMP is kind of unique and can only apply on a wired connection without anything else
    $type .= ( (lc($self->transport) eq "wired") && ($self->isSNMP) ) ? "-SNMP" : "";

    # Handling mac authentication for both NoEAP and EAP connections
    if ( $self->isMacAuth ) {
        $type .= "-MacAuth";
        $type .= ( $self->isEAP ) ? "-EAP" : "-NoEAP";
    }

    # Handling 802.1X
    $type .= ( $self->is8021X ) ? "-8021X" : "";

    # Handling VPN
    $type .= ( $self->isVPN ) ? "-VPN" : "";

    # Handling CLI
    $type .= ( $self->isCLI ) ? "-CLI" : "";

    $self->type($type);
}

=head2 _stringToAttributes

We set the according attributes based on the printable string received in parameter.

=cut

sub _stringToAttributes {
    my ( $self, $type ) = @_;

    # We set the transport type
    ( lc($type) =~ /^wireless/ ) ? $self->transport("Wireless") : $self->transport("Wired");

    if (lc($type) =~/^virtual/ ) {
            $self->transport("Virtual");
    }

    # We check if SNMP
    ( (lc($type) =~ /^wired/) && (lc($type) =~ /^snmp/) ) ? $self->isSNMP($TRUE) : $self->isSNMP($FALSE);

    # We check if mac authentication
    ( lc($type) =~ /^macauth/ ) ? $self->isMacAuth($TRUE) : $self->isMacAuth($FALSE);

    # We check if EAP
    # (We do this check using NoEAP because we don't want to fetch EAP in NoEAP string... you know!)
    ( lc($type) =~ /^noeap/ ) ? $self->isEAP($FALSE) : $self->isEAP($TRUE);

    # We check if 802.1X
    ( lc($type) =~ /^8021x/ ) ? $self->is8021X($TRUE) : $self->is8021X($FALSE);

    # We check if VPN
    ( lc($type) =~ /^vpn/ ) ? $self->isVPN($TRUE) : $self->isVPN($FALSE);

    # We check if CLI
    ( lc($type) =~ /^cli/ ) ? $self->isCLI($TRUE) : $self->isCLI($FALSE);
}

=head2 backwardCompatibleToAttributes

Go from a backward compatible string (L<%pf::config::connection_type>) to attributes for this class

=cut

sub backwardCompatibleToAttributes {
    my ($self, $type) = @_;

    return if( lc($type) =~ /inline/ || !$type );

    # We set the transport type
    ( lc($type) =~ /^wireless-802\.11/ ) ? $self->transport("Wireless") : $self->transport("Wired");

    if (lc($type) =~/^virtual/ ) {
            $self->transport("Virtual");
    }

    # We check if SNMP. If so, we return immediately while setting the flag
    if ( (lc($type) =~ /^snmp/) ) { 
        $self->isSNMP($TRUE);
        return
    }
    else {
        $self->isSNMP($FALSE);
    }

    # We check if mac authentication
    ( lc($type) eq "wired_mac_auth" || lc($type) eq "Ethernet-NoEAP" ) ? $self->isMacAuth($TRUE) : $self->isMacAuth($FALSE);

    # We check if EAP
    if ( lc($type) =~ /eap$/ && lc($type) !~ /noeap$/ ) {
        $self->isEAP($TRUE);
        $self->is8021X($TRUE); 
        $self->isMacAuth($FALSE);
    }
    else {
        $self->isEAP($FALSE) ; $self->is8021X($FALSE) ; $self->isMacAuth($TRUE);
    }
    if ( lc($type) =~ /vpn$/ ) {
        $self->isMacAuth($FALSE);
        $self->isVPN($TRUE);
    }
    if ( lc($type) =~ /cli$/ ) {
        $self->isMacAuth($FALSE);
        $self->isCLI($TRUE);
    }
}

=head2 attributesToBackwardCompatible

Only for backward compatibility while we introduce the new connection types.

=cut

sub attributesToBackwardCompatible {
    my ( $self ) = @_;

    # Wireless MacAuth
    return $WIRELESS_MAC_AUTH if ( (lc($self->transport) eq "wireless") && ($self->isMacAuth) );

    # Wireless 802.1X
    return $WIRELESS_802_1X if ( (lc($self->transport) eq "wireless") && ($self->is8021X) );

    # Wired MacAuth
    return $WIRED_MAC_AUTH if ( (lc($self->transport) eq "wired") && ($self->isMacAuth) );

    # Wired 802.1X
    return $WIRED_802_1X if ( (lc($self->transport) eq "wired") && ($self->is8021X) );

    # Virtual VPN
    return $VIRTUAL_VPN if ( (lc($self->transport) eq "virtual") && ($self->isVPN) );

    # Virtual CLI
    return $VIRTUAL_CLI if ( (lc($self->transport) eq "virtual") && ($self->isCLI) );

    # Default
    return;
}

=head2 identifyType

=cut

sub identifyType {
    my ( $self, $nas_port_type, $eap_type, $mac, $user_name, $switch, $radius_request ) = @_;

    # We first identify the transport mode using the NAS-Port-Type attribute of the RADIUS Access-Request as per RFC2875
    # Assumption: If NAS-Port-Type is either undefined or does not contain "Wireless", we treat is as "Wired"
    if (defined $nas_port_type) {
        if ($nas_port_type =~ /^\d+/ && exists $RADIUS::NAS_port_type{$nas_port_type}) {
            # if it's an integer, look up the type in the radius constants.
            $nas_port_type = $RADIUS::NAS_port_type{$nas_port_type};
        }
        $self->transport($nas_port_type =~ /^wireless/i ? "Wireless" : "Wired");
        if ($nas_port_type =~ /^virtual/i) {
		$self->transport("Virtual");
        }
    }
    else {
        $self->transport("Wired");
    }

    # Handling EAP connection
    if(defined($eap_type) && ($eap_type ne 0)) {
        $self->isEAP($TRUE);
        $self->subType($eap_type);
    }
    else {
        $self->isEAP($FALSE);
    }

    # Handling mac authentication versus 802.1X connection
    # In most cases, when EAP is used we can assume we are dealing with 802.1X connection. Unfortunately, some vendors are doing
    # mac authentication over EAP.
    # We use the User-Name RADIUS Access-Request attribute to differentiate both of theses scenarios. Since mac authentication use
    # the mac address as username, we can assume that we are dealing with a mac authentication connection if these two attributes
    # are equals.
    if ( $self->isEAP ) {
        $mac =~ s/[^[:xdigit:]]//g;
        ( lc($mac) eq lc($user_name) ) ? $self->isMacAuth($TRUE) : $self->is8021X($TRUE);
    }
    # We can safely assume that every NoEAP connection in a RADIUS context is a mac authentication connection
    else {
        if (lc($self->transport) ne "virtual") {
            $self->isMacAuth($TRUE);
        }
    }

    # Override connection type using custom switch module
    $switch->identifyConnectionType($self, $radius_request);

    # We create the printable string for type
    $self->_attributesToString;
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};


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
