package pfconfig::namespaces::config::DnsConnectors;

=head1 NAME

pfconfig::namespaces::config::DnsConnectors

=head1 DESCRIPTION

The DNS servers behind the connectors, one entry per server, derived from the
C<dns_servers> lists of connectors.conf (see pf::connector::dns). Kept under
its historical name for its consumers (pfdns-connector's
resource::connectors_config, resource::pfconnector_static_connections, the
DNS lookup test): entries carry C<ip>, C<port>, C<pfconnector_port> (the
tunnel port), C<domains> (comma separated) and C<connector>, and are keyed
"<connector>:<ip>:<port>". dns_connectors.conf is no longer read.

=cut

use strict;
use warnings;
use pfconfig::namespaces::resource;
use pf::connector::dns qw(dns_server_id);
use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;
    $self->{connectors} = $self->{cache}->get_cache('config::Connector');
    $self->{child_resources} = [
        'resource::connectors_config',
        'resource::pfconnector_static_connections'
    ];
}

sub build {
    my ($self) = @_;
    my %entries;
    for my $connector_id (sort keys %{ $self->{connectors} // {} }) {
        my $connector = $self->{connectors}{$connector_id};
        for my $s (@{ $connector->{dns_servers} // [] }) {
            next unless ref($s) eq 'HASH' && defined $s->{ip} && length $s->{ip};
            $entries{ dns_server_id($connector_id, $s) } = {
                ip               => $s->{ip},
                port             => $s->{port},
                pfconnector_port => $s->{tunnel_port},
                domains          => join(',', @{ $s->{domains} // [] }),
                connector        => $connector_id,
            };
        }
    }
    return \%entries;
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
