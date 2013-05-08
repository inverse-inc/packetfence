package pf::SNMP::Avaya::WC;

=head1 NAME

pf::SNMP::Avaya::WC

=head1 SYNOPSIS

The pf::SNMP::Avaya:WC module implements an object oriented interface to 
manage Avaya Wireless Controllers

=head1 BUGS AND LIMITATIONS

=over

=item Caching problems on secure connections

Performing a de-authentication does not clear the key cache. 
Meaning that on reconnection the device's authorization is served straight from the cache 
instead of creating a new RADIUS query.
This defeats the reason why we perform de-authentication (to change VLAN or deny access).

A client-side workaround exists: disable the PMK Caching on the client.
However this could (and should in our opinion) be fixed by the vendor.

=item SNMPv3 support is untested.

=back

=over

=cut

use strict;
use warnings;

use base ('pf::SNMP');
use Log::Log4perl;

use pf::config;
use pf::util;

sub description { 'Avaya Wireless Controller' }

=back

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item getVersion

obtain image version information from switch

=cut
sub getVersion {
    my ($this)        = @_;
    my $oid_s5ChasVer = '1.3.6.1.4.1.45.1.6.3.1.5.0';
    my $logger        = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return '';
    }

    $logger->trace("SNMP get_request for s5ChasVer: $oid_s5ChasVer");

    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid_s5ChasVer] );
    if ( exists( $result->{$oid_s5ChasVer} ) && ( $result->{$oid_s5ChasVer} ne 'noSuchInstance' ) ) {
        return $result->{$oid_s5ChasVer};
    }
    return '';
}
=item parseTrap

All traps ignored

=cut
sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # example disassociate trap on MAC 00 1B B1 8B 82 13
    # BEGIN TYPE 0 END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.2.1.1.3.0 = Timeticks: (865381) 2:24:13.81|.1.3.6.1.6.3.1.1.4.1.0 = OID: .1.3.6.1.4.1.388.14.5.1.7.1.6|.1.3.6.1.4.1.388.14.5.1.7.1.1 = Hex-STRING: 00 1B B1 8B 82 13 |.1.3.6.1.4.1.388.14.3.3.1.2.2.1.1 = Counter32: 1|.1.3.6.1.4.1.388.14.4.1.4.1.1.1 = INTEGER: 31|.1.3.6.1.4.1.388.14.4.1.4.1.1.2 = INTEGER: 4|.1.3.6.1.4.1.388.14.4.1.4.1.1.4 = STRING: "disassociated"|.1.3.6.1.4.1.388.14.4.1.4.1.1.5 = Hex-STRING: 07 DA 09 1B 09 25 0F 00 |.1.3.6.1.4.1.388.14.4.1.4.1.1.8 = INTEGER: 2 END VARIABLEBINDINGS

    # example associate trap on MAC 00 1B B1 8B 82 13
    # BEGIN TYPE 0 END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.2.1.1.3.0 = Timeticks: (875290) 2:25:52.90|.1.3.6.1.6.3.1.1.4.1.0 = OID: .1.3.6.1.4.1.388.14.5.1.7.1.4|.1.3.6.1.4.1.388.14.5.1.7.1.1 = Hex-STRING: 00 1B B1 8B 82 13 |.1.3.6.1.4.1.388.14.3.3.1.2.2.1.1 = Counter32: 1|.1.3.6.1.4.1.388.14.4.1.4.1.1.1 = INTEGER: 32|.1.3.6.1.4.1.388.14.4.1.4.1.1.2 = INTEGER: 4|.1.3.6.1.4.1.388.14.4.1.4.1.1.4 = STRING: "associated"|.1.3.6.1.4.1.388.14.4.1.4.1.1.5 = Hex-STRING: 07 DA 09 1B 09 26 36 00 |.1.3.6.1.4.1.388.14.4.1.4.1.1.8 = INTEGER: 2 END VARIABLEBINDINGS

    $logger->debug("trap ignored, not useful for wireless controller");
    $trapHashRef->{'trapType'} = 'unknown';

    return $trapHashRef;
}

=item deauthenticateMacDefault

deauthenticateMacDefault a MAC address from wireless network (including 802.1x)

=cut
sub deauthenticateMacDefault {
    my ($this, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    my $oid_avWlanAssociatedClientDisassociateAction = '1.3.6.1.4.1.45.7.9.1.1.1.10';

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't write to avWlanAssociatedClientDisassociateAction");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    # append MAC to deauthenticate to oid to set
    $oid_avWlanAssociatedClientDisassociateAction .= '.' . mac2oid($mac);

    $logger->info("deauthenticate mac $mac from controller: " . $this->{_ip});
    $logger->trace("SNMP set_request for avWlanAssociatedClientDisassociateAction: $oid_avWlanAssociatedClientDisassociateAction");
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [ "$oid_avWlanAssociatedClientDisassociateAction", Net::SNMP::INTEGER, 2 ]
    );

    if (defined($result)) {
        $logger->debug("deauthenticatation successful");
        return $TRUE;
    } else {
        $logger->warn("deauthenticatation failed with " . $this->{_sessionWrite}->error());
        return;
    }
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($this, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $default = $SNMP::SNMP;
    my %tech = (
        $SNMP::SNMP => \&deauthenticateMacDefault,
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
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
