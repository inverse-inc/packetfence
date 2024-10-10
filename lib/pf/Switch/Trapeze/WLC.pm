package pf::Switch::Trapeze::WLC;

=head1 NAME

pf::Switch::Trapeze::WLC

=head1 SYNOPSIS

Module to manage Juniper (Trapeze) controllers

=cut

use strict;
use warnings;

use Log::Log4perl;
#use Net::Appliance::Session;
use POSIX;

use base ('pf::Switch::Trapeze');

use pf::config;
# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::constants;

#sub supportsRoleBasedEnforcement { return $TRUE; }
=head1 STATUS

=head1 BUGS AND LIMITATIONS

=over

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Default implementation.

=cut
sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger();

    my $radius_reply_ref = {};

    # should this node be kicked out?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if (defined($kick));

    # Inline Vs. VLAN enforcement
    my $role = "";
    if ( (!$args->{'wasInline'} || ($args->{'wasInline'} && $args->{'vlan'} != 0) ) && isenabled($self->{_VlanMap})) {
        if(defined($args->{'vlan'}) && $args->{'vlan'} ne "" && $args->{'vlan'} ne 0){
            if ( $args->{'vlan'} =~ /^[-\d]+$/ ) {
                $radius_reply_ref = {
                    'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
                    'Tunnel-Type' => $RADIUS::VLAN,
                    'Tunnel-Private-Group-ID' => $args->{'vlan'},
                };
            }
            else {
                $radius_reply_ref = {
                    'Trapeze-VLAN-Name'  => $args->{'vlan'},
                };
            }
            $logger->info("(".$self->{'_id'}.") Added VLAN $args->{'vlan'} to the returned RADIUS Access-Accept");
        }
        else {
            $logger->debug("(".$self->{'_id'}.") Received undefined VLAN. No VLAN added to RADIUS Access-Accept");
        }
    }
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

    my $status = $RADIUS::RLM_MODULE_OK;
    if (!isenabled($args->{'unfiltered'})) {
        my $filter = pf::access_filter::radius->new;
        my $rule = $filter->test('returnRadiusAccessAccept', $args);
        ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    }

    return [$status, %$radius_reply_ref];
}
=back


=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Francois Gaudreault <fgaudreault@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>

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
