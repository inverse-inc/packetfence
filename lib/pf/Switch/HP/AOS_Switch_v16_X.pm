package pf::Switch::HP::AOS_Switch_v16_X;

=head1 NAME

pf::Switch::HP::AOS_Switch_v16_X - Object oriented module to access SNMP enabled HP Procurve 2920 switches

=head1 SYNOPSIS

The pf::Switch::HP::AOS_Switch_v16_X module implements an object
oriented interface to access SNMP enabled HP Procurve 2920 switches using the ArubaOS-Switch
operating system version 16.x and up to configure dynamic ACL.

=head1 BUGS AND LIMITATIONS

VoIP not tested using MAC Authentication/802.1X

=head1 SNMP

This switch can parse SNMP traps and change a VLAN on a switch port using SNMP.

=cut

use strict;
use warnings;
use Net::SNMP;
use base ('pf::Switch::HP');

sub description {'AOS Switch v16.x'}

# importing switch constants
use pf::Switch::constants;
use pf::constants::role qw($VOICE_ROLE);
use pf::util;
use pf::radius::constants;
use pf::locationlog;
use pf::config qw(
    $MAC
    $PORT
    $WEBAUTH_WIRED
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);
use Try::Tiny;
use pf::util::radius qw(perform_coa perform_disconnect);
use pf::constants;

# CAPABILITIES
# access technology supported
use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    Lldp
    RadiusVoip
    RoleBasedEnforcement
    AccessListBasedEnforcement
    ExternalPortal
);

# inline capabilities
sub inlineCapabilities { return ( $MAC, $PORT ); }

=head2 getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($self) = @_;
    my $logger = $self->logger;
    my $vlanid = sprintf( "%03x\n", $self->getVlanByName($VOICE_ROLE) );
    my $hexvlan = hex( "31000" . $vlanid );
    return ( 'Egress-VLANID' => $hexvlan, );
}

=head2 getPhonesLLDPAtIfIndex

Using SNMP and LLDP we determine if there is VoIP connected on the switch port

=cut

sub getPhonesLLDPAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my @phones;
    if ( !$self->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch "
                . $self->{_ip}
                . ". getPhonesLLDPAtIfIndex will return empty list." );
        return @phones;
    }
    my $oid_lldpRemPortId           = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemChassisIdSubtype = '1.0.8802.1.1.2.1.4.1.1.12';
    if ( !$self->connectRead() ) {
        return @phones;
    }
    $logger->trace(
        "SNMP get_next_request for lldpRemSysDesc: $oid_lldpRemChassisIdSubtype"
    );
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $oid_lldpRemChassisIdSubtype );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid
            =~ /^$oid_lldpRemChassisIdSubtype\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            if ( $ifIndex eq $2 ) {
                my $cache_lldpRemTimeMark     = $1;
                my $cache_lldpRemLocalPortNum = $2;
                my $cache_lldpRemIndex        = $3;

                if ( $self->getBitAtPosition($result->{$oid}, $SNMP::LLDP::TELEPHONE) ) {
                    $logger->trace(
                        "SNMP get_request for lldpRemPortId: $oid_lldpRemPortId.$cache_lldpRemTimeMark.$cache_lldpRemLocalPortNum.$cache_lldpRemIndex"
                    );
                    my $MACresult = $self->{_sessionRead}->get_request(
                        -varbindlist => [
                            "$oid_lldpRemPortId.$cache_lldpRemTimeMark.$cache_lldpRemLocalPortNum.$cache_lldpRemIndex"
                        ]
                    );
                    if ($MACresult
                        && ($MACresult->{"$oid_lldpRemPortId.$cache_lldpRemTimeMark.$cache_lldpRemLocalPortNum.$cache_lldpRemIndex"}
                            =~ /^(?:0x)?([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})(?::..)?$/i
                        )
                        )
                    {
                        push @phones, lc("$1:$2:$3:$4:$5:$6");
                    }
                }
            }
        }
    }
    return @phones;
}

