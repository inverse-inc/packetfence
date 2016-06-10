package pf::Switch::AeroHIVE::AP_firmware6;

=head1 NAME

pf::Switch::AeroHIVE::AP - Object oriented module to access AP series via Telnet/SSH

=head1 SYNOPSIS

The pf::Switch::AeroHIVE::AP module implements an object oriented interface
to access AP  Series via Telnet/SSH

=head1 STATUS

This module is currently only a placeholder, see pf::Switch::AeroHIVE

=cut

use strict;
use warnings;

use base ('pf::Switch::AeroHIVE');
use pf::util;

sub description { 'AeroHIVE AP firmware 6+' }

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    my $radius_reply_ref = {};
    my $status;
    # should this node be kicked out?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if (defined($kick));

    $logger->debug("Network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned.");

    my $role = $args->{'user_role'};
    if ( isenabled($self->{_RoleMap}) && $self->supportsRoleBasedEnforcement()) {
        $logger->debug("Network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");
        if ( defined($args->{'user_role'}) && $args->{'user_role'} ne "" ) {
            $role = $self->getRoleByName($args->{'user_role'});
        }
        if ( defined($role) && $role ne "" ) {
            $radius_reply_ref = {
                %$radius_reply_ref,
                $self->returnRoleAttributes($role),
            };
            $logger->info(
                "(".$self->{'_id'}.") Added role $role to the returned RADIUS Access-Accept"
            );
        }
        else {
            $logger->debug("(".$self->{'_id'}.") Received undefined role. No Role added to RADIUS Access-Accept");
        }
    }

    # if Roles aren't configured, return VLAN information
    if (isenabled($self->{_VlanMap})) {
        if(defined($args->{'vlan'}) && $args->{'vlan'} ne "" && $args->{'vlan'} ne 0) {
            $radius_reply_ref = {
                 %$radius_reply_ref,
                'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
                'Tunnel-Type' => $RADIUS::VLAN,
                'Tunnel-Private-Group-ID' => $args->{'vlan'},
            };

            $logger->info("Returning ACCEPT with VLAN: $args->{'vlan'}");
        }
    }
    #use Data::Dumper;
    #$logger->warn(Dumper $args);

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];

}


=item returnRoleAttributes

Return the specific role attribute of the switch.

=cut

sub returnRoleAttributes {
    my ($self, $role) = @_;
    return ($self->returnRoleAttribute() => $role);
}

=head2 returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Filter-Id';
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

