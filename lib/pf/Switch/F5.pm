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
use pf::util;
use pf::log;
use pf::constants;
use pf::config qw ($WEBAUTH_WIRELESS $VIRTUAL_VPN);
use Readonly;

use base ('pf::Switch');

Readonly::Scalar our $AUTHENTICATE_ONLY => 8;

=head1 METHODS

=cut

sub description { 'F5 VPN' }

use pf::SwitchSupports qw(
    ExternalPortal
    WebFormRegistration
    VPN
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
    my @proxied_ip = split(',', $client_ip);
    $client_ip = $proxied_ip[0];

    my $client_mac = random_mac();

    my $switch_id;
    if($req->param('conf_id')) {
        $switch_id = $req->param('conf_id');
    } else {
        my $uri = URI->new($req->param('post_url'));
        $switch_id = $uri ? $uri->host() : undef;
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
        if ($radius_request->{"Service-Type"} == $AUTHENTICATE_ONLY) {
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

    my $client_ip       = $radius_request->{'Tunnel-Client-Endpoint'};
    my $mac             = '02:00:' . join(':', map { sprintf("%02x", $_) } split /\./, $radius_request->{'Tunnel-Client-Endpoint'});
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

Copyright (C) 2005-2024 Inverse inc.

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
