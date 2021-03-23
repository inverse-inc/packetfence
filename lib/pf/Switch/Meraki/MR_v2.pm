package pf::Switch::Meraki::MR_v2;

=head1 NAME

pf::Switch::Meraki::MR_v2

=head1 SYNOPSIS

Implement object oriented module to interact with Meraki MR (v2) network equipment

=head1 STATUS

Developed and tested on a MR12 access point

=cut

use strict;
use warnings;

use base ('pf::Switch::Cisco::WLC');

use Net::SNMP;
use Try::Tiny;
use pf::constants;
use pf::util;
use pf::node;
use pf::util::radius qw(perform_coa);

sub description { 'Meraki cloud controller V2' }

=head2 getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->info("we don't know how to determine the version through SNMP !");
    return '1';
}

=head2 returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    return 'Airespace-ACL-Name';
}

=head2 radiusDisconnect

Tailored made disconnect message for Meraki APs

=cut

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger;

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating");

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # On which port we have to send the CoA-Request ?
    my $nas_port = $self->{'_disconnectPort'} || '3799';
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
            nas_port => $nas_port,
        };

        my $node_info = node_view($mac);
        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        # Standard Attributes

        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        my $vsa = [
            {
            vendor => "Cisco",
            attribute => "Cisco-AVPair",
            value => "audit-session-id=$node_info->{'sessionid'}",
            },
            {
            vendor => "Cisco",
            attribute => "Cisco-AVPair",
            value => "subscriber:command=reauthenticate",
            },
            {
            vendor => "Cisco",
            attribute => "Cisco-AVPair",
            value => "subscriber:reauthenticate-type=last",
            }
        ];
        # This attribute is unsupported on the Meraki so we make sure we don't send it
        delete $attributes_ref->{'Service-Type'};
        $response = perform_coa($connection_info, $attributes_ref, $vsa);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): $_");
        $logger->error("Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.")...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ( ($response->{'Code'} eq 'Disconnect-ACK') || ($response->{'Code'} eq 'CoA-ACK') );

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request on (".$self->{'_id'}.")."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=head2 parseRequest

Redefinition of pf::Switch::parseRequest due to specific attribute being used for webauth

=cut

sub parseRequest {
    my ( $self, $radius_request ) = @_;
    my $client_mac      = ref($radius_request->{'Calling-Station-Id'}) eq 'ARRAY'
                           ? clean_mac($radius_request->{'Calling-Station-Id'}[0])
                           : clean_mac($radius_request->{'Calling-Station-Id'});
    my $user_name       = $self->parseRequestUsername($radius_request);
    my $nas_port_type   = $radius_request->{'NAS-Port-Type'};
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );
    my $session_id = $self->getCiscoAvPairAttribute($radius_request, "audit-session-id");

    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, $session_id, $nas_port_id);
}

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    $args->{'unfiltered'} = $TRUE;
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if($status == $RADIUS::RLM_MODULE_USERLOCK);

    my @av_pairs = defined($radius_reply_ref->{'Cisco-AVPair'}) ? @{$radius_reply_ref->{'Cisco-AVPair'}} : ();

    my $role = $self->getRoleByName($args->{'user_role'});
    if ( isenabled($self->{_UrlMap}) && $self->externalPortalEnforcement ) {
        if ( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined($self->getUrlByName($args->{'user_role'}) ) ) {
            $args->{'session_id'} = "sid".$self->setSession($args);
            my $redirect_url = $self->getUrlByName($args->{'user_role'});
            $redirect_url .= '/' unless $redirect_url =~ m(\/$);
            $redirect_url .= $args->{'session_id'};
            # Cisco and Meraki started adding "&redirect_url=http://example.com" unconditionnaly to the redirect URL.
            # This means that since we don't have any query parameters that generated paths like "/Cisco::WLC/sid123456&redirect_url=http://example.com" which extracts the SID as sid123456&redirect_url=http://example.com
            # We add empty query parameters to our path as a workaround
            $redirect_url .= "?";
            #override role if a role in role map is define
            if (isenabled($self->{_RoleMap}) && $self->supportsRoleBasedEnforcement()) {
                my $role_map = $self->getRoleByName($args->{'user_role'});
                $role = $role_map if (defined($role_map));
                # remove the role if any as we push the redirection ACL along with it's role
                delete $radius_reply_ref->{$self->returnRoleAttribute()};
            }
            $logger->info("Adding web authentication redirection to reply using role: '$role' and URL: '$redirect_url'");
            push @av_pairs, "url-redirect-acl=$role";
            push @av_pairs, "url-redirect=".$redirect_url;
        }
    }
    if ($args->{profile}->dpskEnabled()) {
        if (defined($args->{owner}->{psk})) {
            $radius_reply_ref{ 'Tunnel-Password'} = $args->{owner}->{psk};
        } else {
            $radius_reply_ref{ 'Tunnel-Password'} = $args->{profile}->{_default_psk_key};
        }
        #Remove av pairs coming from WLC
        @av_pairs = grep ! /psk=/, @av_pairs;
        @av_pairs = grep ! /psk-mode=ascii/, @av_pairs;
    }
    $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs;
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
