package pfconfig::namespaces::config::DomainsConnectors;

=head1 NAME

pfconfig::namespaces::config::DomainsConnectors

=head1 DESCRIPTION

Domain name -> connector, derived from the domains listed under the
connectors' DNS servers (connectors.conf C<dns_servers>, see
pf::connector::dns). Kept under its historical name for its consumer
(resource::connectors_config). domains_connectors.conf is no longer read.

=cut

use strict;
use warnings;
use pfconfig::namespaces::resource;
use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;
    $self->{connectors} = $self->{cache}->get_cache('config::Connector');
    $self->{child_resources} = [
        'resource::connectors_config'
    ];
}

sub build {
    my ($self) = @_;
    my %domains;
    for my $connector_id (sort keys %{ $self->{connectors} // {} }) {
        my $connector = $self->{connectors}{$connector_id};
        for my $s (@{ $connector->{dns_servers} // [] }) {
            next unless ref($s) eq 'HASH';
            for my $domain (@{ $s->{domains} // [] }) {
                next unless defined $domain && length $domain;
                $domains{$domain} //= { connector => $connector_id };
            }
        }
    }
    return \%domains;
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
