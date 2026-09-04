package pfappserver::Form::Config::Connector;

=head1 NAME

pfappserver::Form::Config::Connector - Web form for Connector

=head1 DESCRIPTION

Form definition to create or update a connector

=cut

use HTML::FormHandler::Moose;
use pf::ConfigStore::Connector::DomainsConnectors;
use pfconfig::cached_hash;
use pf::util qw(valid_ip isenabled);
use pf::connector::site_network qw(interface_name $IFNAMSIZ);
use NetAddr::IP;

tie my %ConnectorConfig, "pfconfig::cached_hash" , "config::Connector";

extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
);

has_field 'id' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'description' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'networks' =>
  (
   type => 'Repeatable',
  );

has_field 'networks.contains' =>
  (
   type => 'CIDR',
  );

has_field 'secret' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'fingerbank_environment' => (
   type => 'Repeatable',
);

has_field 'fingerbank_environment.contains' => (
   type => 'EnvVar',
);

# Site networking: VLAN interfaces the connector host creates and holds an IP
# on, plus static routes. See pf::connector::site_network for the storage
# format. The VLAN interface is named "<parent>.<vlan>".
has_field 'interfaces' => (
   type => 'Repeatable',
);

has_field 'interfaces.parent' => (
   type => 'Text',
   required => 1,
   maxlength => $IFNAMSIZ - 5, # room for ".4094"
   apply => [
       {
           check => qr/^[A-Za-z0-9_-]+$/,
           message => 'Parent interface name may only contain letters, digits, "_" and "-"',
       },
   ],
);

has_field 'interfaces.vlan' => (
   type => 'PosInteger',
   required => 1,
   range_start => 1,
   range_end => 4094,
);

has_field 'interfaces.cidr' => (
   type => 'Text',
   required => 1,
   apply => [
       {
           check => \&_valid_host_cidr,
           message => 'Value must be a host IPv4 address with a prefix length (e.g. 10.10.100.1/24)',
       },
   ],
);

# DHCP scope served by pfdhcp for the VLAN (DHCP-over-HTTPS through the
# connector). The network and netmask come from the interface address.
has_field 'interfaces.dhcp' => (
   type => 'Toggle',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default => 'disabled',
);

# Captive DNS: answer every DNS query received on the interface with the
# interface address (served by the connector itself).
has_field 'interfaces.dns_server' => (
   type => 'Toggle',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default => 'disabled',
);

has_field 'interfaces.dhcp_start' => (
   type => 'IPAddress',
   accept => [''],
);

has_field 'interfaces.dhcp_end' => (
   type => 'IPAddress',
   accept => [''],
);

has_field 'interfaces.dhcp_default_lease_time' => (
   type => 'PosInteger',
   default => 300,
);

has_field 'interfaces.dhcp_max_lease_time' => (
   type => 'PosInteger',
   default => 600,
);

has_field 'interfaces.dns' => (
   type => 'IPAddresses',
);

has_field 'interfaces.gateway' => (
   type => 'IPAddress',
   accept => [''],
);

has_field 'interfaces.domain_name' => (
   type => 'Text',
   maxlength => 253,
   apply => [
       {
           check => qr/^[A-Za-z0-9.-]*$/,
           message => 'Domain name may only contain letters, digits, "." and "-"',
       },
   ],
);

has_field 'routes' => (
   type => 'Repeatable',
);

has_field 'routes.destination' => (
   type => 'CIDR',
   required => 1,
);

has_field 'routes.gateway' => (
   type => 'IPAddress',
   accept => [''],
);

has_field 'routes.interface' => (
   type => 'Text',
   maxlength => $IFNAMSIZ,
   apply => [
       {
           check => qr/^[A-Za-z0-9_.-]*$/,
           message => 'Interface name may only contain letters, digits, ".", "_" and "-"',
       },
   ],
);

