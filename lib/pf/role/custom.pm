package pf::role::custom;

=head1 NAME

pf::role - Object oriented module for VLAN isolation oriented functions

=head1 SYNOPSIS

The pf::role module contains the functions necessary for the VLAN isolation.
All the behavior contained here can be overridden in lib/pf/role/custom.pm.

=cut

# When adding a "use", remember to keep pf::role::custom up to date for easier customization.
use strict;
use warnings;

use pf::log;

use base ('pf::role');

use pf::constants;
use Scalar::Util qw(blessed);
use pf::constants::trigger qw($TRIGGER_ID_PROVISIONER $TRIGGER_TYPE_PROVISIONER);
use pf::config qw(
    %ConfigFloatingDevices
    $WIRELESS_MAC_AUTH
    %Config
    $WIRED_MAC_AUTH
    $EAP
    $VOIP
    $ALWAYS
    $MAC
    $PORT
    $SSID
);
use pf::node qw(node_attributes node_exist node_modify);
use pf::Switch::constants;
use pf::constants::role qw($VOICE_ROLE $REJECT_ROLE);
use pf::util;
use pf::config::util;
use pf::floatingdevice::custom;
use pf::constants::scan qw($POST_SCAN_VID);
use pf::authentication;
use pf::Authentication::constants;
use pf::Connection::ProfileFactory;
use pf::access_filter::vlan;
use pf::person;
use pf::lookup::person;
use pf::util::statsd qw(called);
use pf::StatsD::Timer;

our $VERSION = 1.04;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=cut


=head2 getRegisteredRole

Returns registered Role

This sub is meant to be overridden in lib/pf/role/custom.pm if the default version doesn't do the right thing for you.
It will try to match a role based on a username (if provided) or on the node MAC address and return the according
VLAN for the given switch.

Return values:

=head2 * -1 means kick-out the node (not always supported)

=head2 * 0 means node is already registered

=head2 * undef means there was an error

=head2 * anything else is either a VLAN name string or a VLAN number

=cut

