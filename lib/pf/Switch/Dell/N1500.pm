package pf::Switch::Dell::N1500;


=head1 NAME

pf::Switch::Dell::N1500

=head1 SYNOPSIS

pf::Switch::Dell::N1500 module manages access to Dell N1500 Series
Tested on Firmware >= 6.6.0.17

=head1 STATUS



=cut

use strict;
use warnings;
use pf::log;

use base ('pf::Switch::Dell');
use pf::constants;
use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
    $WEBAUTH_WIRED
    %ConfigRoles
);

use Try::Tiny;

sub description { 'N1500 Series' }

# importing switch constants
use pf::Switch::constants;
use pf::util::radius qw(perform_coa perform_disconnect);
use pf::util;

# CAPABILITIES
# access technology supported
# VoIP technology supported
use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    RadiusVoip
    RadiusDynamicVlanAssignment
    Lldp
    AccessListBasedEnforcement
    DownloadableListBasedEnforcement
    RoleBasedEnforcement
    ExternalPortal
);

=head2 isVoIPEnabled

Supports VoIP if enabled.

=cut

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
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

=head2 dot1xPortReauthenticate


=cut

sub dot1xPortReauthenticate {
    my ($self, $ifIndex, $mac) = @_;

    return $self->_dot1xPortReauthenticate($ifIndex);
}

=head2 returnAuthorizeWrite

Return radius attributes to allow write access (supposed to work)

=cut

sub returnAuthorizeWrite {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{'Cisco-AVPair'} = 'shell:priv-lvl=15';
    $radius_reply_ref->{'Reply-Message'} = "Switch enable access granted by PacketFence";
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with write access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeWrite', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];

}

=head2 returnAuthorizeRead

Return radius attributes to allow read access (supposed to work)

=cut

sub returnAuthorizeRead {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{'Cisco-AVPair'} = 'shell:priv-lvl=3';
    $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeRead', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}


=head2 getPhonesLLDPAtIfIndex

Return list of MACs found through LLDP on a given ifIndex.

If this proves to be generic enough, it could be promoted to L<pf::Switch>.
In that case, create a generic ifIndexToLldpLocalPort also.

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
    my $oid_lldpRemPortId  = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemSysCapEnabled = '1.0.8802.1.1.2.1.4.1.1.12';

    if ( !$self->connectRead() ) {
        return @phones;
    }
    $logger->trace(
        "SNMP get_next_request for lldpRemSysCapEnabled: $oid_lldpRemSysCapEnabled");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $oid_lldpRemSysCapEnabled );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid =~ /^$oid_lldpRemSysCapEnabled\.([0-9]+)\.([0-9]+)\.([0-9]+)$/ ) {
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
                        && ($MACresult->{
                                "$oid_lldpRemPortId.$cache_lldpRemTimeMark.$cache_lldpRemLocalPortNum.$cache_lldpRemIndex"
                            }
                            =~ /^(?:0x)?([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})(?::..)?$/i))
                    {
                        push @phones, lc("$1:$2:$3:$4:$5:$6");
                    }
                }
            }
        }
    }
    return @phones;
}

=head2 getBitAtPosition - returns the bit at the position specified

The input must be the untranslated raw result of an snmp get_table

=cut

# TODO move out to a util package


