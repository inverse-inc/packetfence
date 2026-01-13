package pf::Switch::Arista::AristaSwitch;

=head1 NAME

pf::Switch::Arista::AristaSwitch - Object oriented module to access and configure Arista Switch

=head1 STATUS

The minimum required firmware version is 4.29.1F.

=over

=item Supports

=over

=item 802.1X with or without VoIP

=item MAC notifications with VoIP

=back

=item Untested

=over

=item RADIUS VoIP authorization (we relied on LLDP discovery instead)

=back

=back

This module extends pf::Switch.

=head1 BUGS AND LIMITATIONS

=back

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=head1 SNMP

This switch can parse SNMP traps and change a VLAN on a switch port using SNMP.

=cut

use strict;
use warnings;

use base ('pf::Switch');
use Carp;
use Net::SNMP;
use Readonly;

use pf::constants;
use pf::config qw(
    $ROLE_API_LEVEL
    $MAC
    $PORT
    $WIRED_802_1X
    $WIRED_MAC_AUTH
    %ConfigRoles
);
use pf::locationlog;
sub description { 'Arista Switch' }
sub switchDriverId { 'arista_eos' }

# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::config::util;
use pf::role::custom $ROLE_API_LEVEL;
use pf::radius::constants;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

# CAPABILITIES
# access technology supported
# special features
use pf::SwitchSupports qw(
    WiredDot1x
    WiredMacAuth
    RadiusDynamicVlanAssignment
    AccessListBasedEnforcement
    RoleBasedEnforcement
    ExternalPortal
    RadiusVoip
    Lldp
    PushACLs
);

# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

sub getMinOSVersion {
    my $self   = shift;
    my $logger = $self->logger;
    return '4.29.1F';
}


=item NasPortToIfIndex

Translate RADIUS NAS-Port into switch's ifIndex.

=cut

sub NasPortToIfIndex {
    my ($self, $NAS_port) = @_;
    my $logger = $self->logger;

    # 50017 is ifIndex 17
    if ($NAS_port =~ s/^500//) {
        return $NAS_port;
    } else {
        $logger->warn("Unknown NAS-Port format. ifIndex translation could have failed. "
            ."VLAN re-assignment and switch/port accounting will be affected.");
    }
    return $NAS_port;
}

=item getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($self) = @_;
    my $logger = $self->logger;

    return ('Arista-AVPair' => "device-traffic-class=voice");
}

=item getPhonesLLDPAtIfIndex

Return list of MACs found through LLDP on a given ifIndex.

If this proves to be generic enough, it could be promoted to L<pf::Switch>.
In that case, create a generic ifIndexToLldpLocalPort also.

=cut

sub getPhonesLLDPAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    # if can't SNMP read abort
    return if ( !$self->connectRead() );

    #Transfer ifIndex to LLDP index
    my $lldpPort = $self->ifIndexToLldpLocalPort($ifIndex);
    if (!defined($lldpPort)) {
        $logger->info("Unable to lookup LLDP port from IfIndex. LLDP VoIP detection will not work. Is LLDP enabled?");
        return;
    }

    my $oid_lldpRemPortId = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemSysCapEnabled = '1.0.8802.1.1.2.1.4.1.1.12';

    $logger->trace(
        "SNMP get_next_request for lldpRemSysCapEnabled: "
        . "$oid_lldpRemSysCapEnabled.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort"
    );
    my $result = $self->{_sessionRead}->get_table(
        -baseoid => "$oid_lldpRemSysCapEnabled.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort"
    );
    # Cap entries look like this:
    # iso.0.8802.1.1.2.1.4.1.1.12.0.10.29 = Hex-STRING: 24 00
    # We want to validate that the telephone capability bit is turned on.
    my @phones = ();
    foreach my $oid ( keys %{$result} ) {

        # grab the lldpRemIndex
        if ( $oid =~ /^$oid_lldpRemSysCapEnabled\.[0-9]+\.$lldpPort\.([0-9]+)$/ ) {

            my $lldpRemIndex = $1;

            # make sure that what is connected is a VoIP phone based on lldpRemSysCapEnabled information
            if ( $self->getBitAtPosition($result->{$oid}, $SNMP::LLDP::TELEPHONE) ) {
                # we have a phone on the port. Get the MAC
                $logger->trace(
                    "SNMP get_request for lldpRemPortId: "
                    . "$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"
                );
                my $portIdResult = $self->{_sessionRead}->get_request(
                    -varbindlist => [
                        "$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"
                    ]
                );
                next if (!defined($portIdResult));
                if ($portIdResult->{"$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"}
                        =~ /^(?:0x)?([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})(?::..)?$/i) {
                    push @phones, lc("$1:$2:$3:$4:$5:$6");
                }
            }
        }
    }
    return @phones;
}

=item getIfIndexByNasPortId

Fetch the ifindex on the switch by NAS-Port-Id radius attribute

=cut

sub getIfIndexByNasPortId {
    my ($self, $ifDesc_param) = @_;

    if ( !defined($ifDesc_param) || !$self->connectRead() ) {
        return 0;
    }

    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';
    my $ifDescHashRef;
    my $result = $self->cachedSNMPTable([-baseoid => $OID_ifDesc]);
    foreach my $key ( keys %{$result} ) {
        my $ifDesc = $result->{$key};
        if ( $ifDesc =~ /^$ifDesc_param$/i ) {
            $key =~ /^$OID_ifDesc\.(\d+)$/;
            return $1;
        }
    }
}

=head2 returnRadiusAccessAccept

