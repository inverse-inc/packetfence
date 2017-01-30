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

sub description { 'Ruckus SmartZone Wireless Controllers' }

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
        client_mac      => clean_mac($req->param('client_mac')),
        client_ip       => defined($req->param('uip')) ? $req->param('uip') : undef,
        ssid            => $req->param('ssid'),
        redirect_url    => $req->param('url'),
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
        <form name="weblogin_form" action="http://$controller_ip:9997/SubscriberPortal/hotspotlogin" method="POST" style="display:none">
          <input type="text" name="ip" value="$client_ip" />
          <input type="text" name="username" value="$mac" />
          <input type="text" name="password" value="$mac"/>
          <input type="submit">
        </form>

        <script language="JavaScript" type="text/javascript">
        window.setTimeout('document.weblogin_form.submit();', 1000);
        </script>
    ];

    $logger->debug("Generated the following html form : ".$html_form);
    return $html_form;
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
