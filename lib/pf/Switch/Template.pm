package pf::Switch::Template;

=head1 NAME

pf::Switch::Template -

=head1 DESCRIPTION

pf::Switch::Template

=cut

use strict;
use warnings;
use base ('pf::Switch');
use pf::util::radius qw(perform_coa perform_disconnect);
use pf::Switch::constants;
use pf::constants;
use pf::util qw(isenabled);
use pf::constants::role qw($REJECT_ROLE);
use pf::access_filter::radius;
use pf::roles::custom;
use pf::mini_template;

our $DISCONNECT_TYPE_COA = 'coa';
our $DISCONNECT_TYPE_DISCONNECT = 'disconnect';
our $DISCONNECT_TYPE_BOTH = 'coa,disconnect';

our %DISCONNECT_DISPATCH = (
    $DISCONNECT_TYPE_COA => \&handleCoa,
    $DISCONNECT_TYPE_DISCONNECT => \&handleDisconnect,
    $DISCONNECT_TYPE_BOTH => \&handleCoaOrDisconnect,
);

sub makeRadiusAttributes {
    my ($self, $attrs_tmpl, $vars) = @_;
    my @vsas;
    my @attrs;
    for my $a (@{$attrs_tmpl // []}) {
        my $v = $a->{vendor};
        if ($v) {
            push @vsas, {vendor => $v, attribute => $a->{name}, value => $a->{tmpl}->process($vars) };
        } else {
            push @attrs, $a->{name}, $a->{tmpl}->process($vars);
        }
    }

    return (\@attrs, \@vsas);
}

=item handleRadiusDeny

Return RLM_MODULE_USERLOCK if the vlan id is -1

=cut

sub handleRadiusDeny {
    my ($self, $args) =@_;
    my $logger = $self->logger();

    if (( defined($args->{'vlan'}) && $args->{'vlan'} eq "-1" ) || ( defined($args->{'user_role'}) && $args->{'user_role'} eq $REJECT_ROLE )) {
        $logger->info("According to rules in fetchRoleForNode this node must be kicked out. Returning USERLOCK");
        $self->disconnectRead();
        $self->disconnectWrite();
        my ($attrs, undef) = $self->makeRadiusAttributes($self->{_template}->{reject}, $args);
        return [ $RADIUS::RLM_MODULE_USERLOCK, @$attrs ];
    }

    return undef;
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept response for the network device.

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
        my $vlanTemplate = $self->{_template}{acceptVlan};
        if ( defined $vlanTemplate &&  defined($args->{'vlan'}) && $args->{'vlan'} ne "" && $args->{'vlan'} ne 0) {
            $logger->info("(".$self->{'_id'}.") Added VLAN $args->{'vlan'} to the returned RADIUS Access-Accept");
            my ($attrs, undef) = $self->makeRadiusAttributes($vlanTemplate, $args);
            $radius_reply_ref = { @$attrs };
        } else {
            $logger->debug("(".$self->{'_id'}.") Received undefined VLAN. No VLAN added to RADIUS Access-Accept");
        }
    }

    if ( isenabled($self->{_RoleMap}) && $self->supportsRoleBasedEnforcement()) {
        $logger->debug("Network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");
        if ( defined($args->{'user_role'}) && $args->{'user_role'} ne "" ) {
            $role = $self->getRoleByName($args->{'user_role'});
        }
        my $roleTemplate = $self->{_template}{acceptRole};
        if (defined $roleTemplate && defined($role) && $role ne "" ) {
            my ($attrs, undef) = $self->makeRadiusAttributes($roleTemplate, { %$args, role => $role });
            $radius_reply_ref = {
                %$radius_reply_ref,
                @$attrs,
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

=item radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Optionally you can provide other attributes as an hashref.

Uses L<pf::util::radius> for the low-level RADIUS stuff.

=cut

# TODO consider whether we should handle retries or not?
sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger();

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS Disconnect-Request on $self->{'_id'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating");
    my $radiusDisconnect = $self->{_template}{radiusDisconnect} // '';
    if (!exists $DISCONNECT_DISPATCH{$radiusDisconnect}) {
        $logger->error(
            "Unable to perform RADIUS Disconnect-Request on $self->{'_id'}: radiusDisconnect method '$radiusDisconnect' is invalid"
        );
        return;
    }
    
    my $response;
    try {
        $response = $DISCONNECT_DISPATCH{$radiusDisconnect}->($self, $mac, $add_attributes_ref);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS Disconnect-Request: $_");
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

=head2 handleDisconnect

handleDisconnect

=cut

sub handleDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $send_disconnect_to = $self->disconnectAddress($add_attributes_ref);
    my $connection_info = {
        nas_ip => $send_disconnect_to,
        secret => $self->{'_radiusSecret'},
        LocalAddr => $self->deauth_source_ip($send_disconnect_to),
    };

    if (defined($self->{'_disconnectPort'}) && $self->{'_disconnectPort'} ne '') {
        $connection_info->{'nas_port'} = $self->{'_disconnectPort'};
    }

    my $radiusDisconnect = $self->{_template}{disconnect};
    my ($attrs, $vsa) = $self->makeRadiusAttributes($radiusDisconnect, { disconnectIp => $send_disconnect_to, mac => $mac });
    # Standard Attributes
    my $attributes_ref = { @$attrs, %$add_attributes_ref };
    return perform_disconnect($connection_info, $attributes_ref, $vsa);
}

=head2 disconnectAddress

disconnectAddress

=cut

sub disconnectAddress {
    my ($self, $add_attributes_ref) = @_;
    my $logger = $self->logger;
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # allowing client code to override where we connect with NAS-IP-Address
    if ( defined($add_attributes_ref->{'NAS-IP-Address'}) && $add_attributes_ref->{'NAS-IP-Address'} ne '' ) {
        $logger->info("'NAS-IP-Address' additionnal attribute is set. Using it '" . $add_attributes_ref->{'NAS-IP-Address'} . "' to perform deauth");
        $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'};
    }

    return $send_disconnect_to;
}

=head2 handleCoa

handleCoa

=cut

sub handleCoa {
    my ($self, $mac, $add_attributes_ref, $role) = @_;
    my $send_disconnect_to = $self->disconnectAddress($add_attributes_ref);
    my $connection_info = {
        nas_ip => $send_disconnect_to,
        secret => $self->{'_radiusSecret'},
        LocalAddr => $self->deauth_source_ip($send_disconnect_to),
    };

    if (defined($self->{'_coaPort'}) && $self->{'_coaPort'} ne '') {
        $connection_info->{'nas_port'} = $self->{'_coaPort'};
    }

    my $radiusDisconnect = $self->{_template}{coa};
    my ($attrs, $vsa) = $self->makeRadiusAttributes($radiusDisconnect, { disconnectIp => $send_disconnect_to, mac => $mac, role => $role });
    # Standard Attributes
    my $attributes_ref = { @$attrs, %$add_attributes_ref };
    return perform_coa($connection_info, $attributes_ref, $vsa);
}

=head2 handleCoaOrDisconnect

handleCoaOrDisconnect

=cut

sub handleCoaOrDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $roleResolver = pf::roles::custom->instance();
    my $role = $roleResolver->getRoleForNode($mac, $self);
    if ( $self->shouldUseCoA({role => $role}) ) {
        return $self->handleCoa($mac, $add_attributes_ref, $role);
    }

    return $self->handleDisconnect($mac, $add_attributes_ref);
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => 'deauthenticateMacDefault',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=item supporteddeauthTechniques

return Default Deauthentication Method

=cut

sub supporteddeauthTechniques {
    my ( $self ) = @_;

    my %tech = (
        'Default' => 'deauthenticateMacDefault',
    );
    return %tech;
}

=item deauthenticateMacDefault

return Default Deauthentication Default technique

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect($mac);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
