package pf::Switch::CoovaChilli;

=head1 NAME

pf::Switch::CoovaChilli

=head1 SYNOPSIS

Implement object oriented module to handle CoovaChilli network equipment

=head1 STATUS

Tested and developed on a Ubiquiti NanoStation M2 running OpenWRT CHAOS CALMER (15.05.1,r48532)
with coova-chilli 1.3.0+20141128-2

=cut


use strict;
use warnings;

use base ('pf::Switch');

use pf::config qw(
    $WIRELESS_MAC_AUTH
);
use pf::constants;
use pf::node;
use pf::util;
use pf::violation;


sub description { 'CoovaChilli' }

sub supportsExternalPortal { return $TRUE; }
sub supportsWebFormRegistration { return $TRUE }


=head1 METHODS

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
        switch_id               => $req->param('nasid'),
        client_mac              => clean_mac($req->param('mac')),
        client_ip               => $req->param('ip'),
        ssid                    => $req->param('ssid'),
        redirect_url            => $req->param('userurl'),
        status_code             => $req->param('res'),
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

    $logger->debug("Generating web release HTML form");

    my $uamip = $portalSession->param("ecwp-original-param-uamip");
    my $uamport = $portalSession->param("ecwp-original-param-uamport");
    my $html_form = qq[
        <script type="text/javascript" src="/content/ChilliLibrary.js"></script>
        <script type="text/javascript">
            chilliController.host = "$uamip";
            chilliController.port = "$uamport";
            function logon() {
                chilliController.logon("$mac", "$mac");
            }
        </script>
        <script type="text/javascript">
            window.setTimeout('logon();', 1000);
        </script>
    ];

    $logger->debug("Generated the following web release HTML form: " . $html_form);
    return $html_form;
}


=item returnRadiusAccessAccept

Redefined to force returning '-1' in the case of an unregistered / isolated endpoint and a single Access-Accept in the case of a registered endpoint.

=cut

sub returnRadiusAccessAccept {
    my ( $self, $args ) = @_;
    my $logger = $self->logger;

    my $radius_reply_ref = {};
    my $status;

    # Should this node be kicked out ?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if ( defined($kick) );

    my $node = $args->{'node_info'};

    # RADIUS filter processing
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);

    # Violation handling
    my $violation = pf::violation::violation_view_top($args->{'mac'});

    # if user is unregistered or is in violation then we reject him to show him the captive portal
    if ( $node->{status} eq $pf::node::STATUS_UNREGISTERED || defined($violation) ){
        $logger->info("[$args->{'mac'}] is unregistered. Refusing access to force the eCWP");
        $args->{user_role} = $REJECT_ROLE;
        $self->handleRadiusDeny();
    }
    else {
        ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
        return [$status, %$radius_reply_ref];
    }
}


=item deauthenticateMacDefault

Redefined to use additional arguments

- NAS-IP-Address: Force the use of configured switch IP as the NAS-IP-Address since controllerIp is configured for other purposes

- User-Name: chilli uses the 'User-Name' attribute for CoA

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("(".$self->{'_id'}.") not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate using RADIUS Disconnect-Request deauth method");
    my $args = {
        'NAS-IP-Address'    => $self->{'_switchIp'},    # Force the use of configured switch IP as the NAS-IP-Address since controllerIp is configured for other purposes
        'User-Name'         => $mac,                    # chilli uses the 'User-Name' attribute for CoA
    };

    return $self->radiusDisconnect($mac, $args);
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
