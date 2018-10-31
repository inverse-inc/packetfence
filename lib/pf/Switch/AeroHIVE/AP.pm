package pf::Switch::AeroHIVE::AP;

=head1 NAME

pf::Switch::AeroHIVE::AP

=head1 SYNOPSIS

Implement object oriented module to interact with AeroHive AP network equipment

=head1 STATUS

=head2 External Portal Enforcement

Tested on an AP330 running HiveOS 6.1r6.1779

=head1 BUGS AND LIMITATIONS

=head2 External Portal Enfocement - Redirect URL is not working

When selecting the option to redirect the user to the initially requested page, the AeroHIVE access point is not able to do the redirection properly.
Using the default success page of AeroHIVE works.

=over

=back 

=cut

use strict;
use warnings;

use pf::config qw(
    $WIRELESS_MAC_AUTH
);
use pf::constants;
use pf::locationlog;
use pf::node;
use pf::util;
use pf::violation;
use pf::constants::role qw($REJECT_ROLE);

use base ('pf::Switch::AeroHIVE');


sub description { 'AeroHIVE AP' }


sub supportsExternalPortal { return $TRUE; }
sub supportsWebFormRegistration { return $TRUE; }


=head1 METHODS

=over

=cut


=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overriding the default implementation for the external captive portal

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    my $radius_reply_ref = {};
    my $status;
    # should this node be kicked out?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if (defined($kick));

    my $node = $args->{'node_info'};

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);

    if ( $self->externalPortalEnforcement ) {
        my $violation = pf::violation::violation_view_top($args->{'mac'});
        # if user is unregistered or is in violation then we reject him to show him the captive portal
        if ( $node->{status} eq $pf::node::STATUS_UNREGISTERED || defined($violation) ){
            $logger->info("[$args->{'mac'}] is unregistered. Refusing access to force the eCWP");
            $args->{user_role} = $REJECT_ROLE;
            $self->handleRadiusDeny();
        }
        else{
            $logger->info("Returning ACCEPT");
            ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
            return [$status, %$radius_reply_ref];
        }
    }

    return $self->SUPER::returnRadiusAccessAccept($args);
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
        switch_id               => $req->param('RADIUS-NAS-IP'),
        client_mac              => clean_mac($req->param('Calling-Station-Id')),
        client_ip               => $req->param('STA-IP'),
        ssid                    => $req->param('ssid'),
        redirect_url            => defined($req->param('destination_url')),
        grant_url               => $req->param('url'),
        status_code             => '200',
        synchronize_locationlog => $TRUE,
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
        <form name="weblogin_form" data-autosubmit="1000" method="POST" action="http://1.1.1.1/reg.php">
            <input type="hidden" name="Submit2" value="Submit">
            <input type="hidden" name="autherr" value="0">
            <input type="hidden" name="username" value="$mac">
            <input type="hidden" name="password" value="$mac">
            <input type="hidden" name="ssid" value="$last_ssid">
            <input type="hidden" name="url" value="$destination_url">
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

