package pf::SNMP::Aruba;

=head1 NAME

pf::SNMP::Aruba

=head1 SYNOPSIS

The pf::SNMP::Aruba module implements an object oriented interface
to access and manage Aruba Wireless Controllers.

=cut

=head1 STATUS

Developed and tested on Controller 200 running firmware 5.0.3.3

Tested on Controller 600 with RADIUS Disconnect running firmware 6.0.x

=over

=item Supports

=over

=item Deauthentication with RADIUS Disconnect (RFC3576)

=item Deauthentication with Telnet

=item Role-based access control

=back

=back

=head1 BUGS AND LIMITATIONS

=over

=item Telnet deauthentication broken on firmware 6.x

We had reports that Telnet-based deauthentication is no longer working with
the firmware 6 series.

Although this is not a PacketFence issue, upgrading PacketFence to 3.1.0 will
work-around this situation since we use a new RADIUS-based technique to
perform deauthentication on Aruba.

Reported on firmware 6.1.3.1. Let us know if you have a 6.x version and you
are unaffected.

=back

=cut

use strict;
use warnings;

use base ('pf::SNMP');

use POSIX;
use Log::Log4perl;
use Net::Telnet;
use Try::Tiny;
use Data::Dumper;

use pf::config;
use pf::SNMP::constants;
use pf::util;
use pf::roles::custom;
use pf::accounting qw(node_accounting_current_sessionid);
use pf::util::radius qw(perform_coa perform_disconnect);
use pf::node qw(node_attributes);

=head1 SUBROUTINES

TODO: this list is incomplete

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsRoleBasedEnforcement { return $TRUE; }
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item getVersion - obtain image version information from switch

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

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # wlsxNUserEntryDeAuthenticated: 1.3.6.1.4.1.14823.2.3.1.11.1.2.1017

    if ( $trapString =~ /\.1\.3\.6\.1\.4\.1\.14823\.2\.3\.1\.11\.1\.2\.1017[|].+[|]\.1\.3\.6\.1\.4\.1\.14823\.2\.3\.1\.11\.1\.1\.52\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/) {
        $trapHashRef->{'trapType'}    = 'dot11Deauthentication';
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($1);

    } elsif ( $trapString =~ /\.1\.3\.6\.1\.4\.1\.14823\.2\.3\.1\.11\.1\.1\.5\.0 = $SNMP::MAC_ADDRESS_FORMAT/ ) {
        $trapHashRef->{'trapType'}    = 'wirelessIPS';
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($1);
    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

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
    return $self->radiusDisconnect($mac);
}

=item _deauthenticateMacWithTelnet

DEPRECATED

De-authenticate a MAC address from wireless network (including 802.1x)

Here, we find out what submodule to call _dot1xDeauthenticateMAC or _deauthenticateMAC and call accordingly.

=cut

sub _deauthenticateMacWithTelnet {
    my ( $this, $mac, $is_dot1x ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't write to the bnsMobileStationTable");
        return 1;
    }

    if ( !$this->connectRead() ) {
        $logger->error("Can not connect using SNMP to Aruba Controller " . $this->{_id});
        return 1;
    }

    if ( length($mac) != 17 ) {
        $logger->error("MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx");
        return 1;
    }

    if (defined($is_dot1x) && $is_dot1x) {
        $logger->debug("deauthenticate $mac using 802.1x deauth method");
        $this->_dot1xDeauthenticateMAC($mac);
    } else {
        # Any other authentication method lets kick out with traditionnal approach
        $logger->debug("deauthenticate $mac using non-802.1x deauth method");
        $this->_deauthenticateMAC($mac);
    }
}

