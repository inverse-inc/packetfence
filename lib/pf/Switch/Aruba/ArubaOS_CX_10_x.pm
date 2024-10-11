package pf::Switch::Aruba::ArubaOS_CX_10_x;

=head1 NAME

pf::Switch::Aruba::ArubaOS_CX_10_x

=head1 SYNOPSIS

Module to manage rebanded Aruba HP CX 10.x Switch

=head1 STATUS

=over

=item Supports

=over

=item MAC-Authentication

=item 802.1X

=item Radius downloadable ACL support

=item Voice over IP

=item Radius CLI Login

=back

=back

Has been reported to work on Aruba CX

=cut

use strict;
use warnings;
use Net::SNMP;

use base ('pf::Switch::HP::AOS_Switch_v16_X');

use pf::constants;
use pf::config qw(
    $MAC
    $PORT
    $WIRED_802_1X
    $WIRED_MAC_AUTH
    %ConfigRoles
);

use pf::Switch::constants;
use pf::util;
use pf::util::radius qw(perform_disconnect perform_coa);
use Try::Tiny;
use pf::locationlog;
use NetAddr::IP;

sub description { 'Aruba CX Switch 10.x' }

# CAPABILITIES
# access technology supported
# VoIP technology supported
use pf::SwitchSupports qw(
    PushACLs
    WiredMacAuth
    WiredDot1x
    RadiusVoip
    AccessListBasedEnforcement
);

# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

=over

Return radius attributes to allow write access

=cut

sub returnAuthorizeWrite {
   my ($self, $args) = @_;
   my $logger = $self->logger;
   my $radius_reply_ref = {};
   my $status;
   $radius_reply_ref->{'Service-Type'} = 'Administrative-User';
   $radius_reply_ref->{'Reply-Message'} = "Switch enable access granted by PacketFence";
   $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with write access");
   my $filter = pf::access_filter::radius->new;
   my $rule = $filter->test('returnAuthorizeWrite', $args);
   ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
   return [$status, %$radius_reply_ref];
}

=item returnAuthorizeRead

Return radius attributes to allow read access

=cut

sub returnAuthorizeRead {
   my ($self, $args) = @_;
   my $logger = $self->logger;
   my $radius_reply_ref = {};
   my $status;
   $radius_reply_ref->{'Service-Type'} = 'NAS-Prompt-User';
   $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
   $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
   my $filter = pf::access_filter::radius->new;
   my $rule = $filter->test('returnAuthorizeRead', $args);
   ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
   return [$status, %$radius_reply_ref];
}

