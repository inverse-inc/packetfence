package pf::Switch::Extreme::EXOS;

=head1 NAME

pf::Switch::Extreme::EXOS - Object oriented module to parse SNMP traps 
and manage Extreme Networks' Summit X250e switches

=head1 STATUS

=cut

use strict;
use warnings;
use Net::SNMP;
use base ('pf::Switch::Extreme::Summit');

# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::log;
use pf::constants;
use pf::config qw(
    $WEBAUTH_WIRED
);
use pf::SwitchSupports qw(
    RoleBasedEnforcement
    ExternalPortal
);

sub description { "Extreme EXOS" } 

sub returnRoleAttribute { "Filter-Id" }

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

sub parseRequest {
    my ($self, $radius_request) = @_;
    my ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, $session_id, $ifDesc) = $self->SUPER::parseRequest($radius_request);
    $ifDesc = $ifDesc || $self->findIfdescUsingSNMP($port);
    return ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, $session_id, $ifDesc);
}

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;
    my $logger = $self->logger;

    # Using a hash to contain external portal parameters
    my %params = ();

    my $client_mac = clean_mac($req->param('mac'));

    my $locationlog = pf::locationlog::locationlog_view_open_mac($client_mac);
    my $switch_id = $locationlog->{switch};
    my $client_ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $r->connection->remote_ip;

    my $redirect_url;
    if ( defined($req->param('dest')) ) {
        $redirect_url = $req->param('redirect');
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
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
