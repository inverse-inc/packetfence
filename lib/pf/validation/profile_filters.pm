package pf::validation::profile_filters;

=head1 NAME

pf::validation::profile_filters - Validate the profile filters

=cut

=head1 DESCRIPTION

pf::validation::profile_filters

Validate the profile filters

=cut

use strict;
use warnings;
use pf::constants qw($TRUE $FALSE);
use pf::config qw(%connection_type);
use pf::constants::eap_type qw(%RADIUS_EAP_TYPE_2_VALUES);
use pf::SwitchFactory;
use pf::nodecategory qw(nodecategory_lookup);
use NetAddr::IP;
use Time::Period qw(inPeriod);
use pf::condition_parser qw(parse_condition_string);
use pf::dal::tenant;
use pf::error;
use Moo;

our $PROFILE_FILTER_REGEX = qr/^(([^:]|::)+?):(.*)$/;
our %ALLOWED_TYPES = (
    'network' => 1,
    'node_role' => 1,
    'connection_type' => 1,
    'port' => 1,
    'realm' => 1,
    'ssid' => 1,
    'switch' => 1,
    'switch_group' => 1,
    'switch_mac' => 1,
    'switch_port' => 1,
    'uri' => 1,
    'vlan' => 1,
    'connection_sub_type' => 1,
    'time' => 1,
    'tenant' => 1,
    'advanced' => 1,
    'fqdn' => 1,
);

our %TYPE_VALIDATOR = (
    'network' => \&validate_network,
    'connection_type' => \&validate_connection_type,
    'connection_sub_type' => \&validate_connection_sub_type,
    'switch'    => \&validate_switch,
    'switch_port' => \&validate_switch_port,
    'node_role' => \&validate_node_role,
    'time' => \&validate_time,
    'tenant' => \&validate_tenant,
    'advanced' => \&validate_advanced,
);

=head2 validate

Valid the profile filter

=cut

sub validate {
    my ($self, $filter) = @_;
    unless ($filter =~ $PROFILE_FILTER_REGEX ) {
        return ($FALSE, "Filter '$filter' is invalid please update to newer format 'type:data'");
    }
    my ($type, $data) = ($1, $3);
    unless (exists $ALLOWED_TYPES{$type} && $ALLOWED_TYPES{$type} ) {
        return ($FALSE, "Filter '$filter' has an invalid type '$type'");
    }
    unless (length($data)) {
        return ($FALSE, "Filter '$filter' has no data defined");
    }
    if (exists $TYPE_VALIDATOR{$type} ) {
        return ($TYPE_VALIDATOR{$type}->($self, $type, $data) );
    }
    return ($TRUE, undef);
}

=head2 validate_network

Validate the network value of a profile filter

=cut

sub validate_network {
    my ($self, $type, $ip) = @_;
    my $ip_addr = eval { NetAddr::IP->new($ip) };
    unless (defined $ip_addr) {
        return ($FALSE, "'$ip' is an invalid $type spec");
    }
    return ($TRUE, undef);
}

=head2 validate_connection_type

Validate the connection type value of a profile filter

=cut

sub validate_connection_type {
    my ($self, $type, $value) = @_;
    unless (exists $connection_type{$value}) {
        return ($FALSE, "'$value' is an invalid $type");
    }
    return ($TRUE, undef);
}

=head2 validate_connection_sub_type

Validate the connection sub type value of a profile filter

=cut

sub validate_connection_sub_type {
    my ($self, $type, $value) = @_;
    unless (exists $RADIUS_EAP_TYPE_2_VALUES{$value}) {
        return ($FALSE, "'$value' is an invalid $type");
    }
    return ($TRUE, undef);
}

=head2 validate_switch

Validate the switch value of a profile filter

=cut

sub validate_switch {
    my ($self, $type, $value) = @_;
    if (!exists $pf::SwitchFactory::SwitchConfig{$value} || $value eq 'default' || $value =~ /^group / ) {
        return ($FALSE, "'$value' is an invalid switch id for filter type $type");
    }
    return ($TRUE, undef);
}


=head2 validate_switch_port

Validate the switch port value of a profile filter

=cut

sub validate_switch_port {
    my ($self, $type, $value) = @_;
    my ($switch, $port) = split(/-/, $value);
    if (!defined $port || length($port) == 0) {
        return ($FALSE, "'$value' is an invalid $type spec");
    }
    return $self->validate_switch($type, $switch);
}

=head2 validate_node_role

Validate the node role value of a profile filter

=cut

sub validate_node_role {
    my ($self, $type, $value) = @_;
    my $role_id = nodecategory_lookup($value);
    if (!defined $role_id) {
        return ($FALSE, "'$value' is an invalid $type");
    }
    return ($TRUE, undef);
}


=head2 validate_node_role

Validate the time value of a profile filter

=cut

sub validate_time {
    my ($self, $type, $value) = @_;
    if (inPeriod(1,$value) == -1 ) {
        return ($FALSE, "'$value' is an invalid $type spec");
    }
    return ($TRUE, undef);
}

=head2 validate_tenant

Validate the node role value of a profile filter

=cut

sub validate_tenant {
    my ($self, $type, $value) = @_;
    if (pf::dal::tenant->exists({id => $value}) == $STATUS::NOT_FOUND) {
        return ($FALSE, "'$value' is an invalid $type");
    }
    return ($TRUE, undef);
}


=head2 validate_advanced

=cut

sub validate_advanced {
    my ($self, $type, $value) = @_;
    my ($array, $msg) = parse_condition_string($value);
    unless (defined $array) {
        return ($FALSE, $msg);
    }
    return ($TRUE, undef);
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

