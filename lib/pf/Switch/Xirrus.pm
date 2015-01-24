package pf::Switch::Xirrus;

=head1 NAME

pf::Switch::Xirrus

=head1 SYNOPSIS

The pf::Switch::Xirrus module implements an object oriented interface to manage Xirrus Wireless Access Points.

=head1 STATUS

Developed and tested against XS4 model ArrayOS version 3.5-724.

According to Xirrus engineers, this modules should work on any XS and XN model.

=head1 BUGS AND LIMITATIONS

SNMPv3 support is untested.

=cut

use strict;
use warnings;

use Log::Log4perl;
use POSIX;

use base ('pf::Switch');

use pf::constants;
use pf::config;
use pf::Switch::constants;
use pf::util;
use pf::util::radius qw(perform_disconnect);
use Try::Tiny;

sub description { 'Xirrus WiFi Arrays' }

=head1 SUBROUTINES

TODO: this list is incomplete

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
    my ($this)       = @_;
    my $oid_sysDescr = '1.3.6.1.2.1.1.1.0';
    my $logger       = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_sysDescr");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid_sysDescr] );
    my $sysDescr = ( $result->{$oid_sysDescr} || '' );

    # sysDescr sample output:
    #Xirrus XS4 WiFi Array
    #, ArrayOS Version 3.5-724

    if ( $sysDescr =~ m/Version (\d+\.\d+-\d+)/ ) {
        return $1;
    } else {
        $logger->warn("couldn't extract exact version information, returning SNMP System Description instead");
        return $sysDescr;
    }
}

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # wlsxNUserEntryDeAuthenticated: 1.3.6.1.4.1.14823.2.3.1.11.1.2.1017

    if ( $trapString =~ /\.1\.3\.6\.1\.4\.1\.14823\.2\.3\.1\.11\.1\.2\.1017[|].+[|]\.1\.3\.6\.1\.4\.1\.14823\.2\.3\.1\.11\.1\.1\.52\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/ ) {
        $trapHashRef->{'trapType'} = 'dot11Deauthentication';
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($1);

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

=item deauthenticateMacDefault

deauthenticate a MAC address from wireless network (including 802.1x)

=cut

sub deauthenticateMacDefault {
    my ($this, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    my $OID_stationDeauthMacAddress = '1.3.6.1.4.1.21013.1.2.22.3.0'; # from XIRRUS-MIB

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't write to the stationDeauthMacAddress");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    $logger->trace("SNMP set_request for stationDeauthMacAddress: $OID_stationDeauthMacAddress");
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_stationDeauthMacAddress",
            Net::SNMP::OCTET_STRING,
            $mac
        ] );

    # TODO: validate result
    $logger->info("deauthenticate mac $mac from access point : " . $this->{_ip});
    return ( defined($result) );

}

=item deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1x).

New implementation using RADIUS Disconnect-Request.

=cut

sub deauthenticateMacRadius {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    # TODO push Login-User => 1 (RFC2865) in pf::radius::constants if someone ever reads this
    # (not done because it doesn't exist in current branch)
    return $self->radiusDisconnect( $mac );
}

=item radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Optionally you can provide other attributes as an hashref.

Uses L<pf::util::radius> for the low-level RADIUS stuff.

=cut

# TODO consider whether we should handle retries or not?

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $management_network->tag('vip'),
        };

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;

        # Standard Attributes
        my $attributes_ref = {
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = perform_disconnect( $connection_info,
            {
                'Calling-Station-Id' => $mac,
            },
        );
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($this, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $default = $SNMP::SNMP;
    my %tech = (
        $SNMP::SNMP => 'deauthenticateMacDefault',
        $SNMP::RADIUS => 'deauthenticateMacRadius',
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

