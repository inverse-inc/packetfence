package pf::Switch::Ruckus::SmartZone;

=head1 NAME

pf::Switch::Ruckus::SmartZone

=head1 SYNOPSIS

Implements methods to manage Ruckus SmartZone Wireless Controllers

=cut

use strict;
use warnings;

use base ('pf::Switch::Ruckus');

use pf::accounting qw(node_accounting_dynauth_attr);
use pf::constants;
use pf::util;
use LWP::UserAgent;
use pf::node;
use pf::security_event;
use pf::ip4log;
use JSON::MaybeXS qw(encode_json);
use pf::config qw ($WEBAUTH_WIRELESS);

sub description { 'Ruckus SmartZone Wireless Controllers' }
sub supportsWebFormRegistration { return $FALSE; }
sub supportsWirelessMacAuth { return $TRUE; }

=over


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
        client_mac              => clean_mac($req->param('client_mac')),
        client_ip               => defined($req->param('uip')) ? $req->param('uip') : undef,
        ssid                    => $req->param('ssid'),
        redirect_url            => $req->param('url'),
        switch_id               => $req->param('nbiIP'),
        synchronize_locationlog => $TRUE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::HTTP;
    my %tech = (
        $SNMP::HTTP => 'deauthenticateMacWebservices',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=head2 deauthenticateMacWebservices

Deauthenticate a MAC address using the Ruckus Northbound API

=cut

sub deauthenticateMacWebservices {
    my ($self, $mac) = @_;
    my $logger = $self->logger;
    my $controllerIp = $self->{_controllerIp} || $self->{_ip};
    my $webservicesPassword = $self->{_wsPwd};
    my $ucmac = uc $mac;
    my $ip = pf::ip4log::mac2ip($mac);
    my $node_info = node_view($mac);
    my $payload;
    if($node_info->{status} eq "unreg" || security_event_count_reevaluate_access($mac)) {
        $payload = encode_json({
         "Vendor"=> "ruckus",
         "RequestPassword"=> $webservicesPassword,
         "APIVersion"=> "1.0",
         "RequestCategory"=> "UserOnlineControl",
         "RequestType"=> "Logout",
         "UE-IP"=> $ip,
         "UE-MAC"=> $ucmac
        });
    }
    else {
        $payload = encode_json({
         "Vendor"=> "ruckus",
         "RequestPassword"=> $webservicesPassword,
         "APIVersion"=> "1.0",
         "RequestCategory"=> "UserOnlineControl",
         "RequestType"=> "Login",
         "UE-IP"=> $ip,
         "UE-MAC"=> $ucmac,
         "UE-Proxy"=> "0",
         "UE-Username"=> $ucmac,
         "UE-Password"=> $ucmac
        });
    }
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->ssl_opts(verify_hostname => 0);
    my $res = $ua->post("https://$controllerIp:9443/portalintf", Content => $payload, "Content-Type" => "application/json");
    if($res->is_success) {
        $logger->info("Contacted Ruckus to perform deauthentication");
        $logger->debug("Got the following response: ".$res->decoded_content);
    }
    else {
        $logger->error("Failed to contact Ruckus for deauthentication: ".$res->status_line);
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
