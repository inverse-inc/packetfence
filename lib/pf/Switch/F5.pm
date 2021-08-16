package pf::Switch::F5;

=head1 NAME

pf::Switch::F5 - Object oriented module to F5 VPN

=head1 SYNOPSIS

The pf::Switch::F5  module implements an object oriented interface to interact with the F5 VPN

=head1 STATUS



=cut

=head1 BUGS AND LIMITATIONS

Not doing deauthentication in web auth

=cut

use strict;
use warnings;
use pf::node;
use pf::security_event;
use pf::locationlog;
use pf::util;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI;
use pf::log;
use pf::constants;
use pf::accounting qw(node_accounting_dynauth_attr);
use pf::config qw ($WEBAUTH_WIRELESS $VIRTUAL_VPN);
use pf::constants::role qw($REJECT_ROLE);

use base ('pf::Switch');

=head1 METHODS

=cut

sub description { 'F5 VPN' }

use pf::SwitchSupports qw(
    ExternalPortal
    WebFormRegistration
    WirelessMacAuth
    WiredMacAuth
    WirelessDot1x
    RoleBasedEnforcement
    VPN
    ExternalPortal
);

=item getIfIndexByNasPortId

Return constant sice there is no ifindex

=cut

sub getIfIndexByNasPortId {
   return 'external';
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

    my $client_ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $r->connection->remote_ip;

    my $client_mac = random_mac();

    if($req->param('conf_id')) {
        $switch_id = $req->param('conf_id');
    } else {
        my $uri = URI->new($req->param('post_url'));
        $switch_id = $uri->host();
    }

    %params = (
        switch_id               => $switch_id,
        client_mac              => $client_mac,
        client_ip               => $client_ip,
        grant_url               => $req->param('post_url'),
        status_code             => '200',
        synchronize_locationlog => $TRUE,
        connection_type         => $VIRTUAL_VPN,
        user_id                 => $req->param('id'),
    );

    return \%params;
}

=head2 returnRadiusAccessAccept

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
        else{
            $logger->info("Returning ACCEPT");
            ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
            return [$status, %$radius_reply_ref];
        }
    }

    return $self->SUPER::returnRadiusAccessAccept($args);
}

=head2 getAcceptForm

Return the accept form to the client

=cut

sub getAcceptForm {
    my ( $self, $mac , $destination_url,$cgi_session, $username) = @_;
    my $logger = $self->logger;
    $logger->debug("Creating web release form");

    my $post = $cgi_session->param("ecwp-original-param-post_url");

    my $html_form = qq[
        <form name="weblogin_form" data-autosubmit="1000" method="POST" action="$post">
            <input type="hidden" name="username" value="$username">
            <input type="hidden" name="password" value="$mac">
            <input type="submit" style="display:none;">
        </form>
        <script src="/content/autosubmit.js" type="text/javascript"></script>
    ];

    $logger->debug("Generated the following html form : ".$html_form);
    return $html_form;
}

=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Fortinet-Group-Name';
}

=item deauthenticateMacDefault

Overrides base method to send Acct-Session-Id within the RADIUS disconnect request

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    #Fetching the acct-session-id
    my $dynauth = node_accounting_dynauth_attr($mac);

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect(
        $mac, { 'Acct-Session-Id' => $dynauth->{'acctsessionid'}, 'User-Name' => $dynauth->{'username'} },
    );
}

=head2 getVersion

return a constant since there is no api for this

=cut

sub getVersion {
    my ($self) = @_;
    return 0;
}

=item identifyConnectionType

Determine Connection Type based on radius attributes

=cut


sub identifyConnectionType {
    my ( $self, $connection, $radius_request ) = @_;
    my $logger = $self->logger;


    my @require = qw(Service-Type);
    my @found = grep {exists $radius_request->{$_}} @require;


    if (@require == @found) {
        if ($radius_request->{"Service-Type"} == 8) {
            $connection->isVPN($TRUE);
            $connection->isCLI($FALSE);
        } else {
            $connection->isVPN($FALSE);
        }
    } else {
        $connection->isVPN($FALSE);
    }
}


=item returnAuthorizeVPN

Return radius attributes to allow VPN access

=cut

sub returnAuthorizeVPN {
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
    $logger->info("Returning ACCEPT");
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=item parseVPNRequest

Redefinition of pf::Switch::parseVPNRequest due to specific attribute being used

=cut

sub parseVPNRequest {
    my ( $self, $radius_request ) = @_;
    my $logger = $self->logger;
use Data::Dumper;
$logger->warn(Dumper $radius_request);

    my $client_ip       = $radius_request->{'Tunnel-Client-Endpoint'};
    my $mac             = '00:00:' . join(':', map { sprintf("%02x", $_) } split /\./, $radius_request->{'Tunnel-Client-Endpoint'});
    my $user_name       = $self->parseRequestUsername($radius_request);
    my $nas_port_type   = $radius_request->{'NAS-Port-Type'};
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );

    return ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, undef, $nas_port_id);
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
