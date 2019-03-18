package pf::Switch::Ruckus;

=head1 NAME

pf::Switch::Ruckus

=head1 SYNOPSIS

The pf::Switch::Ruckus module implements an object oriented interface to
manage Ruckus Wireless Controllers

=head1 STATUS

Developed and tested on ZoneDirector 1100 running firmware 9.3.0.0 build 83

=over

=item Supports

=over

=item Deauthentication with RADIUS Disconnect (RFC3576)

=back

=back

=head1 BUGS AND LIMITATIONS

=over

No Dynamic VLAN assigments using Mac Authentication.  The module support for mac-auth is disabled for now.

=back

=cut

use strict;
use warnings;

use base ('pf::Switch');

use pf::accounting qw(node_accounting_dynauth_attr);
use pf::constants;
use pf::config qw(
    $MAC
    $SSID
    $WEBAUTH_WIRELESS
);
use pf::util;

sub description { 'Ruckus Wireless Controllers' }

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $FALSE; }
sub supportsExternalPortal { return $TRUE; }
sub supportsRoleBasedEnforcement { return $TRUE; }

# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item supportsWebFormRegistration

Will be activated only if HTTP is selected as a deauth method

=cut

sub supportsWebFormRegistration {
    my ($self) = @_;
    return $self->{_deauthMethod} eq $SNMP::HTTP;
}

=item getVersion

obtain image version information from switch

=cut

sub getVersion {
    my ($self)       = @_;
    my $oid_ruckusVer = '1.3.6.1.4.1.25053.1.2.1.1.1.1.18';
    my $logger       = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_ruckusVer");

    # sysDescr sample output:
    # 9.3.0.0 build 83

    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_ruckusVer] );
    if (defined($result)) {
        return $result->{$oid_ruckusVer};
    }

    # none of the above worked
    $logger->warn("unable to fetch version information");
}

=item parseTrap

All traps ignored

=cut

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    $logger->debug("trap currently not handled.  TrapString was: $trapString");
    $trapHashRef->{'trapType'} = 'unknown';

    return $trapHashRef;
}

=item deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1x).

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

Parse external portal request using URI and it's parameters then return an hash reference with the appropriate parameters

See L<pf::web::externalportal::handle>

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;
    my $logger = $self->logger;

    # Using a hash to contain external portal parameters
    my %params = ();

    %params = (
        switch_id               => $req->param('sip'),
        client_mac              => clean_mac($req->param('client_mac')),
        client_ip               => defined($req->param('uip')) ? $req->param('uip') : undef,
        ssid                    => $req->param('ssid'),
        redirect_url            => $req->param('url'),
        synchronize_locationlog => $FALSE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}


=item getAcceptForm

Creates the form that should be given to the client device to trigger a reauthentication.

=cut

sub getAcceptForm {
    my ( $self, $mac, $destination_url, $portalSession ) = @_;
    my $logger = $self->logger;
    $logger->debug("Creating web release form");

    my $client_ip = $portalSession->param("ecwp-original-param-uip");
    my $controller_ip = $self->{_ip};

    my $html_form = qq[
        <form name="weblogin_form" data-autosubmit="1000" method="POST" action="http://$controller_ip:9997/login" style="display:none">
          <input type="text" name="ip" value="$client_ip" />
          <input type="text" name="username" value="$mac" />
          <input type="text" name="password" value="$mac"/>
          <input type="submit">
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

    return 'Ruckus-User-Groups';

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