sub getRegisteredRole {
    my $timer = pf::StatsD::Timer->new;
    require pf::violation;
    #$args->{'switch'} is the switch object (pf::Switch)
    #$args->{'ifIndex'} is the ifIndex of the computer connected to
    #$args->{'mac'} is the mac connected
    #$args->{'node_info'} is the node info hashref (result of pf::node's node_attributes on $args->{'mac'})
    #$args->{'connection_type'} is set to the connnection type expressed as the constant in pf::config
    #$args->{'user_name'} is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$args->{'ssid'} is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
    my ($self, $args) = @_;
    my $logger = $self->logger;

    $logger->debug(sub { use Data::Dumper; "getRegistredRole args: ".Dumper($args) });

    my ($vlan, $role, $result, $person, $source, $portal);
    my $profile = $args->{'profile'};

    if (defined($args->{'node_info'}->{'pid'})) {
        $person = pf::person::person_view_simple($args->{'node_info'}->{'pid'});
	    $logger->debug(sub { use Data::Dumper; "person: ".Dumper($person) });
        if (defined($person->{'source'}) && $person->{'source'} ne '') {
            $source = $person->{'source'};
        }
        if (defined($person->{'portal'}) && $person->{'portal'} ne '') {
            $portal = $person->{'portal'};
        }
    }
    my $provisioner = $profile->findProvisioner($args->{'mac'},$args->{'node_info'});
    if (defined($provisioner) && $provisioner->{enforce}) {
        $logger->info("Triggering provisioner check");
        pf::violation::violation_trigger( { 'mac' => $args->{'mac'}, 'tid' => $TRIGGER_ID_PROVISIONER, 'type' => $TRIGGER_TYPE_PROVISIONER } );
    }

    my $scan = $profile->findScan($args->{'mac'},$args->{'node_info'});
    if (defined($scan) && isenabled($scan->{'post_registration'})) {
        $logger->info("Triggering scan check");
        pf::violation::violation_add( $args->{'mac'}, $POST_SCAN_VID );
    }

    $logger->debug("Trying to determine VLAN from role.");

    # Vlan Filter
    $role = $self->filterVlan('RegisteredRole',$args);
    if ( $role ) {
        return ({ role => $role});
    }

    $role = _check_bypass($args);
    if( $role ) {
        return $role;
    }

    # Try MAC_AUTH, then other EAP methods and finally anything else.
    if ( $args->{'connection_type'} && ($args->{'connection_type'} & $WIRED_MAC_AUTH) == $WIRED_MAC_AUTH ) {
        $logger->info("Connection type is WIRED_MAC_AUTH. Getting role from node_info" );
        $role = $args->{'node_info'}->{'category'};
    } elsif ( $args->{'connection_type'} && ($args->{'connection_type'} & $WIRELESS_MAC_AUTH) == $WIRELESS_MAC_AUTH ) {
        $logger->info("Connection type is WIRELESS_MAC_AUTH. Trying to get rule from pid" );
    # If it's an MAC aut we try to match the pid username with authentication sources to calculate
    # the role based on the rules defined in the different authentication sources.
    # FIRST HIT MATCH
        if ( isdisabled($profile->dot1xRecomputeRoleFromPortal) ) {
            $logger->info("Role has already been computed and we don't want to recompute it. Getting role from node_info" );
            $role = $args->{'node_info'}->{'category'};
        } else {
            my @sources = $profile->getFilteredAuthenticationSources($args->{'node_info'}->{'pid'}, $args->{'realm'});
            my $stripped_user = '';
            $stripped_user = $args->{'node_info'}->{'pid'} if(defined($args->{'node_info'}->{'stripped_user_name'}));
            my $params = {
                username => $args->{'node_info'}->{'pid'},
                connection_type => connection_type_to_str($args->{'connection_type'}),
                SSID => $args->{'ssid'},
                stripped_user_name => $stripped_user,
                rule_class => 'authentication',
                radius_request => $args->{radius_request},
            };
            my $matched = pf::authentication::match2([@sources], $params);
            $logger->debug(sub { use Data::Dumper; "match2 matched: ".Dumper($matched) });
            $source = $matched->{source_id};
            my $values = $matched->{values};
            $role = $values->{$Actions::SET_ROLE};
            my $unregdate = $values->{$Actions::SET_UNREG_DATE};
            my $time_balance =  $values->{$Actions::SET_TIME_BALANCE};
            my $bandwidth_balance =  $values->{$Actions::SET_BANDWIDTH_BALANCE};
            pf::person::person_modify($args->{'user_name'},
                'source'  => $source,
                'portal'  => $profile->getName,
            );
            # Don't do a person lookup if autoreg (already did it);
            pf::lookup::person::async_lookup_person($args->{'node_info'}->{'pid'}, $source) if !($args->{'autoreg'});
            $portal = $profile->getName;
            my %info = (
                'pid' => $args->{'node_info'}->{'pid'},
            );
            if (defined $unregdate) {
                $info{unregdate} = $unregdate;
            }
            if (defined $role) {
                $info{category} = $role;
            }
            if (defined $time_balance) {
                $info{time_balance} = pf::util::normalize_time($time_balance);
            }
            if (defined $bandwidth_balance) {
                $info{bandwidth_balance} = pf::util::unpretty_bandwidth($bandwidth_balance);
            }
            if (blessed ($args->{node_info})) {
                $args->{node_info}->merge(\%info);
            }
            else {
                node_modify($args->{'mac'},%info);
            }
        }
    }
    # If a user based role has been found by matching authentication sources rules, we return it
    if ( defined($role) && $role ne '' ) {
        $logger->info("Username was defined \"$args->{'user_name'}\" - returning role '$role'");
    # Otherwise, we return the node based role matched with the node MAC address
    } else {
        $role = $args->{'node_info'}->{'category'};
        $logger->info("Username was NOT defined or unable to match a role - returning node based role '$role'");
    }
    return ({role => $role, source => $source, portal => $portal});
}




sub _check_bypass {
    my ( $args ) = @_;
    my $logger = get_logger();

    # If the role of the node is the REJECT role, then we early return as it has precedence over the bypass role and VLAN
    if($args->{node_info}->{category} eq $REJECT_ROLE) {
        $logger->debug("Not considering bypass role and VLAN since the role of the device is $REJECT_ROLE");
        return undef;
    }

    # Bypass VLAN/role is configured in node record so we return accordingly
    if ( defined( $args->{'node_info'}->{'bypass_vlan'} ) && ( $args->{'node_info'}->{'bypass_vlan'} ne '' ) ) {
        $logger->info( "A bypass VLAN is configured. Returning VLAN: " . $args->{'node_info'}->{'bypass_vlan'} );
        return ({vlan => $args->{'node_info'}->{'bypass_vlan'}});
    }
    elsif ( defined( $args->{'node_info'}->{'bypass_role'} ) && ( $args->{'node_info'}->{'bypass_role'} ne '' ) ) {
        $logger->info( "A bypass Role is configured. Returning Role: " . $args->{'node_info'}->{'bypass_role'} );
        return ({role => $args->{'node_info'}->{'bypass_role'}});
    }
    else {
        return undef;
    }
}









=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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