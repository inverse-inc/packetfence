package pf::Switch::Motorola;

=head1 NAME

pf::Switch::Motorola

=head1 SYNOPSIS

The pf::Switch::Motorola module implements an object oriented interface to
manage Motorola RF Switches (Wireless Controllers)

=head1 STATUS

Developed and tested on RFS7000 running OS release 4.3.0.0-059R,
and RFS6000 running OS 5.2.0.0-069R.

=over

=item Supports

=over

=item Deauthentication with RADIUS Disconnect (RFC3576)

=item Deauthentication with SNMP

=item Roles-assignment through RADIUS

=back

=back

=head1 BUGS AND LIMITATIONS

=over

=item Firmware 4.x support

Deauthentication against firmware 4.x series is done using SNMP

=item Firmware 5.x support

Deauthentication against firmware 5.x series is done using RADIUS CoA.

=item SNMPv3

SNMPv3 support is untested.

=back

=cut

use strict;
use warnings;

use base ('pf::Switch');

use pf::accounting qw(node_accounting_current_sessionid);
use pf::constants;
use pf::config qw(
    $MAC
    $SSID
);
use pf::util;

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsRoleBasedEnforcement { return $TRUE; }
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item getVersion

obtain image version information from switch

=cut

sub getVersion {
    my ($self)       = @_;
    my $oid_sysDescr = '1.3.6.1.2.1.1.1.0';
    my $logger       = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_sysDescr");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_sysDescr] );
    my $sysDescr = ( $result->{$oid_sysDescr} || '' );

    # sysDescr sample output:
    # RFS7000 Wireless Switch, Version 4.3.0.0-059R MIB=01a

    # all non-whitespace characters grouped after the string Version
    if ( $sysDescr =~ / Version (\S+)/ ) {
        return $1;
    } else {
        $logger->warn("couldn't extract exact version information, returning SNMP System Description instead");
        return $sysDescr;
    }
}

=item parseTrap

Parsing SNMP Traps - WIDS stuff only, other types are discarded

=cut

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    $logger->debug("trap currently not handled");
    $trapHashRef->{'trapType'} = 'unknown';

    return $trapHashRef;
}

=item deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1x).

New implementation using RADIUS Disconnect-Request.

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    if ($self->getVersion() =~ /^5/) {
        #Fetching the acct-session-id, mandatory for Motorola
        my $acctsessionid = node_accounting_current_sessionid($mac);

        $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
        return $self->radiusDisconnect( $mac, { 'Acct-Session-Id' => $acctsessionid } );
    } else {
        $logger->debug("deauthenticate $mac using SNMP deauth method");
        return $self->_deauthenticateMacSNMP($mac);
    }
}

=item _deauthenticateMacSNMP

deauthenticate a MAC address from wireless network (including 802.1x)

=cut

sub _deauthenticateMacSNMP {
    my ($self, $mac) = @_;
    my $logger = $self->logger;
    my $oid_wsCcRfMuDisassociateNow = '1.3.6.1.4.1.388.14.3.2.1.12.3.1.19'; # from WS-CC-RF-MIB

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't write to wsCcRfMuDisassociateNow");
        return 1;
    }

    # handles if deauth should be performed against controller or actual device. Returns sessionWrite hash key to use.
    my $performDeauthOn = $self->getDeauthSnmpConnectionKey();
    if ( !defined($performDeauthOn) ) {
        return;
    }

    # append MAC to deauthenticate to oid to set
    $oid_wsCcRfMuDisassociateNow .= '.' . mac2oid($mac);

    $logger->info("deauthenticate mac $mac from controller: " . $self->{_ip});
    $logger->trace("SNMP set_request for wsCcRfMuDisassociateNow: $oid_wsCcRfMuDisassociateNow");
    my $result = $self->{$performDeauthOn}->set_request(
        -varbindlist => [ "$oid_wsCcRfMuDisassociateNow", Net::SNMP::INTEGER, $TRUE ]
    );

    if (defined($result)) {
        $logger->debug("deauthenticatation successful");
        return $TRUE;
    } else {
        $logger->warn("deauthenticatation failed with " . $self->{$performDeauthOn}->error());
        return;
    }
}

=item returnRoleAttribute

Motorola uses the following VSA for role assignment

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Symbol-User-Group';
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::SNMP;
    my %tech = (
        $SNMP::SNMP => 'deauthenticateMacDefault',
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
