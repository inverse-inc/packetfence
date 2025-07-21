package pf::factory::connector;

=head1 NAME

pf::factory::connector

=cut

=head1 DESCRIPTION

pf::factory::connector

=cut

use strict;
use warnings;
use pf::connector;
use NetAddr::IP;
use pf::config qw($management_network %ConfigConnector %Config);
use NetAddr::IP;
use Net::IP;
use Net::DNS;
use pf::log;

tie my @connectors_ordered, 'pfconfig::cached_array',
  'resource::connectors_ordered';

sub factory_for { 'pf::connector' }

sub new {
    my ( $class, $name ) = @_;
    my $object;
    if ( !exists $ConfigConnector{$name} ) {
        return undef;
    }

    my $data = $ConfigConnector{$name};
    if ( !defined $data ) {
        return undef;
    }

    $data->{id} = $name;

    return pf::connector->new(%$data);
}

sub local_connector {
    my ($class) = @_;
    return $class->new("local_connector");
}
sub for_ip {
    my ( $class, $ip ) = @_;
    $ip = NetAddr::IP->new($ip);
    for my $connector_id (@connectors_ordered) {
        for my $net (@{$ConfigConnector{$connector_id}{networks}}) {
            $net = NetAddr::IP->new($net);
            if($net->contains($ip)) {
                return $class->new($connector_id);
            }
        }
    }
    return $class->local_connector();
}

sub resolve {
    my ($class, $ip) = @_;
    # Check if the IP is valid if not then it's a hostname
    if (!Net::IP::ip_is_ipv4($ip)) {
        my $fqdn = $ip;
        # If the IP is not valid, we assume it's a hostname and resolve it
        if (substr($ip, -1) ne '.') {
            $ip = $ip.".";
        }
        my ($resolved_ips, $error) = resolve_dns_with_custom_resolver($ip, $Config{pfdns_connector}{pfdns_connector_server});
        if (!@{$resolved_ips}) {
            return undef; # No valid IPs resolved
        }
        # If we have multiple IPs, we take the first one
        $ip = NetAddr::IP->new($resolved_ips->[0]);
        get_logger->warn("Resolved ".$fqdn." to ip ".$resolved_ips->[0]." through pfdns-connector");
    } else {
        $ip = NetAddr::IP->new($ip);
    }
    if (!$ip) {
        return undef;
    }
    return $ip->addr();
}

sub replace_mgmt_ip {
    my ($input_string) = @_;

    if ($input_string && $input_string =~ /%mgmtip%/) {
        # We use the management ip interface and not the vip
        my $mgmt_ip = $management_network->tag('ip');
        if (!$mgmt_ip) {
            return '100.64.0.1:5353';
        }
        $input_string =~ s/%mgmtip%/$mgmt_ip/g;
    }
    return $input_string;
}

sub resolve_dns_with_custom_resolver {
    my ($fqdn, $dns_server_str) = @_;
    $dns_server_str = select_dns_server($dns_server_str);
    my $dns_server_str_save = $dns_server_str; # Save the original DNS server string for error messages
    my $err;
    my ($dns_host, $dns_port) = ($dns_server_str =~ /^(.*?)(?::(\d+))?$/);
    my $dns_port_default = $dns_port // "53";
    unless (Net::IP::ip_is_ipv4($dns_host)) {
        my $kube_dns = $ENV{'K8S_DNS_SERVER'};
        if ($dns_host !~ /\.svc\.cluster\.local/) {
            $dns_host .= ".svc.cluster.local";
        }
        ($dns_server_str, $err) = resolve_dns($dns_host, $kube_dns);
        if ($err) {
            return (undef, "Error resolving DNS server '$dns_host': $err");
        }
    }
    return (undef, "DNS server not configured and K8S_DNS_SERVER is not defined") unless $dns_server_str;
    return resolve_dns($fqdn, $dns_server_str, $dns_port_default) if Net::IP::ip_is_ipv4($dns_server_str->[0]);
    return (undef, "Invalid DNS server format: $dns_server_str") unless $dns_server_str =~ /^(.*?)(?::(\d+))?$/;
}

sub resolve_dns {
    my ($fqdn, $dns_server_str, $dns_port_default) = @_;

    my @dns_hosts;
    my $dns_port = $dns_port_default // "53"; # Default DNS port

    # Support arrayref or scalar for dns_server_str
    if (ref($dns_server_str) eq 'ARRAY') {
        @dns_hosts = @$dns_server_str;
    } else {
        # Parse host:port if present
        my ($host, $port) = ($dns_server_str =~ /^(.*?)(?::(\d+))?$/);
        $dns_port = $port if $port;
        push @dns_hosts, $host if $host;
    }

    # Remove any empty hosts
    @dns_hosts = grep { $_ } @dns_hosts;

    my $resolver = Net::DNS::Resolver->new(
        nameservers => \@dns_hosts,
        port        => $dns_port,
        recurse     => 1,
        timeout     => 5, # Timeout of 5 seconds
    );

    my $packet = $resolver->query($fqdn, 'A'); # A record research (IPv4)
    unless ($packet) {
        return (undef, "Error trying to resolve '$fqdn' via [@dns_hosts]: " . $resolver->errorstring);
    }
    my @ips;
    foreach my $rr ($packet->answer) {
        push @ips, $rr->address if $rr->type eq 'A';
    }

    return (\@ips, undef);
}

sub select_dns_server {
    my ($dns_server_str) = @_;
    $dns_server_str = replace_mgmt_ip($dns_server_str);
    return $dns_server_str if $dns_server_str;

    # If no DNS server is provided, we use the default one
    return $ENV{'K8S_DNS_SERVER'};
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2025 Inverse inc.

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

