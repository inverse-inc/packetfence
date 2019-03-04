package pf::Switch::Aruba;

=head1 NAME

pf::Switch::Aruba

=head1 SYNOPSIS

The pf::Switch::Aruba module implements an object oriented interface
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

use base ('pf::Switch');

use POSIX;
use Try::Tiny;

use pf::constants;
use pf::config qw(
    $MAC
    $SSID
    $WEBAUTH_WIRELESS
);
use pf::Switch::constants;
use pf::util;
sub description { 'Aruba Networks' }
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
sub supportsExternalPortal { return $TRUE; }
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }

# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item getVersion - obtain image version information from switch

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
    if ( $sysDescr =~ m/V(\d{1}\.\d{2}\.\d{2})/ ) {
        return $1;
    } elsif ( $sysDescr =~ m/Version (\d+\.\d+\([^)]+\)[^,\s]*)(,|\s)+/ ) {
        return $1;
    } else {
        return $sysDescr;
    }
}

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    # wlsxNUserEntryDeAuthenticated: 1.3.6.1.4.1.14823.2.3.1.11.1.2.1017

    if ( $trapString =~ /\.1\.3\.6\.1\.4\.1\.14823\.2\.3\.1\.11\.1\.2\.1017[|].+[|]\.1\.3\.6\.1\.4\.1\.14823\.2\.3\.1\.11\.1\.1\.52\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/) {
        $trapHashRef->{'trapType'}    = 'dot11Deauthentication';
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
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("(".$self->{'_id'}.") not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("(".$self->{'_id'}.") deauthenticate using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect($mac);
}

=item _deauthenticateMacWithTelnet

DEPRECATED

De-authenticate a MAC address from wireless network (including 802.1x)

Here, we find out what submodule to call _dot1xDeauthenticateMAC or _deauthenticateMAC and call accordingly.

=cut

sub _deauthenticateMacWithTelnet {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("(".$self->{'_id'}.") not in production mode ... we won't write to the bnsMobileStationTable");
        return 1;
    }

    if ( !$self->connectRead() ) {
        $logger->error("(".$self->{'_id'}.") Can not connect using SNMP to Aruba Controller ");
        return 1;
    }

    if ( length($mac) != 17 ) {
        $logger->error("MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx");
        return 1;
    }

    if (defined($is_dot1x) && $is_dot1x) {
        $logger->debug("deauthenticate using 802.1x deauth method");
        $self->_dot1xDeauthenticateMAC($mac);
    } else {
        # Any other authentication method lets kick out with traditionnal approach
        $logger->debug("deauthenticate using non-802.1x deauth method");
        $self->_deauthenticateMAC($mac);
    }
}

# old code used to find user authentication method then kick him out accordingly, not required anymore
#use constant AUTH_DOT1X => 4;
#sub deauthenticateMac {
#    my ($self, $mac) = @_;
#    my $logger = $self->logger;
#    my $OID_nUserAuthenticationMethod = '1.3.6.1.4.1.14823.2.2.1.4.1.2.1.6'; # from WLSX-USER-MIB
#    ...
#    # Query the controller to get the type of authentication the user is using
#    $logger->trace("SNMP get_table for nUserAuthenticationMethod: $OID_nUserAuthenticationMethod");
#    my $result = $self->{_sessionRead}->get_table(-baseoid => "$OID_nUserAuthenticationMethod");
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
#                        $self->_dot1xDeauthenticateMAC($mac);
#                    } else {
#                        # Any other authentication method lets kick out with traditionnal approach
#                        $logger->trace("using non-802.1x deauth method");
#                        $self->_deauthenticateMAC($mac);
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
    my ($self, $mac) = @_;
    my $logger = $self->logger;

    my $session = $self->getTelnetSession;
    if (!$session) {
        $logger->error("(".$self->{'_id'}.") Can't connect to Aruba Controller  using ".$self->{_cliTransport});
        return;
    }

    my $cmd = "aaa user delete mac $mac";

    $logger->info("deauthenticating 802.1x with: $cmd");
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
    my ($self, $mac) = @_;
    my $logger = $self->logger;
    my $OID_nUserApBSSID = '1.3.6.1.4.1.14823.2.2.1.4.1.2.1.11'; # from WLSX-USER-MIB

    # Query the controller to get the MAC address of the AP to which the client is associated
    $logger->trace("SNMP get_table for nUserApBSSID: $OID_nUserApBSSID");
    my $result = $self->{_sessionRead}->get_table(-baseoid => "$OID_nUserApBSSID");
    if (keys %{$result}) {

        my $session = $self->getTelnetSession;
        if (!$session) {
            $logger->error("(".$self->{'_id'}.") Can't connect to Aruba Controller using ".$self->{_cliTransport});
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

                    $logger->info("deauthenticating from SSID $apSSID with: $cmd");
                    $session->cmd($cmd);
                    $count++;
                } else {
                    $logger->error("The MAC address format of the SSID is invalid: $macIpToBSSID");
                }
            }
        }

        $session->close();
        if ($count > 1) {
            $logger->warn("We deauthenticated more than one client with this mac");
        } elsif ($count == 0) {
            $logger->info("no one was deauthenticated (request with this mac)");
        }
    } else {
        $logger->error("Can not get AP SSID from Aruba Controller for this MAC");
        return;
    }
}

