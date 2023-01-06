package pf::Switch::Ruckus::Unleashed;

=head1 NAME

pf::Switch::Ruckus::Unleashed

=head1 SYNOPSIS

Implements methods to manage Ruckus Unleashed AP

=head1 BUGS AND LIMITATIONS

=cut

use strict;
use warnings;

use base ('pf::Switch::Ruckus::SmartZone');

use pf::constants;
use pf::util;
use pf::node;
use pf::config qw (
    $WEBAUTH_WIRELESS
);
use pf::log;

sub description { 'Ruckus Unleashed' }
use pf::SwitchSupports qw(
    WirelessMacAuth
    -WebFormRegistration
);

=over

=item supportsWebFormRegistration

Will be activated only if HTTP is selected as a deauth method

=cut

sub supportsWebFormRegistration {
    my ($self) = @_;
    return $TRUE;
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
        client_mac              => clean_mac($req->param('client_mac')),
        client_ip               => defined($req->param('uip')) ? $req->param('uip') : undef,
        ssid                    => $req->param('ssid'),
        redirect_url            => $req->param('url'),
        switch_id               => $req->param('sip'),
        switch_mac              => clean_mac($req->param('mac')),
	synchronize_locationlog => $TRUE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}

sub getAcceptForm {
    my ( $self, $mac, $destination_url, $portalSession ) = @_;
    my $logger = $self->logger;
    $logger->debug("Creating web release form");

    my $node = node_view($mac);
    my $last_ssid = $node->{last_ssid};
    $mac =~ s/:/-/g;
    my $html_form = qq[
        <form name="weblogin_form" data-autosubmit="1000" method="POST" action="https://unleashed.ruckuswireless.com:9998/login">
            <input type="hidden" name="username" value="$mac">
            <input type="hidden" name="password" value="$mac">
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

Copyright (C) 2005-2022 Inverse inc.

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
