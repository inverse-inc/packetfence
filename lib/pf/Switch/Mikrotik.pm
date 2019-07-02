package pf::Switch::Mikrotik;


=head1 NAME

pf::Switch::Mikrotik

=head1 SYNOPSIS

The pf::Switch::Mikrotik module manages access to Mikrotik APs

=head1 STATUS

Should work on CAPsMAN enabled APs, tested on v6.18

=cut

use strict;
use warnings;

use POSIX;
use Try::Tiny;

use base ('pf::Switch');

use pf::constants;
use pf::config qw(
    $MAC
    $SSID
    $WIRELESS_MAC_AUTH
    $WEBAUTH_WIRELESS
);
sub description { 'Mikrotik' }

# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::util::radius qw(perform_disconnect);

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

sub supportsExternalPortal { return $TRUE; }
sub supportsWebFormRegistration { return $TRUE }

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
        switch_id               => $req->param('ap-id'),
        client_mac              => clean_mac($req->param('mac')),
        client_ip               => $req->param('ip'),
        status_code             => '200',
        synchronize_locationlog => $TRUE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}

=head2 getAcceptForm

Get the accept form to trigger the authentication on the Mikrotik when using webauth

=cut

sub getAcceptForm {
    my ( $self, $mac , $destination_url, $cgi_session) = @_;
    my $logger = $self->logger;
    $logger->debug("Creating web release form");

    my $linkLoginOnly = $cgi_session->param("ecwp-original-param-link-login-only");
    my $linkOrig = $cgi_session->param("ecwp-original-param-link-orig");

    use Digest::MD5 qw(md5_hex);
    $mac =~ s/:/-/g;
    my $pass = md5_hex($cgi_session->param("ecwp-original-param-chap-id").$mac.$cgi_session->param("ecwp-original-param-chap-challenge"));
    my $html_form = qq[
        <form name="weblogin_form" data-autosubmit="1000" method="POST" action="$linkLoginOnly">
            <input type="hidden" name="dst" value="$linkOrig" />
            <input type="hidden" name="popup" value="true" />
            <input type="hidden" name="username" value="$mac">
            <input type="hidden" name="password" value="$pass">
        </form>
        <script src="/content/autosubmit.js" type="text/javascript"></script>
    ];

    $logger->debug("Generated the following html form : ".$html_form);
    return $html_form;
}


=item getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($self)       = @_;
    my $oid_sysDescr = '1.3.6.1.4.1.14988.1.1.4.4.0';
    my $logger       = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_sysDescr");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_sysDescr] );
    my $sysDescr = ( $result->{$oid_sysDescr} || '' );
    return $sysDescr;
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::SSH;
    my %tech = (
        $SNMP::SSH    => 'deauthenticateMacSSH',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=item deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1x).

New implementation using RADIUS Disconnect-Request.

This method has been kept since we will probably use this deauth method in the future

=cut

sub deauthenticateMacRadius {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect($mac);
}

=item radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Has been tested with 6.18 Mikrotik OS version and doesn´t work yet

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
            "Unable to perform RADIUS Disconnect-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # Where should we send the RADIUS Disconnect-Request?
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

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = perform_disconnect($connection_info, $attributes_ref);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS Disconnect-Request: $_");
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

=item returnRadiusAccessAccept

Overloading L<pf::Switch>'s implementation because Mikrotik have his own radius attributes.

Don't forget to fill /usr/share/freeradius/dictionary.mikrotik with the following attributes:

ATTRIBUTE       Mikrotik-Wireless-VlanID                26      integer
ATTRIBUTE       Mikrotik-Wireless-VlanIDType            27      integer

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    my $radius_reply_ref = {};
    my $status;

    # should this node be kicked out?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if (defined($kick));

    # Inline Vs. VLAN enforcement
    my $role = "";
    if ( (!$args->{'wasInline'} || ($args->{'wasInline'} && $args->{'vlan'} != 0) ) && isenabled($self->{_VlanMap})) {
        $radius_reply_ref = {
            'Mikrotik-Wireless-VlanID' => $args->{'vlan'} . "",
            'Mikrotik-Wireless-VlanIDType' => "0",
        };
    }

    $logger->info("(".$self->{'_id'}.") Returning ACCEPT with VLAN $args->{'vlan'} and role $role");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=item deauthenticateMacSSH

deauthenticate a MAC address from wireless network

Right now the only way to do it is from the CLI (through SSH).

=cut

sub deauthenticateMacSSH {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't deauthenticate $mac");
        return 1;
    }

    if ( length($mac) != 17 ) {
        $logger->error("MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx");
        return 1;
    }

    my $ssh;

    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }

    eval {
        require Net::SSH2;
        $ssh = Net::SSH2->new();
        $ssh->connect($send_disconnect_to);
        $ssh->auth_password($self->{_cliUser},$self->{_cliPwd});
    };

    if ($@) {
        $logger->error("Unable to connect to ".$send_disconnect_to." using ".$self->{_cliTransport}.". Failed with $@");
        return;
    }

    $mac = uc($mac);
    my $command = "/caps-man registration-table remove [/caps-man registration-table find mac-address=$mac]";

    $logger->info("Deauthenticating mac $mac");
    $logger->warn("sending CLI command '$command'");

    my $chan = $ssh->channel();
    $chan->exec($command);
    $ssh->disconnect();

    return 1;
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

