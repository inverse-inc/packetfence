package pf::Switch::Cambium;

=head1 NAME

pf::Switch::Cambium

=head1 SYNOPSIS

Implements a Cambium AP which supports 802.1X, MAC Authentication and Web Authentication in wireless

=head1 STATUS

Developed and tested with e410 model firmware 3.7-r9.

=head1 BUGS AND LIMITATIONS

Nothing documented at this point.

=cut

use strict;
use warnings;

use base ('pf::Switch');

use pf::config qw(
    $MAC
    $PORT
);
use pf::constants;
use pf::Switch::constants;
use pf::util;
use pf::accounting qw(node_accounting_dynauth_attr);

=head1 SUBROUTINES

=over

=cut

# Description
sub description { return "Cambium" }

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
sub supportsExternalPortal { return $TRUE; }
sub supportsWebFormRegistration { return $TRUE }
sub inlineCapabilities { return ($MAC,$PORT); }

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

    # sysDescr sample output:
    #EdgeSwitch 48-Port 750W, 1.7.0.4922887, Linux 3.6.5-f4a26ed5, 0.0.0.0000000

    if ( $sysDescr =~ m/, (\d+\.\d+-\d+),/ ) {
        return $1;
    } else {
        $logger->warn("couldn't extract exact version information, returning SNMP System Description instead");
        return $sysDescr;
    }
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

    #Fetching the acct-session-id
    my $dynauth = node_accounting_dynauth_attr($mac);

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect(
        $mac, { 'User-Name' => $dynauth->{'username'} },
    );
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
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

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
        switch_id               => $req->param('ga_srvr'),
        client_mac              => clean_mac($req->param('ga_cmac')),
        client_ip               => defined($req->param('ga_cip')) ? $req->param('ga_cip') : $client_ip,
        ssid                    => $req->param('ga_ssid'),
        synchronize_locationlog => $TRUE,
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

    my $ssid = $portalSession->param("ecwp-original-param-ga_ssid");    
    my $ap_mac = $portalSession->param("ecwp-original-param-ga_ap_mac");
    my $nas_id = $portalSession->param("ecwp-original-param-ga_nas_id");
    my $srvr = $portalSession->param("ecwp-original-param-ga_srvr");
    my $client_mac = $portalSession->param("ecwp-original-param-ga_cmac");
    my $client_ip = $portalSession->param("ecwp-original-param-ga_cip");
    my $qv = $portalSession->param("ecwp-original-param-ga_Qv");
    my $orig_url = $portalSession->param("ecwp-original-param-ga_orig_url");

    my $html_form = qq[
        <form name="weblogin_form" data-autosubmit="1000" method="POST" action="http://$srvr:880/cgi-bin/hotspot_login.cgi">
            <input type="hidden" name="Submit2" value="Submit">
            <input type="hidden" name="autherr" value="0">
            <input type="hidden" name="ga_user" value="$mac">
            <input type="hidden" name="ga_pass" value="$mac">
            <input type="hidden" name="ga_ssid" value="$ssid">
            <input type="hidden" name="ga_ap_mac" value="$ap_mac">
            <input type="hidden" name="ga_nas_id" value="$nas_id">
            <input type="hidden" name="ga_srvr" value="$srvr">
            <input type="hidden" name="ga_cmac" value="$client_mac">
            <input type="hidden" name="ga_cip" value="$client_ip">
            <input type="hidden" name="ga_Qv" value="$qv">
            <input type="hidden" name="ga_orig_url" value="$orig_url">
        </form>
        <script src="/content/autosubmit.js" type="text/javascript"></script>
    ];

    $logger->debug("Generated the following html form : ".$html_form);
    return $html_form;
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
