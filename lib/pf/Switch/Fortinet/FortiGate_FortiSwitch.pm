package pf::Switch::Fortinet::FortiGate_FortiSwitch;

=head1 NAME

pf::Switch::Fortinet::FortiGate_FortiSwitch - FortiGate with managed FortiSwitch devices

=head1 SYNOPSIS

The pf::Switch::Fortinet::FortiGate_FortiSwitch module implements an object oriented interface
for a FortiGate that manages FortiSwitch devices and also handles wireless. All RADIUS requests
come from the same FortiGate IP. This module dispatches wired requests using FortiSwitch-style
RADIUS attributes (Filter-Id + NAS-Filter-Rule ACLs) and wireless requests using FortiGate-style
attributes (Fortinet-Group-Name + eCWP).

=head1 STATUS

Tested with FortiGate managing FortiSwitch v7.x

=cut

use strict;
use warnings;
use pf::log;
use pf::util;
use pf::constants;
use pf::accounting qw(node_accounting_dynauth_attr);
use pf::dal::radacct;
use pf::error qw(is_error);
use NetAddr::IP;
use pf::config qw(
    $WIRED
    $WIRED_802_1X
    $WIRED_MAC_AUTH
    $WEBAUTH_WIRED
    %ConfigRoles
);

use base ('pf::Switch::Fortinet::FortiGate');

sub description { 'FortiGate with managed FortiSwitch' }

# Inherit everything from FortiGate and add WiredDot1x + AccessListBasedEnforcement
use pf::SwitchSupports qw(
    WiredDot1x
    AccessListBasedEnforcement
);

=head1 METHODS

=head2 returnRadiusAccessAccept

Dispatch wired requests to FortiSwitch-style logic and wireless requests to FortiGate logic.

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    if (($args->{'connection_type'} & $WIRED) == $WIRED) {
        $logger->info("Wired connection detected, using FortiSwitch RADIUS logic");
        return $self->_returnRadiusAccessAcceptWired($args);
    }

    $logger->info("Wireless/other connection detected, using FortiGate RADIUS logic");
    return $self->SUPER::returnRadiusAccessAccept($args);
}

=head2 _returnRadiusAccessAcceptWired

Handle wired RADIUS Access-Accept using FortiSwitch-style attributes:
VLAN + Filter-Id role + NAS-Filter-Rule ACLs.

Replicates the logic from FortiSwitchOS_v7_x::returnRadiusAccessAccept.

=cut