=head2 returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overrides the default implementation to add the dynamic acls

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    $args->{'unfiltered'} = $TRUE;
    $args->{'compute_acl'} = $FALSE;
    $self->compute_action(\$args);
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if($status == $RADIUS::RLM_MODULE_USERLOCK);
    my @acls = defined($radius_reply_ref->{'Aruba-NAS-Filter-Rule'}) ? @{$radius_reply_ref->{'Aruba-NAS-Filter-Rule'}} : ();

    if ( isenabled($self->{_AccessListMap}) && $self->supportsAccessListBasedEnforcement ){
        if( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined(my $access_list = $self->getAccessListByName($args->{'user_role'}, $args->{mac})) && !($self->usePushACLs && exists $ConfigRoles{$args->{'user_role'}} )){
            if ($access_list) {
                while($access_list =~ /([^\n]+)\n?/g){
                    my ($test, $formated_acl) = $self->returnAccessListAttribute('',$1);
                    if ($test) {
                        push(@acls, $formated_acl);
                        $logger->info("(".$self->{'_id'}.") Adding access list : $formated_acl to the RADIUS reply");
                    }
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
    my $nas_port = $self->{'_disconnectPort'} || '3799';
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
        $connection_info->{nas_port} = $nas_port;
        my $locationlog = locationlog_view_open_mac($mac);
        $logger->debug("network device supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        my $username = $locationlog->{dot1x_username};
        # transforming MAC to the expected format 00112233CAFE
        my $calling_station_id = uc($mac);
        $calling_station_id =~ s/:/-/g;
        if (pf::util::valid_mac($username)) {
            $username = lc($username);
            $username =~ s/://g;
        }

        # Standard Attributes
        my $attributes_ref = {
            'User-Name' => $username,
            'NAS-IP-Address' => $send_disconnect_to,
            'Calling-Station-Id' => $calling_station_id,
            'NAS-Port' => $locationlog->{port},
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

=head2 returnInAccessListAttribute

Returns the attribute to use when pushing an input ACL using RADIUS

=cut

sub returnInAccessListAttribute {
    my ($self) = @_;
    return '';
}


=head2 returnOutAccessListAttribute

Returns the attribute to use when pushing an output ACL using RADIUS

=cut

sub returnOutAccessListAttribute {
    my ($self) = @_;
    return '';
}

=head2 returnAccessListAttribute

Returns the attribute to use when pushing an ACL using RADIUS

=cut

sub returnAccessListAttribute {
    my ($self, $acl_num, $acl) = @_;
    if ($acl =~ /^out\|(.*)/) {
        if ($self->supportsOutAcl) {
            return $TRUE, $self->returnOutAccessListAttribute.$acl_num.$1;
        } else {
            return $FALSE, '';
        }
    } elsif ($acl =~ /^in\|(.*)/) {
        return $TRUE, $self->returnInAccessListAttribute.$acl_num.$1;
    } else {
        return $TRUE, $self->returnInAccessListAttribute.$acl_num.$acl;
    }
}


=head2 getVoipVsa

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa{
    my ($self) = @_;
    my $logger = $self->logger;
    my $voiceVlan = $self->{'_voiceVlan'};
    $logger->info("Accepting phone with untagged Access-Accept on voiceVlan $voiceVlan");

    # Return the normal response except we force the voiceVlan to be sent
    return (
        'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
        'Tunnel-Type' => $RADIUS::VLAN,
        'Tunnel-Private-Group-ID' => $voiceVlan . "",
        'Aruba-Port-Auth-Mode' => 3,
        'Aruba-Device-Traffic-Class' => 1
    );

}

=item isVoIPEnabled

Is VoIP enabled for this device

=cut

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'dot1xPortReauthenticate',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'handleReAssignVlanTrapForWiredMacAuth',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
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

=head2 acl_chewer

Format ACL to match with the expected switch format.

=cut

sub acl_chewer {
    my ($self, $acl, $role) = @_;
    my $logger = $self->logger;
    my ($acl_ref , @direction) = $self->format_acl($acl);

    my $i = 0;
    my $acl_chewed;
    foreach my $acl (@{$acl_ref->{'packetfence'}->{'entries'}}) {
        #Bypass acl that contain tcp_flag, it doesnt apply correctly on the switch
        next if (defined($acl->{'tcp_flags'}));
        $acl->{'protocol'} =~ s/\(\d*\)//;
        my $dest;
        my $dest_port;
        if (defined($acl->{'destination'}->{'port'})) {
            $dest_port = $acl->{'destination'}->{'port'};
            $dest_port =~ s/\w+\s+//;
        }
        if ($acl->{'destination'}->{'ipv4_addr'} eq '0.0.0.0') {
            $dest = "any";
        } elsif($acl->{'destination'}->{'ipv4_addr'} ne '0.0.0.0') {
            if ($acl->{'destination'}->{'wildcard'} ne '0.0.0.0') {
                my $net_addr = NetAddr::IP->new($acl->{'destination'}->{'ipv4_addr'}, norm_net_mask($acl->{'destination'}->{'wildcard'}));
                my $cidr = $net_addr->cidr();
                $dest = $cidr;
            } else {
                $dest = $acl->{'destination'}->{'ipv4_addr'};
            }
        }
        my $src;
        if ($acl->{'source'}->{'ipv4_addr'} eq '0.0.0.0') {
            $src = "any";
        } elsif($acl->{'source'}->{'ipv4_addr'} ne '0.0.0.0') {
            if ($acl->{'source'}->{'wildcard'} ne '0.0.0.0') {
                my $net_addr = NetAddr::IP->new($acl->{'source'}->{'ipv4_addr'}, norm_net_mask($acl->{'source'}->{'wildcard'}));
                my $cidr = $net_addr->cidr();
                $src = $cidr;
            } else {
                $src = $acl->{'source'}->{'ipv4_addr'};
            }
        }
        my $j = $i + 1;
        if ($self->usePushACLs && (whowasi() eq "pf::Switch::getRoleAccessListByName")) {
            $acl_chewed .= ((defined($direction[$i]) && $direction[$i] ne "") ? $direction[$i]."|" : "").$j." ".$acl->{'action'}." ".$acl->{'protocol'}." ".(($self->usePushACLs) ? $src : "any")." $dest " . ( defined($acl->{'destination'}->{'port'}) ? $acl->{'destination'}->{'port'} : '' )."\n";
        } else {
            $acl_chewed .= ((defined($direction[$i]) && $direction[$i] ne "") ? $direction[$i]."|" : "").$acl->{'action'}." ".((defined($direction[$i]) && $direction[$i] ne "") ? $direction[$i] : "in")." ".$acl->{'protocol'}." from any to ".$dest." ".( defined($dest_port) ? $dest_port : '' )."\n";
        }
        $i++;
    }
    return $acl_chewed;
}

=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Aruba-User-Role';
}

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