# TODO: extract in a more generic place?
sub getTelnetSession {
    my ($self) = @_;
    my $logger = $self->logger;

    # use telnet to deauthenticate the client
    # FIXME: we do not honor the $self->{_cliTransport} parameter
    my $session;
    eval {
        require Net::Telnet;
        $session = Net::Telnet->new(
            Host    => $self->{_controllerIp} || $self->{_ip},
            Timeout => 5,
            Prompt  => '/[\$%#>]$/'
        );
        $session->waitfor('/User: /');
        $session->put( $self->{_cliUser} . "\n" );
        $session->waitfor('/Password:/');
        $session->put( $self->{_cliPwd} . "\n" );
        $session->waitfor( $session->prompt );
        $session->put( "en\n" );
        $session->waitfor('/Password:/');
        $session->put( $self->{_cliEnablePwd} . "\n" );
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

Aruba specific parser. See pf::Switch for base implementation.

=cut

sub extractSsid {
    my ($self, $radius_request) = @_;
    my $logger = $self->logger;

    # Aruba-Essid-Name VSA
    if (defined($radius_request->{'Aruba-Essid-Name'})) {
        return $radius_request->{'Aruba-Essid-Name'};
    }

    $logger->warn(
        "Unable to extract SSID for module " . ref($self) . ". SSID-based VLAN assignments won't work. "
        . "Please let us know so we can add support for it."
    );
    return;
}

=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Aruba-User-Role';
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => 'deauthenticateMacDefault',
        $SNMP::TELNET  => '_deauthenticateMacWithTelnet',
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
    my $logger = $self->logger;

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
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
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

        if ( $self->shouldUseCoA({role => $role}) ) {

            $attributes_ref = {
                %$attributes_ref,
                'Filter-Id' => $role,
            };
            $logger->info("[$self->{'_ip'}] Returning ACCEPT with role: $role");
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

    return $TRUE if ( ($response->{'Code'} eq 'Disconnect-ACK') || ($response->{'Code'} eq 'CoA-ACK') );

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
    my $logger = $self->logger;
    return ($radius_request->{'Aruba-User-Vlan'});
}


=item parseExternalPortalRequest

Parse external portal request using URI and it's parameters then return an hash reference with the appropriate parameters

See L<pf::web::externalportal::handle>

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;
    my $logger = $self->logger;

    # Using a hash to contain external portal parameters
    my %params = ();

    %params = (
        switch_id               => defined($req->param('switchip')) ? $req->param('switchip') : $req->param('apname'),
        client_mac              => clean_mac($req->param('mac')),
        client_ip               => $req->param('ip'),
        ssid                    => $req->param('essid'),
        redirect_url            => $req->param('url'),
        synchronize_locationlog => $FALSE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}

=item returnAuthorizeWrite

Return radius attributes to allow write access

=cut

sub returnAuthorizeWrite {
   my ($self, $args) = @_;
   my $logger = $self->logger;
   my $radius_reply_ref = {};
   my $status;
   $radius_reply_ref->{'Class'} = 'root';
   $radius_reply_ref->{'Reply-Message'} = "Switch enable access granted by PacketFence";
   $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with write access");
   my $filter = pf::access_filter::radius->new;
   my $rule = $filter->test('returnAuthorizeWrite', $args);
   ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
   return [$status, %$radius_reply_ref];
}

=item returnAuthorizeRead

Return radius attributes to allow read access

=cut

sub returnAuthorizeRead {
   my ($self, $args) = @_;
   my $logger = $self->logger;
   my $radius_reply_ref = {};
   my $status;
   $radius_reply_ref->{'Class'} = 'read-only';
   $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
   $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
   my $filter = pf::access_filter::radius->new;
   my $rule = $filter->test('returnAuthorizeRead', $args);
   ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
   return [$status, %$radius_reply_ref];
}

=item

=cut

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
