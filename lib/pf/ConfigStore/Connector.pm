package pf::ConfigStore::Connector;
=head1 NAME

pf::ConfigStore::Connector add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::Connector

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($connectors_config_file);
use pf::connector::site_network qw(expand_site_network flatten_site_network);
use pf::connector::dns qw(expand_dns_servers flatten_dns_servers $TUNNEL_PORT_MIN $TUNNEL_PORT_MAX);
use pfconfig::cached_hash;
extends 'pf::ConfigStore';

sub configFile { $connectors_config_file };

sub pfconfigNamespace { 'config::Connector' }

=head2 cleanupAfterRead

Expand the site networking line lists (interfaces, routes) into structured
lists. See pf::connector::site_network for the formats.

=cut

sub cleanupAfterRead {
    my ($self, $id, $item) = @_;
    expand_site_network($item);
    expand_dns_servers($item);
}

=head2 cleanupBeforeCommit

Flatten the structured site networking lists back into one line per entry.

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $item) = @_;
    flatten_site_network($item);
    $self->allocate_dns_tunnel_ports($id, $item);
    flatten_dns_servers($item);
}

=head2 allocate_dns_tunnel_ports

Give every DNS server of the connector that has no tunnel port the lowest
free one in the 30000-30999 range, skipping the ports used by the other
connectors' DNS servers and by RADIUS sources reached through a connector.

=cut

sub allocate_dns_tunnel_ports {
    my ($self, $id, $item) = @_;
    return unless ref($item->{dns_servers}) eq 'ARRAY';
    my @servers = grep { ref($_) eq 'HASH' } @{ $item->{dns_servers} };
    return unless grep { !defined $_->{tunnel_port} || !length $_->{tunnel_port} } @servers;

    my %used;
    for my $other_id (@{ $self->readAllIds }) {
        next if $other_id eq $id;
        my $other = $self->read($other_id, 'id') or next;
        for my $s (@{ $other->{dns_servers} // [] }) {
            $used{ $s->{tunnel_port} } = 1 if ref($s) eq 'HASH' && defined $s->{tunnel_port} && length $s->{tunnel_port};
        }
    }
    tie my %auth, 'pfconfig::cached_hash', 'config::Authentication';
    for my $source (values %auth) {
        my $p = ref($source) eq 'HASH' ? $source->{pfconnector_port} : undef;
        $used{$p} = 1 if defined $p && length $p;
    }
    for my $s (@servers) {
        $used{ $s->{tunnel_port} } = 1 if defined $s->{tunnel_port} && length $s->{tunnel_port};
    }
    for my $s (@servers) {
        next if defined $s->{tunnel_port} && length $s->{tunnel_port};
        my $port = $TUNNEL_PORT_MIN;
        $port++ while $used{$port} && $port <= $TUNNEL_PORT_MAX;
        last if $port > $TUNNEL_PORT_MAX;
        $s->{tunnel_port} = $port;
        $used{$port} = 1;
    }
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

