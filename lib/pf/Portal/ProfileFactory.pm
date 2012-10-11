package pf::Portal::ProfileFactory;

=head1 NAME

pf::Portal::ProfileFactory - Factory to construct special 
pf::Portal::Profile objects with complex initialization

=head1 SYNOPSIS

This module is meant to encapsulate the coupling between the configuration
and the actual pf::Portal::Profile objects. Reading and parsing the 
configuration containing all the necessary information needed to actually 
instantiate the objects.

=cut

use strict;
use warnings;

use Log::Log4perl;

use pf::config;
use pf::node;
use pf::Portal::Profile;

=head1 SUBROUTINES

=over

=item instantiate

Create a new pf::Portal::Profile instance based on parameters given.

=cut
# XXX incomplete
sub instantiate {
    my ( $self, $mac, $profile_type ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

#    $logger->debug("creating new portal profile of type $profile_type");
    # XXX handles only default profile for now
    # XXX add complex configuration loading and returning here, then add
    #     getters in ::Profile. Configuration should stay in pf::config
    #     and we only consume it especially since we will support config
    #     reload in there in the future
    # XXX also take the given mac and lookup the SSID on it and return proper
    #     portal object

    return pf::Portal::Profile->new(_default_profile()) if (!defined(tied(%Config)->GroupMembers("portal-profile")));

    # Fetch filter for every configured portal-profiles
    # Structure: FILTER => NAME OF PROFILE
    my %filters;
    foreach my $portalprofile ( tied(%Config)->GroupMembers("portal-profile") ) {
        my $profile = $portalprofile;
        $profile =~ s/portal-profile //;
        $filters{$Config{$portalprofile}{'filter'}} = $profile;
    }

    # Since we apply portal profiles based on the SSID, we check the last_ssid for the given MAC and try to match
    # a portal profile using the previously fetched filters. If no match, we instantiate the default portal profile
    my $node_info = node_view($mac);
    my $last_ssid = $node_info->{'last_ssid'};
    my $last_vlan = $node_info->{'last_vlan'};
    return pf::Portal::Profile->new(_default_profile()) if (!(defined($last_ssid)) || defined($last_vlan) );

    foreach my $last_info ("last_ssid","last_vlan") {
        foreach my $filter ( keys %filters ) {
            if ( $filter eq $last_ssid ) {
                $logger->info("instantiating new portal profile of type " . $filters{$filter});
                return pf::Portal::Profile->new(_custom_profile($filters{$filter}));
            }
        }
    }


    return pf::Portal::Profile->new(_default_profile());
}

sub _default_profile {
    return {
        'name'              => 'default',
        'logo'              => $Config{'general'}{'logo'},
        'auth'              => $Config{'registration'}{'auth'},
        'guest_self_reg'    => $Config{'registration'}{'guests_self_registration'},
        'guest_modes'       => $Config{'guests_self_registration'}{'modes'},
        'guest_category'    => $Config{'guests_self_registration'}{'category'},
        'template_path'     => '/',
        'billing_engine'    => $Config{'registration'}{'billing_engine'},
        'default_auth'      => $Config{'registration'}{'default_auth'},
    };
}

sub _custom_profile {
    my ($name) = @_;

    my $defaults = _default_profile();

    return {
        'name'              => $name,
        'logo'              => $Config{"portal-profile $name"}{'logo'}              || $defaults->{'logo'},
        'auth'              => $Config{"portal-profile $name"}{'auth'}              || 'guests_self_registration_only',
        'guest_self_reg'    => $Config{"portal-profile $name"}{'guest_self_reg'}    || $defaults->{'guest_self_reg'},
        'guest_modes'       => $Config{"portal-profile $name"}{'guest_modes'}       || $defaults->{'guest_modes'},
        'guest_category'    => $Config{"portal-profile $name"}{'guest_category'}    || $defaults->{'guest_category'},
        'template_path'     => $Config{"portal-profile $name"}{'template_path'}     || $defaults->{'template_path'},
        'billing_engine'    => $Config{"portal-profile $name"}{'billing_engine'}    || $defaults->{'billing_engine'},
        'default_auth'      => $Config{"portal-profile $name"}{'default_auth'}      || $defaults->{'default_auth'},
        'category'          => $Config{"portal-profile $name"}{'category'},
    };
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