# old code used to find user authentication method then kick him out accordingly, not required anymore
#use constant AUTH_DOT1X => 4;
#sub deauthenticateMac {
#    my ($this, $mac) = @_;
#    my $logger = Log::Log4perl::get_logger( ref($this) );
#    my $OID_nUserAuthenticationMethod = '1.3.6.1.4.1.14823.2.2.1.4.1.2.1.6'; # from WLSX-USER-MIB
#    ...
#    # Query the controller to get the type of authentication the user is using
#    $logger->trace("SNMP get_table for nUserAuthenticationMethod: $OID_nUserAuthenticationMethod");
#    my $result = $this->{_sessionRead}->get_table(-baseoid => "$OID_nUserAuthenticationMethod");
#    # is there at least one result?
#    if (keys %{$result}) {
#
#        # convert MAC into oid format
#        my $macOID = mac2oid($mac);
#
#        # Fetch Auth Method for the MAC we are interested in
#        my $count = 0;
#        foreach my $macIpToUserAuthMethod (keys %{$result}) {
#            if ($macIpToUserAuthMethod =~ /^$OID_nUserAuthenticationMethod\.$macOID/) {
#                if ($count > 1) {
#                    $logger->warn("MAC: $mac returned two authentication method, it should not happen!" .
#                                  " Please file a bug with steps to reproduce");
#                    return;
#                } else {
#                    if ($result->{$macIpToUserAuthMethod} == AUTH_DOT1X) {
#                        $logger->trace("using 802.1x deauth method");
#                        $this->_dot1xDeauthenticateMAC($mac);
#                    } else {
#                        # Any other authentication method lets kick out with traditionnal approach
#                        $logger->trace("using non-802.1x deauth method");
#                        $this->_deauthenticateMAC($mac);
#                    }
#                    $count++;
#                }
#           }
#        }
#    } else {
#        $logger->error("was not able to find user authentication type for mac $mac, unable to deauthenticate");
#    }
#}

=item _dot1xDeauthenticateMAC

DEPRECATED

De-authenticate a MAC from controller when user is in 802.1x mode using Telnet.

* Private: don't call outside of same object, use _deauthenticateMacWithTelnet externally *

=cut