sub validate_networks {
    my ($self, $field) = @_;
    my $networks = $field->value;
    my %counts;
    for my $n (@$networks) {
        $counts{$n}++;
        if ($counts{$n} == 2) {
            $field->add_error("Cannot have network '$n' defined multiple times");
        }
    }

    my $id = $self->field("id")->value;
    for my $k (grep { $_ ne $id && $_ ne 'local_connector' } keys %ConnectorConfig) {
        for my $n (@{$ConnectorConfig{$k}{networks} // []}) {
            if (exists $counts{$n}) {
                $field->add_error("network '$n' is defined in '$k'");
            }
        }
    }
}

=head2 _valid_host_cidr

A unicast IPv4 host address with a prefix length between 1 and 32, e.g.
10.10.100.1/24. The network and broadcast addresses of the subnet are
refused (except for /31 and /32 where every address is a host).

=cut

sub _valid_host_cidr {
    my ($value) = @_;
    return 0 unless defined $value;
    my ($ip, $prefix, $extra) = split(m!/!, $value, 3);
    return 0 if defined $extra;
    return 0 unless defined $prefix && $prefix =~ /^\d+$/ && $prefix >= 1 && $prefix <= 32;
    return 0 unless valid_ip($ip);
    my $addr = NetAddr::IP->new($ip, $prefix) or return 0;
    return 1 if $prefix >= 31;
    return 0 if $addr->addr eq $addr->network->addr;
    return 0 if $addr->addr eq $addr->broadcast->addr;
    return 1;
}

=head2 validate_interfaces

No duplicate VLAN interface within a connector, the resulting interface name
must fit in IFNAMSIZ, and when DHCP is enabled the scope must be consistent
with the interface address: range inside the interface's network, start
before end, interface address outside the range, gateway inside the network,
default lease not longer than the maximum.

=cut

sub validate_interfaces {
    my ($self, $field) = @_;
    my %seen;
    for my $if_field ($field->fields) {
        my $if = $if_field->value;
        next unless ref($if) eq 'HASH' && defined $if->{parent} && defined $if->{vlan};
        my $name = interface_name($if);
        if (length($name) > $IFNAMSIZ) {
            $if_field->field('parent')->add_error("Interface name '$name' is longer than $IFNAMSIZ characters");
        }
        if ($seen{$name}++) {
            $if_field->field('vlan')->add_error("VLAN interface '$name' is defined multiple times");
        }
        next unless isenabled($if->{dhcp});
        my $addr = NetAddr::IP->new($if->{cidr} // '') or next;
        my $net = $addr->network;
        my ($start, $end) = map { defined $_ && length $_ ? NetAddr::IP->new($_) : undef } @{$if}{qw(dhcp_start dhcp_end)};
        if (!$start) {
            $if_field->field('dhcp_start')->add_error("DHCP range start is required when DHCP is enabled");
        }
        if (!$end) {
            $if_field->field('dhcp_end')->add_error("DHCP range end is required when DHCP is enabled");
        }
        if ($start && $end) {
            if (!$net->contains($start)) {
                $if_field->field('dhcp_start')->add_error("DHCP range start is not inside " . $net->cidr);
            }
            if (!$net->contains($end)) {
                $if_field->field('dhcp_end')->add_error("DHCP range end is not inside " . $net->cidr);
            }
            if ($start > $end) {
                $if_field->field('dhcp_end')->add_error("DHCP range end is before the range start");
            }
            # compare addresses only: NetAddr::IP orders by address then mask
            my $host = NetAddr::IP->new($addr->addr);
            if ($host >= $start && $host <= $end) {
                $if_field->field('dhcp_start')->add_error("The interface address " . $addr->addr . " must not be inside the DHCP range");
            }
        }
        if (defined $if->{gateway} && length $if->{gateway}) {
            my $gw = NetAddr::IP->new($if->{gateway});
            if ($gw && !$net->contains($gw)) {
                $if_field->field('gateway')->add_error("Gateway is not inside " . $net->cidr);
            }
        }
        my ($lease, $max) = @{$if}{qw(dhcp_default_lease_time dhcp_max_lease_time)};
        if (defined $lease && defined $max && length $lease && length $max && $lease > $max) {
            $if_field->field('dhcp_max_lease_time')->add_error("Maximum lease time is shorter than the default lease time");
        }
    }
}

=head2 validate_routes

A route needs a gateway or an interface, may not replace the default route,
and an interface it names must exist on the connector (one of its VLAN
interfaces) or be a plain host interface name.

=cut

sub validate_routes {
    my ($self, $field) = @_;
    my %vlan_ifs = map { interface_name($_) => 1 }
      grep { ref($_) eq 'HASH' && defined $_->{parent} && defined $_->{vlan} }
      @{ $self->field('interfaces')->value // [] };
    my %seen;
    for my $route_field ($field->fields) {
        my $route = $route_field->value;
        next unless ref($route) eq 'HASH' && defined $route->{destination};
        my $gw = $route->{gateway} // '';
        my $dev = $route->{interface} // '';
        if ($gw eq '' && $dev eq '') {
            $route_field->field('gateway')->add_error("A route needs a gateway, an interface, or both");
        }
        my $dst = NetAddr::IP->new($route->{destination});
        if ($dst && $dst->masklen == 0) {
            $route_field->field('destination')->add_error("The default route cannot be managed from here");
        }
        if ($dst && $dst->addr ne $dst->network->addr) {
            $route_field->field('destination')->add_error("Destination must be a network address (e.g. 10.20.0.0/16)");
        }
        if ($seen{$route->{destination}}++) {
            $route_field->field('destination')->add_error("Route to '$route->{destination}' is defined multiple times");
        }
    }
}

=over

=back

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
