package pf::Switch::Ubiquiti::Unifi;

=head1 NAME

pf::Switch::Ubiquiti::Unifi

=head1 SYNOPSIS

The pf::Switch::Ubiquiti::Unifi module implements an object oriented interface to
manage Unifi  controllers

=head1 STATUS

Developed and tested on Unifi controller version 5.4.14 with a UniFi AP-AC-Pro running 3.4.14.3413

=head1 BUGS AND LIMITATIONS

=cut

use strict;
use warnings;

use base ('pf::Switch');

use pf::violation qw(violation_count_reevaluate_access);
use pf::constants::node qw($STATUS_UNREGISTERED);
use pf::file_paths qw($var_dir);
use pf::constants;
use pf::util;
use pf::node;

# The port to reach the Unifi controller API
our $UNIFI_API_PORT = "8443";

sub description { 'Unifi Controller' }

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
sub supportsExternalPortal { return $TRUE; }

=head2 synchronize_locationlog

Override the Switch method so that the controller IP is inserted as the switch_ip in the locationlog

=cut

sub synchronize_locationlog {
    my ( $self, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, $ifDesc) = @_;
    # Set the switch IP to the controller IP so that the locationlog entry has the proper switch_ip entry
    $self->{_ip} = $self->{_controllerIp};
    $self->SUPER::synchronize_locationlog($ifIndex, $vlan, $mac, $voip_status, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, $ifDesc);
}

=head2 parseExternalPortalRequest

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
        switch_id               => $req->param('ap'),
        client_mac              => clean_mac($req->param('id')),
        client_ip               => $client_ip,
        ssid                    => $req->param('ssid'),
        redirect_url            => $req->param('url'),
        status_code             => '200',
        synchronize_locationlog => $TRUE,
    );

    return \%params;
}

=head2 deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::HTTP;
    my %tech = (
        $SNMP::HTTP  => '_deauthenticateMacWithHTTP',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=head2 _deauthenticateMacWithHTTP

Enable or disable the access of a user (portal vs no portal) using an HTTP webservices call

=cut

sub _deauthenticateMacWithHTTP {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;

    my $node_info = node_view($mac);

    my $controllerIp = $self->{_controllerIp};
    my $transport = lc($self->{_wsTransport});
    my $username = $self->{_wsUser};
    my $password = $self->{_wsPwd};

    my $command = ($node_info->{status} eq $STATUS_UNREGISTERED || violation_count_reevaluate_access($mac)) ? "unauthorize-guest" : "authorize-guest";

    my $ua = LWP::UserAgent->new();
    $ua->cookie_jar({ file => "$var_dir/run/.ubiquiti.cookies.txt" });
    $ua->ssl_opts(verify_hostname => 0);
    $ua->timeout(10);


    my $base_url = "$transport://$controllerIp:$UNIFI_API_PORT";

    my $response = $ua->post("$base_url/api/login", Content => '{"username":"'.$username.'", "password":"'.$password.'"}');

    unless($response->is_success) {
        $logger->error("Can't login on the Unifi controller: ".$response->status_line);
        return;
    }

    $response = $ua->post("$base_url/api/s/default/cmd/stamgr", Content => '{"cmd":"'.$command.'", "mac":"'.$mac.'"}');
    
    unless($response->is_success) {
        $logger->error("Can't send request on the Unifi controller: ".$response->status_line);
        return;
    }

    $logger->info("Switched status on the Unifi controller using command $command");
}


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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