sub _dot1xDeauthenticateMAC {
    my ($this, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    my $session = $this->getTelnetSession;
    if (!$session) {
        $logger->error("Can't connect to Aruba Controller ".$this->{'_id'}." using ".$this->{_cliTransport});
        return;
    }

    my $cmd = "aaa user delete mac $mac";

    $logger->info("deauthenticating 802.1x $mac with: $cmd");
    $session->cmd($cmd);

    $session->close();

}

=item _deauthenticateMAC

DEPRECATED

De-authenticate a MAC from controller if user is not in 802.1x mode using Telnet

Here we used to specify MAC and IP in the OID but it doesn't work in a lot of
cases. As soon as the client stops doing activity for a little while, the IP
is forgotten but you can still access the good BSSID with 0.0.0.0 appended at
the end of the OID (no IP).

What we are doing now is fetching the table instead of only one entry and
issuing deauth on the matching MAC in OID format. Worked in my tests with
and without an IP in the table.

* Private: don't call outside of same object, use _deauthenticateMacWithTelnet externally *

=cut

sub _deauthenticateMAC {
    my ($this, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    my $OID_nUserApBSSID = '1.3.6.1.4.1.14823.2.2.1.4.1.2.1.11'; # from WLSX-USER-MIB

    # Query the controller to get the MAC address of the AP to which the client is associated
    $logger->trace("SNMP get_table for nUserApBSSID: $OID_nUserApBSSID");
    my $result = $this->{_sessionRead}->get_table(-baseoid => "$OID_nUserApBSSID");
    if (keys %{$result}) {

        my $session = $this->getTelnetSession;
        if (!$session) {
            $logger->error("Can't connect to Aruba Controller ".$this->{'_id'}." using ".$this->{_cliTransport});
            return;
        }

        # keep track of how many BSSID we grabbed for this MAC
        my $count = 0;

        # convert MAC into oid format
        my $macOID = mac2oid($mac);

        foreach my $macIpToBSSID (keys %{$result}) {
            if ($macIpToBSSID =~ /^$OID_nUserApBSSID\.$macOID/) {
                # TODO: move over clean_mac or valid_mac?
                if ($result->{$macIpToBSSID} =~ /0x([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})/i) {
                    my $apSSID = uc("$1:$2:$3:$4:$5:$6");
                    my $cmd = "stm kick-off-sta $mac $apSSID";

                    $logger->info("deauthenticating $mac from SSID $apSSID with: $cmd");
                    $session->cmd($cmd);
                    $count++;
                } else {
                    $logger->error("The MAC address format of the SSID is invalid: $macIpToBSSID");
                }
            }
        }

        $session->close();
        if ($count > 1) {
            $logger->warn("We deauthenticated more than one client with mac $mac");
        } elsif ($count == 0) {
            $logger->info("no one was deauthenticated (request with mac $mac)");
        }
    } else {
        $logger->error("Can not get AP SSID from Aruba Controller for MAC $mac");
        return;
    }
}

# TODO: extract in a more generic place?
sub getTelnetSession {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # use telnet to deauthenticate the client
    # FIXME: we do not honor the $this->{_cliTransport} parameter
    my $session;
    eval {
        $session = Net::Telnet->new(
            Host    => $this->{_controllerIp} || $this->{_ip},
            Timeout => 5,
            Prompt  => '/[\$%#>]$/'
        );
        $session->waitfor('/User: /');
        $session->put( $this->{_cliUser} . "\n" );
        $session->waitfor('/Password:/');
        $session->put( $this->{_cliPwd} . "\n" );
        $session->waitfor( $session->prompt );
        $session->put( "en\n" );
        $session->waitfor('/Password:/');
        $session->put( $this->{_cliEnablePwd} . "\n" );
        $session->waitfor( $session->prompt );
    };

    if ($@) {
        #$logger->error( Dumper($@));
        return;
    }

    return $session;
}

=item extractSsid

Find RADIUS SSID parameter out of RADIUS REQUEST parameters

Aruba specific parser. See pf::SNMP for base implementation.

=cut

sub extractSsid {
    my ($this, $radius_request) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # Aruba-Essid-Name VSA
    if (defined($radius_request->{'Aruba-Essid-Name'})) {
        return $radius_request->{'Aruba-Essid-Name'};
    }

    $logger->warn(
        "Unable to extract SSID for module " . ref($this) . ". SSID-based VLAN assignments won't work. "
        . "Please let us know so we can add support for it."
    );
    return;
}

=item returnRadiusAccessAccept

Overloading L<pf::SNMP>'s implementation because AeroHIVE doesn't support
assigning VLANs and Roles at the same time.

=cut
sub returnRadiusAccessAccept {
    my ($this, $vlan, $mac, $port, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $radius_reply_ref = {};

    # TODO this is experimental
    try {

        $logger->debug("network device supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $this);

        # Roles are configured and the user should have one
        if (defined($role)) {

            $radius_reply_ref = {
                $this->returnRoleAttribute => $role,
            };

            $logger->info("Returning ACCEPT with Role: $role");
        }

        # if Roles aren't configured, return VLAN information
        else {

            $radius_reply_ref = {
                'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
                'Tunnel-Type' => $RADIUS::VLAN,
                'Tunnel-Private-Group-ID' => $vlan,
            };

            $logger->info("Returning ACCEPT with VLAN: $vlan");
        }

    }
    catch {
        chomp($_);
        $logger->debug(
            "Exception when trying to resolve a Role for the node. Returning VLAN attributes in RADIUS Access-Accept. "
            . "Exception: $_"
        );

        $radius_reply_ref = {
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => $vlan,
        };
    };

    return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
}


=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($this) = @_;

    return 'Aruba-User-Role';
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
        $SNMP::TELNET  => \&_deauthenticateMacWithTelnet,
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
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

        $logger->debug("network device supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        my $acctsessionid = node_accounting_current_sessionid($mac);
        my $node_info = node_attributes($mac);
        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
            'Acct-Session-Id' => $acctsessionid,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        # Roles are configured and the user should have one
        $logger->warn(Dumper $node_info);
        if (defined($role) && (defined($node_info->{'status'}) ) ) {

            $attributes_ref = {
                %$attributes_ref,
                'Filter-Id' => $role,
            };
            $logger->warn(Dumper($connection_info));
            $logger->warn(Dumper($attributes_ref));
            $logger->info("Returning ACCEPT with Role: $role");
            $response = perform_coa($connection_info, $attributes_ref);

        }
        else {
            $response = perform_disconnect($connection_info, $attributes_ref);
        }
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

=item extractVLAN

Extract VLAN from the radius attributes.

=cut

sub extractVLAN {
    my ($self, $radius_request) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    return ($radius_request->{'Aruba-User-Vlan'});
}


=item

=cut

=back

=head1 AUTHOR

Regis Balzard <rbalzard@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Fabrice Durand <fdurand@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009-2012 Inverse inc.

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
