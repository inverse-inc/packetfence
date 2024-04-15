package pf::Switch::Aruba::Instant;

=head1 NAME

pf::Switch::Aruba::Instant

=head1 SYNOPSIS

The pf::Switch::Aruba::Instant module implements an object oriented interface
to access and manage Aruba Instant APs.

This switch module was created to handle WebAuth requests send directly
through HTTP. There is no RADIUS MAC Authentication requests sent.

=head1 STATUS

Tested on Aruba Instant AP and the version 6.5.4.23

=cut

use strict;
use warnings;

use base ('pf::Switch::Aruba');
use pf::constants qw($TRUE);
use pf::constants::config qw($WEBAUTH_WIRELESS);
use pf::util::radius qw(perform_disconnect perform_coa);
use Try::Tiny;
use pf::util;

sub description { 'Aruba Instant' };

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger;

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }
    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);

        $logger->debug("network device supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        # transforming MAC to the expected format 00112233CAFE
        $mac = lc($mac);
        $mac =~ s/://g;

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'User-Name' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
        };
        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        if ( $self->shouldUseCoA({role => $role}) ) {

            $attributes_ref = {
                %$attributes_ref,
                'Filter-Id' => $role,
            };
            $logger->info("[$self->{'_ip'}] Returning ACCEPT with role: $role");
            $response = perform_coa($connection_info, $attributes_ref);

        }
        else {
            $response = perform_disconnect($connection_info, $attributes_ref);
        }
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ( ($response->{'Code'} eq 'Disconnect-ACK') || ($response->{'Code'} eq 'CoA-ACK') );

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=item parseExternalPortalRequest

Parse external portal request using URI and it's parameters then return an hash reference with the appropriate parameters

See L<pf::web::externalportal::handle>

synchronize_localtionlog equals $TRUE because some Aruba WebAuth
implementations redirect users directly to portal without sending a RADIUS
request first (see https://github.com/inverse-inc/packetfence/issues/6387)

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;
    my $logger = $self->logger;

    # Using a hash to contain external portal parameters
    my %params = ();

    %params = (
        switch_id               => valid_ip_fqdn($req->param('switchip')) ? $req->param('switchip') : $req->param('apmac'),
        client_mac              => clean_mac($req->param('mac')),
        client_ip               => $req->param('ip'),
        ssid                    => $req->param('essid'),
        redirect_url            => $req->param('url'),
        synchronize_locationlog => $TRUE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}

=item

=cut

=back

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
