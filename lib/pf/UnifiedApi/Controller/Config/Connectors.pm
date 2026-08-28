package pf::UnifiedApi::Controller::Config::Connectors;

=head1 NAME

pf::UnifiedApi::Controller::Config::Connectors - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Connectors

=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::Connector';
has 'form_class' => 'pfappserver::Form::Config::Connector';
has 'primary_key' => 'connector_id';

use pf::ConfigStore::Connector;
use pfappserver::Form::Config::Connector;
use Mojo::UserAgent;
use NetAddr::IP;
use pf::config qw(
    %Config
    %ConfigConnector
    %ConfigAuthentication
    %ConfigDomains
    %ConfigFirewallSSO
    %ConfigSwitchesList
);
use pf::factory::connector;
use pf::SwitchFactory;
use pf::util qw(listify valid_ip isenabled);
use pfconfig::cached_hash;
use pf::log;

tie our %ConfigDnsConnectors, 'pfconfig::cached_hash', 'config::DnsConnectors';

sub status {
    my ($self) = @_;
    my $logger = get_logger();

    my $config_store = $self->config_store_class->new;
    my $connectors = $config_store->readAllIds;

    my $status_map = {};
    my $url = $Config{services_url}{'pfconnector-server'};
    if ($url) {
        my $ua = Mojo::UserAgent->new;
        $ua->connect_timeout(5);
        $ua->request_timeout(5);
        my $tx = $ua->get("$url/api/v1/pfconnector/connector-status");
        if (!$tx->error) {
            my $data = $tx->res->json;
            if (ref($data) eq 'HASH') {
                $status_map = $data->{connector_status} // {};
            } else {
                $logger->warn("Unexpected response from pfconnector-server connector-status: not a JSON object");
            }
        } else {
            $logger->warn("Failed to fetch connector status from pfconnector-server: " . $tx->error->{message});
        }
    } else {
        $logger->warn("Missing services_url for pfconnector-server, cannot fetch connector status");
    }

    my @items;
    foreach my $connector_id (sort @$connectors) {
        my $status;
        if (exists $status_map->{$connector_id}) {
            $status = $status_map->{$connector_id} ? 'up' : 'down';
        } else {
            $status = 'unknown';
        }
        push @items, { id => $connector_id, status => $status };
    }

    return $self->render(json => { items => \@items });
}

=head2 equipment

List the equipment (switches, authentication sources, domains, firewalls, DNS
connectors) whose configured IP addresses are routed through this connector.
An IP belongs to this connector when pf::factory::connector->for_ip resolves
to it, so overlapping networks across connectors are attributed with the same
precedence the runtime uses.

=cut

sub equipment {
    my ($self) = @_;
    my $connector_id = $self->id;

    my @connector_networks =
      grep { defined }
      map  { NetAddr::IP->new($_) } @{ $ConfigConnector{$connector_id}{networks} // [] };

    my %ip_match_cache;
    my $matches = sub {
        my ($ip) = @_;
        return 0 unless defined $ip && valid_ip($ip);
        return $ip_match_cache{$ip} //= do {
            my $connector = pf::factory::connector->for_ip($ip);
            ($connector && $connector->id eq $connector_id) ? 1 : 0;
        };
    };

    my @switches;
    for my $switch_id (sort keys %ConfigSwitchesList) {
        # Only IP or CIDR switch ids can be located; hostname ids would need a
        # DNS lookup in the request path.
        next unless $switch_id =~ m{^\d{1,3}(?:\.\d{1,3}){3}(?:/\d{1,2})?$};
        my $net = NetAddr::IP->new($switch_id) or next;
        if ($net->num <= 1) {
            next unless $matches->($net->addr);
        } else {
            # A switch range matches when it overlaps one of this connector's networks
            next unless grep { $_->contains($net) || $net->contains($_) } @connector_networks;
        }
        my $data = $pf::SwitchFactory::SwitchConfig{$switch_id} // {};
        push @switches, {
            id          => $switch_id,
            description => $data->{description} // '',
            type        => $data->{type} // '',
            ips         => [$switch_id],
        };
    }

    my @sources;
    for my $source_id (sort keys %ConfigAuthentication) {
        my $data = $ConfigAuthentication{$source_id};
        my @matched =
          grep { $matches->($_) }
          grep { defined && length }
          map  { split /\s*,\s*/ } @{ listify($data->{host} // '') };
        next unless @matched;
        push @sources, {
            id          => $source_id,
            description => $data->{description} // '',
            type        => $data->{type} // '',
            ips         => \@matched,
        };
    }

    my @domains;
    for my $domain_id (sort keys %ConfigDomains) {
        my $data = $ConfigDomains{$domain_id};
        my @matched =
          grep { $matches->($_) }
          grep { defined && length }
          ($data->{ad_server}, split(/\s*,\s*/, $data->{dns_servers} // ''));
        next unless @matched;
        push @domains, {
            id          => $domain_id,
            description => $data->{ad_fqdn} // '',
            type        => 'AD',
            ips         => \@matched,
        };
    }

    my @firewalls;
    for my $firewall_id (sort keys %ConfigFirewallSSO) {
        next unless $matches->($firewall_id);
        my $data = $ConfigFirewallSSO{$firewall_id};
        push @firewalls, {
            id          => $firewall_id,
            description => '',
            type        => $data->{type} // '',
            ips         => [$firewall_id],
        };
    }

    my @dns_connectors;
    for my $dns_id (sort keys %ConfigDnsConnectors) {
        my $data = $ConfigDnsConnectors{$dns_id};
        next unless $matches->($data->{ip});
        push @dns_connectors, {
            id          => $dns_id,
            description => join(', ', @{ listify($data->{domains} // '') }),
            type        => 'DNS',
            ips         => [$data->{ip}],
        };
    }

    return $self->render(json => {
        networks  => [ map { "$_" } @{ $ConfigConnector{$connector_id}{networks} // [] } ],
        equipment => {
            switches               => \@switches,
            authentication_sources => \@sources,
            domains                => \@domains,
            firewalls              => \@firewalls,
            dns_connectors         => \@dns_connectors,
        },
    });
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

