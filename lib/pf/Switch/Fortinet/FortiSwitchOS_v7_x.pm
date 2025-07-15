package pf::Switch::Fortinet::FortiSwitchOS_v7_x;

=head1 NAME

pf::Switch::Fortinet::FortiSwitchOS_v7_x - Object oriented module to FortiSwitch using the 802.1x with the radius disconnect (CoA) on port 3799

=head1 SYNOPSIS

The pf::Switch::Fortinet::FortiSwitchOS_v7_x  module implements an object oriented interface to interact with the FortiSwitch

=head1 STATUS

802.1X tested with FortiOS X.X

=cut

=head1 BUGS AND LIMITATIONS


=cut

use strict;
use warnings;
use pf::util;
use pf::log;
use pf::constants;
use pf::accounting qw(node_accounting_dynauth_attr);
use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
    %ConfigRoles
);

use base ('pf::Switch::Fortinet');

=head1 METHODS

=cut

sub description { 'FortiSwitchOS v7.x' }

use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    AccessListBasedEnforcement
    RoleBasedEnforcement
);

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacDefault',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacDefault',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
}


=item deauthenticateMacDefault

Overrides base method to send Acct-Session-Id, NAS-Identifier and the Called-Station-Id within the RADIUS disconnect request

=cut

sub deauthenticateMacDefault {
    my ( $self, $ifIndex, $mac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    #Fetching the acct-session-id
    my $dynauth = node_accounting_dynauth_attr($mac);

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect(
        $mac, { 'Acct-Session-Id' => $dynauth->{'acctsessionid'}, 'User-Name' => $dynauth->{'username'}, 'NAS-Identifier' => $dynauth->{'nasidentifier'}, 'Called-Station-Id' => $dynauth->{'calledstationid'} },
    );
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
    my @acls = defined($radius_reply_ref->{'NAS-Filter-Rule'}) ? @{$radius_reply_ref->{'NAS-Filter-Rule'}} : ();

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

    $radius_reply_ref->{'NAS-Filter-Rule'} = \@acls;

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
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


=head2 returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role be returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Filter-Id';
}

=head2 getVersion

return a constant since there is no api for this

=cut

sub getVersion {
    my ($self) = @_;
    return 0;
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