sub _returnRadiusAccessAcceptWired {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    $args->{'unfiltered'} = $TRUE;
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if($status == $RADIUS::RLM_MODULE_USERLOCK);

    # Override the role attribute: use Filter-Id instead of Fortinet-Group-Name for wired
    if ( isenabled($self->{_RoleMap}) && $self->supportsRoleBasedEnforcement()) {
        if ( defined($args->{'user_role'}) && $args->{'user_role'} ne "" ) {
            my $role = $self->getRoleByName($args->{'user_role'});
            if ( defined($role) && $role ne "" ) {
                # Remove Fortinet-Group-Name set by parent, replace with Filter-Id
                delete $radius_reply_ref->{'Fortinet-Group-Name'};
                $radius_reply_ref->{'Filter-Id'} = $role;
                $logger->info("(".$self->{'_id'}.") Set wired role Filter-Id=$role");
            }
        }
    }

    # Add NAS-Filter-Rule ACLs (FortiSwitch style)
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

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.
For wired 802.1X and MAC auth, use RADIUS disconnect with FortiSwitch-style attributes.
For wired web auth, use the default FortiGate deauth method.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacWired',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacWired',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WEBAUTH_WIRED) {
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

=head2 deauthenticateMacWired

FortiSwitch-style RADIUS Disconnect with Acct-Session-Id, User-Name, NAS-Identifier,
and Called-Station-Id. Queries radacct directly to obtain all required attributes.

=cut

sub deauthenticateMacWired {
    my ( $self, $ifIndex, $mac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    # Query radacct directly for the full set of attributes needed for FortiSwitch deauth
    my ($status, $iter) = pf::dal::radacct->search(
        -columns => [qw(username acctsessionid nasidentifier calledstationid)],
        -where => {
            acctstoptime => undef,
            callingstationid => $mac,
        },
        -limit => 1,
        -order_by => {-desc => 'acctstarttime'},
        -with_class => undef,
    );

    my $dynauth;
    if (!is_error($status)) {
        $dynauth = $iter->next;
    }

    if (!$dynauth) {
        $logger->warn("Unable to find accounting data for $mac, attempting deauth with limited attributes");
        my $basic = node_accounting_dynauth_attr($mac);
        $dynauth = $basic if $basic;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method (wired/FortiSwitch)");
    return $self->radiusDisconnect(
        $mac, {
            'Acct-Session-Id' => $dynauth->{'acctsessionid'},
            'User-Name' => $dynauth->{'username'},
            'NAS-Identifier' => $dynauth->{'nasidentifier'},
            'Called-Station-Id' => $dynauth->{'calledstationid'},
        },
    );
}

=head2 returnAccessListAttribute

Returns the attribute to use when pushing an ACL using RADIUS.
Copied from FortiSwitchOS_v7_x.

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

=head2 returnInAccessListAttribute

Returns the attribute to use when pushing an input ACL using RADIUS.

=cut

sub returnInAccessListAttribute {
    my ($self) = @_;
    return '';
}

=head2 returnOutAccessListAttribute

Returns the attribute to use when pushing an output ACL using RADIUS.

=cut

sub returnOutAccessListAttribute {
    my ($self) = @_;
    return '';
}

=head2 acl_chewer

Format ACL to match with FortiSwitch NAS-Filter-Rule format.

FortiSwitch expects: "<deny|permit> in <protocol> from <src> to <dst> [port]"

=cut

sub acl_chewer {
    my ($self, $acl, $role) = @_;
    my $logger = $self->logger;
    my ($acl_ref, @direction) = $self->format_acl($acl);

    my $acl_chewed;
    foreach my $acl_entry (@{$acl_ref->{'packetfence'}->{'entries'}}) {
        # Strip protocol code (e.g., tcp(6) -> tcp)
        my $protocol = $acl_entry->{'protocol'};
        $protocol =~ s/\(\d*\)//;

        # Process destination
        my $dest;
        if ($acl_entry->{'destination'}->{'ipv4_addr'} eq '0.0.0.0') {
            $dest = "any";
        } else {
            if ($acl_entry->{'destination'}->{'wildcard'} eq '0.0.0.0') {
                # Single host - use /32
                $dest = $acl_entry->{'destination'}->{'ipv4_addr'} . "/32";
            } else {
                # Network with wildcard mask - convert to CIDR
                my $net_addr = NetAddr::IP->new(
                    $acl_entry->{'destination'}->{'ipv4_addr'},
                    norm_net_mask($acl_entry->{'destination'}->{'wildcard'})
                );
                $dest = $net_addr->cidr();
            }
        }

        # Process source
        my $src;
        if ($acl_entry->{'source'}->{'ipv4_addr'} eq '0.0.0.0') {
            $src = "any";
        } else {
            if ($acl_entry->{'source'}->{'wildcard'} eq '0.0.0.0') {
                $src = $acl_entry->{'source'}->{'ipv4_addr'} . "/32";
            } else {
                my $net_addr = NetAddr::IP->new(
                    $acl_entry->{'source'}->{'ipv4_addr'},
                    norm_net_mask($acl_entry->{'source'}->{'wildcard'})
                );
                $src = $net_addr->cidr();
            }
        }

        # Process destination port
        my $dest_port = "";
        if (defined($acl_entry->{'destination'}->{'port'})) {
            $dest_port = $acl_entry->{'destination'}->{'port'};
            if ($dest_port =~ /range\s+(\d+)\s+(\d+)/) {
                # range 80 100 -> 80-100
                $dest_port = "$1-$2";
            } else {
                # eq 80 -> 80, gt 1024 -> extract number
                $dest_port =~ s/\w+\s+//;
            }
        }

        # Build FortiSwitch NAS-Filter-Rule format
        # Format: "<action> in <protocol> from <src> to <dst> [port]"
        my $rule = $acl_entry->{'action'} . " in " . $protocol . " from " . $src . " to " . $dest;
        $rule .= " " . $dest_port if $dest_port ne "";

        $acl_chewed .= $rule . "\n";
    }

    return $acl_chewed;
}

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
