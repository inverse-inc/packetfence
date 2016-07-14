package pf::Switch::Xirrus::AP_http;

=head1 NAME

pf::Switch::Xirrus::AP_http

=head1 SYNOPSIS

The pf::Switch::Xirrus::AP_http module implements an object oriented interface to
manage the external captive portal on Xirrus access points

=head1 STATUS

Developed and tested on XR4430 running 6.4.1

=head1 BUGS AND LIMITATIONS

=head2 Cannot use the access point behind a NAT gateway

Since the access point is not sending the IP address of the device in the URL parameters,
the access point and PacketFence cannot be separated by a NAT gateway.
This module uses the remote IP in the HTTP request to determine the IP of the client.

=cut

use strict;
use warnings;

use base ('pf::Switch::Xirrus');

use pf::constants;
use pf::config qw(
    $WIRELESS_MAC_AUTH
);
use pf::util;
use pf::node;

sub description { 'Xirrus WiFi Arrays HTTP' }

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessMacAuth { return $TRUE; }
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

    my $client_ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $r->connection->remote_ip;

    %params = (
        switch_id       => $req->param('nasid'),
        client_mac      => clean_mac($req->param('mac')),
        client_ip       => $client_ip,
        ssid            => $req->param('ssid'),
        redirect_url    => $req->param('userurl'),
        status_code     => '200',
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

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    my $radius_reply_ref = {};
    my $status;

    # should this node be kicked out?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if (defined($kick));

    my $node = $args->{'node_info'};

    my $violation = pf::violation::violation_view_top($args->{'mac'});
    # if user is unregistered or is in violation then we reject him to show him the captive portal
    if ( $node->{status} eq $pf::node::STATUS_UNREGISTERED || defined($violation) ){
        $logger->info("is unregistered. Refusing access to force the eCWP");
        my $radius_reply_ref = {
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => -1,
        };
        ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
        return [$status, %$radius_reply_ref];

    }
    else{
        $logger->info("Returning ACCEPT");
        ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
        return [$status, %$radius_reply_ref];
    }

}

sub getAcceptForm {
    my ( $self, $mac , $destination_url, $cgi_session) = @_;
    my $logger = $self->logger;
    $logger->debug("Creating web release form");

    my $uamip = $cgi_session->param("ecwp-original-param-uamip");
    my $uamport = $cgi_session->param("ecwp-original-param-uamport");
    my $userurl = $cgi_session->param("ecwp-original-param-userurl");
    my $challenge = $cgi_session->param("ecwp-original-param-challenge");
    my $newchal  = pack "H32", $challenge;

    my @ib = unpack("C*", "\0" . $mac . $newchal);
    my $encstr = join("", map {sprintf('\%3.3o', $_)} @ib);
    my ($passvar) = split(/ /, `printf '$encstr' | md5sum`);

    $mac =~ s/:/-/g;

    my $html_form = qq[
        <script>
        if (document.URL.match(/res=success/)){
            //http requests are too fast for the ap
            //we leave him time to understand what is happening
            setTimeout(function(){window.location = "$destination_url"}, 2000)
        }
        else{
            window.location = "http://$uamip:$uamport/logon?username=$mac&password=$passvar&userurl=$destination_url"
        }
        </script>
    ];

    $logger->debug("Generated the following html form : ".$html_form);
    return $html_form;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
