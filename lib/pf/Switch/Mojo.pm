package pf::Switch::Mojo;

=head1 NAME

pf::Switch::Mojo - Object oriented module to return radius attributes to a Mojo Networks Access Point.
Mojo Networks cloud controller

=head1 STATUS

Developed and tested on firmware version 8.1.1 and build 8.1.1.84
Tested on 8.6.0-316.7 AP model C-130

=over

=item Supports

=over

=item Deauthentication with RADIUS Disconnect (RFC3576)

=back

=back

=head1 BUGS AND LIMITATIONS

This module supports 802.1X and web authentication. MAC authentication is not supported yet.

=over

=item Version specific issues

=back

=cut

use strict;
use warnings;

use base ('pf::Switch');

use pf::constants;
use pf::constants::role qw($REJECT_ROLE);
use pf::util;
use pf::util::radius qw(perform_disconnect);
use pf::radius::constants;
use pf::locationlog;
use Try::Tiny;
use DateTime;
use DateTime::Format::MySQL;
use pf::constants qw($ZERO_DATE);

sub description { 'Mojo Networks AP' }

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsExternalPortal { return $TRUE; }
sub supportsWebFormRegistration { return $TRUE }

=item getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->info("we don't know how to determine the version through SNMP !");
    return '8.1.1';
}

=item deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1X).

New implementation using RADIUS Disconnect-Request.

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    # TODO push Login-User => 1 (RFC2865) in pf::radius::constants if someone ever reads this
    # (not done because it doesn't exist in current branch)
    return $self->radiusDisconnect( $mac, { 'Service-Type' => 'Login-User'} );
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
            "Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): RADIUS Shared Secret not configured"
        );
        return;
    }

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # On which port we have to send the CoA-Request ?
    my $nas_port = $self->{'_disconnectPort'} || '3799';
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $locationlog = locationlog_view_open_mac($mac);
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
            nas_port => $nas_port,
        };

        $logger->debug("network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        # Standard Attributes

        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-Identifier' => uc($locationlog->{switch_mac})."-".$locationlog->{ssid} ,
        };

        $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
            nas_port => $nas_port,
        };
        $response = perform_disconnect($connection_info, $attributes_ref);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS Disconnect-Request on (".$self->{'_id'}."): $_");
        $logger->error("Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.")...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ( ($response->{'Code'} eq 'Disconnect-ACK') || ($response->{'Code'} eq 'CoA-ACK') );

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request on (".$self->{'_id'}.")."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=item extractSsid

Find RADIUS SSID parameter out of RADIUS REQUEST parameters

SSID are not provided by a standardized parameter name so we encapsulate that complexity here.
If your AP is not supported look in /usr/share/freeradius/dictionary* for vendor specific attributes (VSA).

Most standard way we encountered is in Called-Station-Id in the format: "xx-xx-xx-xx-xx-xx:SSID".

We support also:

  "xx:xx:xx:xx:xx:xx:SSID"
  "xxxxxxxxxxxx:SSID"

=cut

sub extractSsid {
    my ($self, $radius_request) = @_;
    my $logger = $self->logger;

    # it's put in Called-Station-Id
    # ie: Called-Station-Id = "aa-bb-cc-dd-ee-ff:Secure SSID" or "aa:bb:cc:dd:ee:ff:Secure SSID"
    if (defined($radius_request->{'Called-Station-Id'})) {
        if ($radius_request->{'Called-Station-Id'} =~ /^
            # below is MAC Address with supported separators: :, - or nothing
            [a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}
            -                                                                                           # : delimiter
            (.*)                                                                                        # SSID
        $/ix) {
            return $1;
        } else {
            $logger->info("Unable to extract SSID of Called-Station-Id: ".$radius_request->{'Called-Station-Id'});
        }
    }

    $logger->warn(
        "Unable to extract SSID for module " . ref($self) . ". SSID-based VLAN assignments won't work. "
        . "Please let us know so we can add support for it."
    );
    return;
}

=back

=item parseExternalPortalRequest

Parse external portal request using URI and its parameters then return a hash reference with the appropriate parameters

See L<pf::web::externalportal::handle>

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;

    # Using a hash to contain external portal parameters
    my %params = ();
    my $client_ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $r->connection->remote_ip;
    %params = (
        switch_id               => pf::SwitchFactory->instantiate($req->param("uamip")) ? $req->param("uamip") : clean_mac($req->param('ap_id')),
        client_mac              => clean_mac($req->param('client_mac')),
        client_ip               => $client_ip,
        ssid                    => $req->param('ap_ssid'),
        synchronize_locationlog => $TRUE,
        redirect_url            => defined($req->param('destination_url')),
    );
    return \%params;
}


=item getAcceptForm

Generates the HTML form embedded to web release captive-portal process to trigger a reauthentication.

=cut

sub getAcceptForm {
    my ( $self, $mac, $destination_url, $portalSession ) = @_;
    my $logger = $self->logger;
    $logger->debug("Creating web release form");

    my $challenge = $portalSession->param("ecwp-original-param-challenge");
    my $login_url = $portalSession->param("ecwp-original-param-login_url");

    # transforming MAC to the expected format 00-11-22-33-CA-FE
    $mac = uc($mac);
    $mac =~ s/:/-/g;

    my $html_form = qq[
        <form name="weblogin_form" data-autosubmit="1000" method="GET" action="$login_url">
            <input type="hidden" name="username" value="$mac">
            <input type="hidden" name="password" value="8549b361c2318e9897ecfbd589c0d6a2">
            <input type="hidden" name="res" value="success">
            <input type="hidden" name="challenge" value="$challenge">
            <input type="hidden" name="redirect" value="$destination_url">
        </form>
        <script src="/content/autosubmit.js" type="text/javascript"></script>
    ];

    $logger->debug("Generated the following html form : ".$html_form);
    return $html_form;
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overriding the default implementation for the external captive portal

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    my $radius_reply_ref = {};
    my $status;
    # should this node be kicked out?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if (defined($kick));

    my $node = $args->{'node_info'};

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);

    if ( $self->externalPortalEnforcement ) {
        my $security_event = pf::security_event::security_event_view_top($args->{'mac'});
        # if user is unregistered or is in security_event then we reject him to show him the captive portal
        if ( $node->{status} eq $pf::node::STATUS_UNREGISTERED || defined($security_event) ){
            $logger->info("[$args->{'mac'}] is unregistered. Refusing access to force the eCWP");
            $args->{user_role} = $REJECT_ROLE;
            $self->handleRadiusDeny();
        }
        else {
            if($node->{unregdate} ne $ZERO_DATE) {
                my $unreg = DateTime::Format::MySQL->parse_datetime($node->{unregdate}) ; 
                $unreg->set_time_zone("local"); 
                my $now = DateTime->now(time_zone => "local"); 
                my $session_timeout = $unreg->epoch - $now->epoch;
                $self->logger->info("Setting Session-Timeout to $session_timeout");
                $radius_reply_ref->{"Session-Timeout"} = $session_timeout;
            }
            $logger->info("Returning ACCEPT");
            ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
            return [$status, %$radius_reply_ref];
        }
    }

    return $self->SUPER::returnRadiusAccessAccept($args);
}

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