sub getBitAtPosition {
   my ($self, $bitStream, $position) = @_;
   #Expect the hex stream
   if ($bitStream =~ /^0x/) {
       $bitStream =~ s/^0x//i;
       my $bin = join('',map { unpack("B4",pack("H",$_)) } (split //, $bitStream));
       return substr($bin, $position - 8, 1);
   } else {
       my $bin = substr(unpack('B*', $bitStream), -8);
       return substr($bin, $position, 1);
   }
}

=head2 getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($self) = @_;
    return ('Cisco-AVPair' => "device-traffic-class=voice");
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


=head2 radiusDisconnect

Send a CoA to disconnect a mac

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

    my $send_disconnect_to = $self->{'_ip'};
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);

        $logger->debug("network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        # Standard Attributes

        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };
        $response = perform_disconnect($connection_info, $attributes_ref);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request on (".$self->{'_id'}.") : $_");
        $logger->error("Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.") ...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request on (".$self->{'_id'}.")."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=head2 returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overrides the default implementation to add the dynamic acls

=cut

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

    if ( isenabled($self->{_AccessListMap}) && $self->supportsAccessListBasedEnforcement ){
        if( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined(my $access_list = $self->getAccessListByName($args->{'user_role'}, $args->{mac})) && !($self->usePushACLs && exists $ConfigRoles{$args->{'user_role'}} )){
            if ($access_list) {
                if ($self->useDownloadableACLs) {
                    my $mac = $args->{'mac'};
                    $mac =~ s/://g;
                    my @acl = split("\n", $access_list);
                    $args->{'acl'} = \@acl;
                    $args->{'acl_num'} = '101';
                    push(@av_pairs, "ACS:CiscoSecure-Defined-ACL=#ACSACL#$mac-".$self->setRadiusSession($args));
                } else {
                    my $acl_num = 101;
                    while($access_list =~ /([^\n]+)\n?/g){
                        my $acl = $1;
                        if ($acl !~ /^((in|out)\|)?(permit|deny)/i) {
                            next;
                        }
                        my ($test, $formated_acl) = $self->returnAccessListAttribute($acl_num,$acl);
                        if ($test) {
                            push(@av_pairs, $formated_acl);
                        } else {
                            next;
                        }
                        $acl_num ++;
                        $logger->info("(".$self->{'_id'}.") Adding access list : $formated_acl to the RADIUS reply");
                    }
                }
                $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
            } else {
                $logger->info("(".$self->{'_id'}.") No access lists defined for this role ". ( defined($args->{'user_role'}) ? $args->{'user_role'} : 'registration' ));
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


    $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs;

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=head2 returnAccessListAttribute

Returns the attribute to use when pushing an ACL using RADIUS

=cut

sub returnAccessListAttribute {
    my ($self, $acl_num) = @_;
    return "ip:inacl#$acl_num";
}

=head2 returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role be returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Filter-Id';
}

=head2 returnRoleAttributes

Return the specific role attribute of the switch.

=cut

sub returnRoleAttributes {
    my ($self, $role) = @_;
    return ($self->returnRoleAttribute() => $role.".in");
}

=head2 parseExternalPortalRequest

Parse external portal request using URI and it's parameters then return an hash reference with the appropriate parameters

See L<pf::web::externalportal::handle>

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;
    my $logger = $self->logger;

    # Using a hash to contain external portal parameters
    my %params = ();

    # Cisco Catalyst 2960 uses external portal session ID handling process
    my $uri = $r->uri;
    return unless ($uri =~ /.*sid(.*[^\/])/);
    my $session_id = $1;

    my $locationlog = pf::locationlog::locationlog_get_session($session_id);
    my $switch_id = $locationlog->{switch};
    my $client_mac = $locationlog->{mac};
    my $client_ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $r->connection->remote_ip;
    my @proxied_ip = split(',', $client_ip);
    $client_ip = $proxied_ip[0];

    my $redirect_url;
    if ( defined($req->param('redirect')) ) {
        $redirect_url = $req->param('redirect');
    }
    elsif ( defined($r->headers_in->{'Referer'}) ) {
        $redirect_url = $r->headers_in->{'Referer'};
    }

    %params = (
        session_id              => $session_id,
        switch_id               => $switch_id,
        client_mac              => $client_mac,
        client_ip               => $client_ip,
        redirect_url            => $redirect_url,
        synchronize_locationlog => $FALSE,
        connection_type         => $WEBAUTH_WIRED,
);

    return \%params;
}

=head2

Return Radius reply in the access-challenge

=cut

sub returnRadiusAdvanced {
    my ($self, $args, $options) = @_;
    my $logger = $self->logger;
    my $status = $RADIUS::RLM_MODULE_OK;
    my ($mac, $session_id) = split('-', $args->{'user_name'});
    my $radius_reply_ref = ();
    my @av_pairs;
    $radius_reply_ref->{'control:Proxy-To-Realm'} = 'LOCAL';
    if ($args->{'connection'}->isACLDownload) {
        my $cache = $self->radius_cache_distributed;
        my $session = $cache->get($session_id);
        $session->{'id_session'} = $session_id;
        # Need to send back a challenge since there is still acl to download
        if (exists $args->{'scope'} && $args->{'scope'} eq 'packetfence.authorize' && scalar @{$session->{'acl'}} > 1 ) {
            $status = $RADIUS::RLM_MODULE_HANDLED;
            $radius_reply_ref->{'control:Response-Packet-Type'} = 11;
            $radius_reply_ref->{'state'} = $session_id;
            for ( my $loops = 0; $loops < $self->ACLsLimit; $loops++ ) {
                last if (scalar @{$session->{'acl'}} == 1);
                my $acl = shift @{$session->{'acl'}};
                if ($acl !~ /^((in|out)\|)?(permit|deny)/i) {
                    next;
                }
                my ($test, $formated_acl) = $self->returnAccessListAttribute($session->{'acl_num'},$acl);
                if ($test) {
                    push(@av_pairs, $formated_acl);
                } else {
                    next;
                }
                $session->{'acl_num'} ++;
                $logger->info("(".$self->{'_id'}.") Adding access list : $formated_acl to the RADIUS reply");
                $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs;
            }
            $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
            $self->setRadiusSession($session);
            push(@av_pairs, "ACS:CiscoSecure-Defined-ACL=$mac-".$session_id);
            return [$status, %$radius_reply_ref];
        }
        if (scalar @{$session->{'acl'}} == 1) {
            my $acl = shift @{$session->{'acl'}};
            if ($acl =~ /^((in|out)\|)?(permit|deny)/i) {
                my ($test, $formated_acl) = $self->returnAccessListAttribute($session->{'acl_num'},$acl);
                if ($test) {
                    push(@av_pairs, $formated_acl);
                    $logger->info("(".$self->{'_id'}.") Adding access list : $formated_acl to the RADIUS reply");
                    $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
                    $self->setRadiusSession($session);
                    push(@av_pairs, "ACS:CiscoSecure-Defined-ACL=$mac-".$session_id);
                } else {
                    $logger->info("(".$self->{'_id'}.") No more access lists defined for this role ". ( defined($args->{'user_role'}) ? $args->{'user_role'} : 'registration' ));
                }
            }
        } elsif (scalar @{$session->{'acl'}} == 0) {
            $logger->info("(".$self->{'_id'}.") No more access lists defined for this role ". ( defined($args->{'user_role'}) ? $args->{'user_role'} : 'registration' ));
        } else {
            $logger->info("(".$self->{'_id'}.") No access lists defined for this role ". ( defined($args->{'user_role'}) ? $args->{'user_role'} : 'registration' ));
        }
    }
    $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs;
    return [$status, %$radius_reply_ref];
}

=item identifyConnectionType

Determine Connection Type based on radius attributes

=cut

sub identifyConnectionType {
    my ( $self, $connection, $radius_request ) = @_;
    my $logger = $self->logger;

    my @require = qw(Cisco-AVPair);
    my @found = grep {exists $radius_request->{$_}} @require;
    my $foundvsa = 0;
    my @vsa = qw(aaa:service=ip_admission aaa:event=acl-download);
    if (exists $radius_request->{'Cisco-AVPair'}) {
        if (ref($radius_request->{'Cisco-AVPair'}) eq 'ARRAY') {
            foreach my $item (@{$radius_request->{'Cisco-AVPair'}}) {
                foreach my $vsa (@vsa) {
                    if ($vsa eq $item) {
                        $foundvsa ++;
                    }
                }
            }
        }
    }
    @require = qw(NAS-Port-Type);
    @found = grep {exists $radius_request->{$_}} @require;
    if ($foundvsa) {
        $connection->isACLDownload($TRUE);
        $connection->isVPN($FALSE);
        $connection->isCLI($FALSE);
    } elsif (@require != @found) {
        $connection->isVPN($FALSE);
        $connection->isCLI($TRUE);
        $connection->isMacAuth($FALSE);
        $connection->transport("Virtual");
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
    my $acl_chewed;
    foreach my $acl (@{$acl_ref->{'packetfence'}->{'entries'}}) {
        $acl->{'protocol'} =~ s/\(\d*\)//;
        if ($acl->{'destination'}->{'ipv4_addr'} eq '0.0.0.0') {
            $acl_chewed .= ((defined($direction[$i]) && $direction[$i] ne "") ? $direction[$i] : "").$acl->{'action'}." ".$acl->{'protocol'}." any any " . ( defined($acl->{'destination'}->{'port'}) ? $acl->{'destination'}->{'port'} : '' ) ."\n";
        } else {
            $acl_chewed .= ((defined($direction[$i]) && $direction[$i] ne "") ? $direction[$i] : "").$acl->{'action'}." ".$acl->{'protocol'}." any host ".$acl->{'destination'}->{'ipv4_addr'}." " . ( defined($acl->{'destination'}->{'port'}) ? $acl->{'destination'}->{'port'} : '' ) ."\n";
        }
        $i++;
    }
    return $acl_chewed;
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