Prepares the RADIUS Access-Accept response for the network device.

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
    my @av_pairs = defined($radius_reply_ref->{'Arista-AVPair'}) ? @{$radius_reply_ref->{'Arista-AVPair'}} : ();

    if ( $args->{'compute_acl'} && isenabled($self->{_AccessListMap}) && $self->supportsAccessListBasedEnforcement ){
        if( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined(my $access_list = $self->getAccessListByName($args->{'user_role'}, $args->{mac})) && !($self->usePushACLs && exists $ConfigRoles{$args->{'user_role'}} )){
            if ($access_list) {
                my $acl_num = 101;
                my @acls;
                while($access_list =~ /([^\n]+)\n?/g){
                    my $acl = $1;
                    if ($acl !~ /^((in|out)\|)?(permit|deny)/i) {
                        next;
                    }
                    my ($test, $formated_acl) = $self->returnAccessListAttribute($acl_num,$acl);
                    if ($test) {
                        push(@acls, $formated_acl);
                    } else {
                        next;
                    }
                    $acl_num ++;
                    $logger->info("(".$self->{'_id'}.") Adding access list : $formated_acl to the RADIUS reply");
                }
                $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
                $radius_reply_ref->{'NAS-Filter-Rule'} = \@acls;
            } else {
                $logger->info("(".$self->{'_id'}.") No access lists defined for this role ".$args->{'user_role'});
            }
        }
    }

    my $role = $self->getRoleByName($args->{'user_role'});
    if ( isenabled($self->{_UrlMap}) && $self->externalPortalEnforcement ) {
        if( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined($self->getUrlByName($args->{'user_role'}))){
            my $mac = $args->{'mac'};
            $args->{'session_id'} = "sid".$self->setSession($args);
            my $redirect_url = $self->getUrlByName($args->{'user_role'});
            $redirect_url .= '/' unless $redirect_url =~ m(\/$);
            $redirect_url .= $args->{'session_id'};
            #override role if a role in role map is defined
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


    $radius_reply_ref->{'Arista-AVPair'} = \@av_pairs;

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::RADIUS;
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
        my $default = $SNMP::RADIUS;
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
    $self->radiusDisconnect($mac ,{ 'Acct-Terminate-Cause' => 'Admin-Reset'});
}

=head2 returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role be returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Filter-Id';
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
            return $TRUE, $self->returnOutAccessListAttribute.$1;
        } else {
            return $FALSE, '';
        }
    } elsif ($acl =~ /^in\|(.*)/) {
        return $TRUE, $self->returnInAccessListAttribute.$1;
    } else {
        return $TRUE, $self->returnInAccessListAttribute.$acl;
    }
}

=head2 acl_chewer

Format ACL to match with the expected switch format.

=cut

sub acl_chewer {
    my ($self, $acl, $role) = @_;
    my $logger = $self->logger;
    my ($acl_ref , @direction) = $self->format_acl($acl);

    my $i = 0;
    my $acl_number = "10";
    my $acl_chewed;
    foreach my $acl (@{$acl_ref->{'packetfence'}->{'entries'}}) {
        if ($self->usePushACLs && (whowasi() eq "pf::Switch::getRoleAccessListByName")) {
            $acl->{'protocol'} =~ s/\(\d*\)//;
            my $dest;
            if ($acl->{'destination'}->{'ipv4_addr'} eq '0.0.0.0') {
                $dest = "any";
            } elsif($acl->{'destination'}->{'ipv4_addr'} ne '0.0.0.0') {
                if ($acl->{'destination'}->{'wildcard'} ne '0.0.0.0') {
                    $dest = $acl->{'destination'}->{'ipv4_addr'}." ".$acl->{'destination'}->{'wildcard'};
                } else {
                    $dest = "host ".$acl->{'destination'}->{'ipv4_addr'};
                }
            }
            my $src;
            if ($acl->{'source'}->{'ipv4_addr'} eq '0.0.0.0') {
                $src = "any";
            } elsif($acl->{'source'}->{'ipv4_addr'} ne '0.0.0.0') {
                if ($acl->{'source'}->{'wildcard'} ne '0.0.0.0') {
                    $src = $acl->{'source'}->{'ipv4_addr'}." ".$acl->{'source'}->{'wildcard'};
                } else {
                    $src = "host ".$acl->{'source'}->{'ipv4_addr'};
                }
            }

            $acl_chewed .= $acl_number." ".$acl->{'action'}." ".$acl->{'protocol'}." ".(($self->usePushACLs) ? $src : "any")." ".$dest ." ".(defined($acl->{'destination'}->{'port'}) ? $acl->{'destination'}->{'port'} : '')." ".( defined($acl->{'tcp_flags'}) ? $acl->{'tcp_flags'} : '' );
            $acl_number = $acl_number + 10;
            $acl_chewed =~ s/\s+$//;
            $acl_chewed .= "\n";
        } else {
            #Bypass acl that contain tcp_flag, it doesnt apply correctly on the switch
            next if (defined($acl->{'tcp_flags'}));
            if ($acl->{'protocol'}  =~ /\((\d+)\)/g) {
                $acl->{'protocol'} = $1;
            } else {
                $acl->{'protocol'} = 'ip';
            }
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
            $acl_chewed .= ((defined($direction[$i]) && $direction[$i] ne "") ? $direction[$i]."|" : "").$acl->{'action'}." ".((defined($direction[$i]) && $direction[$i] ne "") ? $direction[$i] : "in")." ".$acl->{'protocol'}." from any to ".$dest." ".( defined($dest_port) ? $dest_port : '' )."\n";
        $i++;
        }
    }
    return $acl_chewed;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
