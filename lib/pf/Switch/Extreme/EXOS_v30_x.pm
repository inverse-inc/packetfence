package pf::Switch::Extreme::EXOS_v30_x;

=head1 NAME

pf::Switch::Extreme::EXOS_v30_x - Object oriented module to parse SNMP traps 
and manage Extreme Networks' Summit X250e switches

=head1 STATUS

Developped and tested on a X440G2-12p-10G4.6 running ExtremeXOS version 30.6.1.11

=head1 SNMP

This switch can parse SNMP traps and change a VLAN on a switch port using SNMP.

=cut

use strict;
use warnings;
use Net::SNMP;
use base ('pf::Switch::Extreme::EXOS');

# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::log;
use pf::constants;
use pf::config qw(
    $WEBAUTH_WIRED
    $WIRED_MAC_AUTH
    $WIRED_802_1X
);
use pf::radius::constants qw(%NAS_port_type);
use pf::SwitchSupports qw(
    RoleBasedEnforcement
    ExternalPortal
    ~AccessListBasedEnforcement
);

sub description { "Extreme EXOS v30.x" } 

sub returnRoleAttribute { "Filter-Id" }

=head2 findIfdescUsingSNMP

Calls the switch to obtain the interface description of an ifindex

=cut

sub findIfdescUsingSNMP {
    my ($self, $ifIndex) = @_;
    my $logger = get_logger;
    my $oid_ifDesc = '1.3.6.1.2.1.2.2.1.2';
    if ( !$self->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for ifOperStatus: $oid_ifDesc.$ifIndex");
    my $result = $self->cachedSNMPRequest([-varbindlist => ["$oid_ifDesc.$ifIndex"]], {expires_in => '24h'});
    return $result->{"$oid_ifDesc.$ifIndex"};
}

=head2 parseRequest

Parse the RADIUS request, overriding here to fetch the ifDesc using SNMP if it can't be extracted from the packet

=cut

sub parseRequest {
    my ($self, $radius_request) = @_;
    my ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, $session_id, $ifDesc) = $self->SUPER::parseRequest($radius_request);

    # if NAS-Port-Type is defined and is not virtual or async, we do SNMP queries
    if (defined($nas_port_type) && ($RADIUS::NAS_port_type{$nas_port_type} ne "Virtual" && $RADIUS::NAS_port_type{$nas_port_type} ne "Async")) {
        $ifDesc = $ifDesc || $self->findIfdescUsingSNMP($port);
    }
    return ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, $session_id, $ifDesc);
}

=head2 parseExternalPortalRequest

Parse an external portal request

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;
    my $logger = $self->logger;

    # Using a hash to contain external portal parameters
    my %params = ();

    my $client_mac = clean_mac($req->param('mac'));

    my $locationlog = pf::locationlog::locationlog_view_open_mac($client_mac);
    my $switch_id = $locationlog->{switch};
    my $client_ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $r->connection->remote_ip;
    my @proxied_ip = split(',', $client_ip);
    $client_ip = $proxied_ip[0];

    my $redirect_url;
    if ( defined($req->param('dest')) ) {
        $redirect_url = $req->param('dest');
    }
    elsif ( defined($r->headers_in->{'Referer'}) ) {
        $redirect_url = $r->headers_in->{'Referer'};
    }

    %params = (
        switch_id               => $switch_id,
        client_mac              => $client_mac,
        client_ip               => $client_ip,
        redirect_url            => $redirect_url,
        synchronize_locationlog => $FALSE,
        connection_type         => $WEBAUTH_WIRED,
    );

    return \%params;
}


=item wiredeauthTechniques

Returns the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'dot1xPortReauthenticate',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::SNMP => 'handleReAssignVlanTrapForWiredMacAuth',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
}

=item deauthenticateMacRadius

Deauthenticate a wired endpoint using RADIUS CoA

=cut

sub deauthenticateMacRadius {
    my ($self, $ifIndex,$mac) = @_;

    $self->radiusDisconnect($mac);
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
