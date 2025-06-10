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
    # Check if the IP is valid if not then it's a hostname
    if (!$ip || !$ip->is_ipv4) {
        # If the IP is not valid, we assume it's a hostname and resolve it
        my ($resolved_ips, $error) = resolve_dns_with_custom_resolver($ip, $Config{pfdns_connector}{pfdns_connector_server});
        if (!$resolved_ips || !@{$resolved_ips}) {
            return undef; # No valid IPs resolved
        }
        # If we have multiple IPs, we take the first one
        $ip = NetAddr::IP->new($resolved_ips->[0]);
    }
    if (!$ip) {
        return undef;
    }
    for my $connector_id (@connectors_ordered) {
        for my $net ( @{ $ConfigConnector{$connector_id}{networks} } ) {
            $net = NetAddr::IP->new($net);
            if ( $net->contains($ip) ) {
                return $class->new($connector_id);
            }
        }
    }
    return $class->local_connector();
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
    $dns_server_str = replace_mgmt_ip($dns_server_str);
    my $dns_server_str_save = $dns_server_str; # Save the original DNS server string for error messages
    my $err;
    $dns_server_str = $ENV{'K8S_DNS_SERVER'} unless $dns_server_str;

    unless (Net::IP::ip_is_ipv4($dns_server_str)) {
        my $kube_dns = $ENV{'K8S_DNS_SERVER'};
        my ($dns_host, $dns_port) = ($dns_server_str =~ /^(.*?)(?::(\d+))?$/);
        ($dns_server_str, $err) = resolve_dns($dns_server_str_save, $kube_dns);
        $dns_server_str = $dns_server_str.":".$dns_port;
    }
    return (undef, "DNS server not configured and K8S_DNS_SERVER is not defined") unless $dns_server_str;
    return resolve_dns($fqdn, $dns_server_str) if Net::IP::ip_is_ipv4($dns_server_str);
    return (undef, "Invalid DNS server format: $dns_server_str") unless $dns_server_str =~ /^(.*?)(?::(\d+))?$/;
}

sub resolve_dns {
    my ($fqdn, $dns_server_str) = @_;
    my ($dns_host, $dns_port) = ($dns_server_str =~ /^(.*?)(?::(\d+))?$/);
    $dns_port ||= 53; # Default DNS port
    my $resolver = Net::DNS::Resolver->new(
        nameservers => [$dns_host],
        port        => $dns_port,
        recurse     => 1,
        timeout     => 5, # Timeout of 5 second
    );

    my $packet = $resolver->query($fqdn, 'A'); # A record research (IPv4)
    unless ($packet) {
        return (undef, "Error trying to resolve '$fqdn' via $dns_host: " . $resolver->errorstring);
    }

    my @ips;
    foreach my $rr ($packet->answer) {
        push @ips, $rr->address if $rr->type eq 'A';
    }

    return (\@ips, undef);
}

sub select_dns_server {
    my ($class, $dns_server_str) = @_;
    $dns_server_str = replace_mgmt_ip($dns_server_str);
    return $dns_server_str if $dns_server_str;

    # If no DNS server is provided, we use the default one
    return $ENV{'K8S_DNS_SERVER'} || '1.1.1.1:53';


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