=head2 returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overrides the default implementation to add the dynamic acls

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    $args->{'unfiltered'} = $TRUE;
    $self->compute_action(\$args);
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if($status == $RADIUS::RLM_MODULE_USERLOCK);
    my @acls = defined($radius_reply_ref->{'Aruba-NAS-Filter-Rule'}) ? @{$radius_reply_ref->{'Aruba-NAS-Filter-Rule'}} : ();

    if ( isenabled($self->{_UrlMap}) ) {
        if ( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined($self->getUrlByName($args->{'user_role'}) ) ) {
            my $redirect_url = $self->getUrlByName($args->{'user_role'});
            $redirect_url .= '/' unless $redirect_url =~ m(\/$);
            $redirect_url .= "?";
            $radius_reply_ref->{'HP-Captive-Portal-URL'} = $redirect_url;
        }
    }

    if ( $args->{'compute_acl'} && isenabled($self->{_AccessListMap}) && $self->supportsAccessListBasedEnforcement ){
        if( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined(my $access_list = $self->getAccessListByName($args->{'user_role'}, $args->{mac}))) {
            my $access_list = $self->getAccessListByName($args->{'user_role'});
            if ($access_list) {
                while($access_list =~ /([^\n]+)\n?/g){
                    push(@acls, $1);
                    $logger->info("(".$self->{'_id'}.") Adding access list : $1 to the RADIUS reply");
                }
                $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
            } else {
                $logger->info("(".$self->{'_id'}.") No access lists defined for this role ".$args->{'user_role'});
            }
        }
    }

    $radius_reply_ref->{'Aruba-NAS-Filter-Rule'} = \@acls;

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
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
    my $locationlog = locationlog_view_open_mac(clean_mac($req->param('mac')));
    %params = (
        switch_id               => $locationlog->{switch},
        client_mac              => clean_mac($req->param('mac')),
        client_ip               => $req->param('ip'),
        redirect_url            => $req->param('url'),
        synchronize_locationlog => $FALSE,
        connection_type         => $WEBAUTH_WIRED,
    );

    return \%params;
}

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

    sub wiredeauthTechniques {
    my ( $self, $method, $connection_type ) = @_;
    my $logger = $self->logger;
    if ( $connection_type == $WIRED_802_1X ) {
        my $default = $SNMP::SNMP;
        my %tech    = (
            $SNMP::SNMP   => 'dot1xPortReauthenticate',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if ( !defined($method) || !defined( $tech{$method} ) ) {
            $method = $default;
        }
        return $method, $tech{$method};
    }
    if ( $connection_type == $WIRED_MAC_AUTH ) {
        my $default = $SNMP::SNMP;
        my %tech    = (
            $SNMP::SNMP   => 'handleReAssignVlanTrapForWiredMacAuth',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if ( !defined($method) || !defined( $tech{$method} ) ) {
            $method = $default;
        }
        return $method, $tech{$method};
    }
}

=head2 radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Optionally you can provide other attributes as an hashref.

Uses L<pf::util::radius> for the low-level RADIUS stuff.

=cut

# TODO consider whether we should handle retries or not?

sub radiusDisconnect {
    my ( $self, $mac, $add_attributes_ref ) = @_;
    my $logger = $self->logger;

    # initialize
    $add_attributes_ref = {} if ( !defined($add_attributes_ref) );

    if ( !defined( $self->{'_radiusSecret'} ) ) {
        $logger->warn(
"[$self->{'_ip'}] Unable to perform RADIUS CoA-Request: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("[$self->{'_ip'}] Deauthenticating $mac");

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};

    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
      if ( defined( $add_attributes_ref->{'NAS-IP-Address'} ) );

    my $response;
    try {
        my $locationlog = locationlog_view_open_mac($mac);
        my $connection_info =
          $self->radius_deauth_connection_info($send_disconnect_to);

        $logger->debug(
"[$self->{'_ip'}] Network device supports roles. Evaluating role to be returned."
        );
        my $roleResolver = pf::roles::custom->instance();
        my $role         = $roleResolver->getRoleForNode( $mac, $self );

        # transforming MAC to the expected format 00-11-22-33-ca-fe
        my $mac      = lc($mac);
        my $username = $locationlog->{dot1x_username};
        $mac =~ s/:/-/g;
        my $time = time;

        # Standard Attributes
        my $vsa;
        my $attributes_ref = {
            'User-Name'          => $username,
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address'     => $send_disconnect_to,
            'NAS-Port-Id'        => $locationlog->{port},

        };

   # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        if ( $self->shouldUseCoA( { role => $role } ) ) {

            $attributes_ref = { %$attributes_ref, 'Filter-Id' => $role, };
            $logger->info("[$self->{'_ip'}] Returning ACCEPT with Role: $role");
            $response = perform_coa( $connection_info, $attributes_ref, $vsa );

        } else {
            $vsa = [
                {
                    'vendor'    => 'HP',
                    'attribute' => 'HP-Port-Bounce-Host',
                    'value'     => '12'
                }
            ];
            $response = perform_coa( $connection_info, $attributes_ref, $vsa );
        }
    } catch {
        chomp;
        $logger->warn(
            "[$self->{'_ip'}] Unable to perform RADIUS CoA-Request: $_");
        $logger->error(
"[$self->{'_ip'}] Wrong RADIUS secret or unreachable network device..."
        ) if ( $_ =~ /^Timeout/ );
    };
    return if ( !defined($response) );

    return $TRUE
      if ( ( $response->{'Code'} eq 'Disconnect-ACK' )
        || ( $response->{'Code'} eq 'CoA-ACK' ) );

    $logger->warn(
        "[$self->{'_ip'}] Unable to perform RADIUS Disconnect-Request."
          . (
            defined( $response->{'Code'} ) ? " $response->{'Code'}"
            : 'no RADIUS code'
          )
          . ' received'
          . (
            defined( $response->{'Error-Cause'} )
            ? " with Error-Cause: $response->{'Error-Cause'}."
            : ''
          )
    );
    return;
}

=head2 deauthenticateMacRadius

Method to deauth a wired node with CoA.

=cut

sub deauthenticateMacRadius {
    my ($self, $ifIndex,$mac) = @_;
    my $logger = $self->logger;


    # perform CoA
    $self->radiusDisconnect($mac);
}


=head2 _dot1xPortReauthenticate

Actual implementation.

Allows callers to refer to this implementation even though someone along the way override the above call.

=cut

sub dot1xPortReauthenticate {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    return;
}


=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'HP-User-Role';
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
