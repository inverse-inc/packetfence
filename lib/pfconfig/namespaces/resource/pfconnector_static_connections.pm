package pfconfig::namespaces::resource::pfconnector_static_connections;

=head1 NAME

pfconfig::namespaces::resource::pfconnector_static_connections -

=head1 DESCRIPTION

pfconfig::namespaces::resource::pfconnector_static_connections

=cut

use strict;
use warnings;
use base 'pfconfig::namespaces::resource';
use NetAddr::IP;
use pf::util qw(listify isenabled);

# Port offset added when using a connector for NTLM auth
use constant CONNECTOR_PORT_OFFSET => 100;

# Port offset and target port for the ntlm-join-remote service
use constant JOIN_REMOTE_PORT_OFFSET => 200;
use constant JOIN_REMOTE_TARGET_PORT => 23000;

sub init {
    my ($self) = @_;
    $self->{_authentication_config} =
      $self->{cache}->get_cache('config::Authentication');
    $self->{_connector_config} =
      $self->{cache}->get_cache('config::Connector');
    $self->{_connectors_ordered} =
      $self->{cache}->get_cache('resource::connectors_ordered');
    $self->{_dns_connectors_config} =
      $self->{cache}->get_cache('config::DnsConnectors');
    $self->{_domain_config} =
      $self->{cache}->get_cache('config::Domain');
}

sub find_connector {
    my ( $self, $ip ) = @_;
    $ip = NetAddr::IP->new($ip);
    my $config = $self->{_connector_config};
    for my $connector_id ( @{ $self->{_connectors_ordered} // [] } ) {
        for my $net ( @{ $config->{$connector_id}{networks} } ) {
            $net = NetAddr::IP->new($net);
            if ( $net->contains($ip) ) {
                return $connector_id;
            }
        }
    }

    return 'local_connector';
}

sub build {
    my ($self) = @_;
    my %hash;
    while ( my ( $id, $data ) =
        each %{ $self->{_authentication_config}{authentication_config_hash} } )
    {
        next unless $data->{'use_connector'};
        my $type = $data->{'type'};
        my $port = $data->{'pfconnector_port'};
        next unless $port && ( $type eq 'RADIUS' );
        my $proto = $type eq 'RADIUS' ? '/udp' : '';
        for my $h ( @{ listify( $data->{host} ) } ) {
            my $connector = $self->find_connector($h);
            my $r         = "${port}:$h:$data->{port}$proto";
            push @{ $hash{$connector} }, $r;
        }
    }

    for my $id ( keys %{ $self->{_dns_connectors_config} } ) {
        my $data = $self->{_dns_connectors_config}{$id};
        my $port = $data->{'pfconnector_port'};
        next unless defined $port;
        my $connector = $self->find_connector( $data->{ip} );
        my $r         = "${port}:$data->{ip}:$data->{port}/udp";
        push @{ $hash{$connector} }, $r;
        $r         = "${port}:$data->{ip}:$data->{port}";
        push @{ $hash{$connector} }, $r;
    }
    for my $id ( keys %{ $self->{_dns_connectors_config} } ) {
        my $data = $self->{_dns_connectors_config}{$id};
        my $port = $data->{'pfconnector_port'};
        next unless defined $port;
        my $connector = $self->find_connector( $data->{ip} );
        my $r         = "100.64.0.1:${port}:$data->{ip}:$data->{port}/udp";
        push @{ $hash{$connector} }, $r;
    }
    for my $id ( keys %{ $self->{_domain_config} } ) {
        my $data = $self->{_domain_config}{$id};
        next unless isenabled($data->{'use_connector'});
        my $port = $data->{'ntlm_auth_port'};
        next unless defined $port;
        $port += CONNECTOR_PORT_OFFSET;
        my $connector = $self->find_connector( $data->{ad_server} );
        my $r         = "${port}:127.0.0.1:$data->{ntlm_auth_port}/tcp";
        push @{ $hash{$connector} }, $r;
    }
    # Join-remote tunnels to reach ntlm-join-remote on port 23000
    # Deduplicate by connector + local_port to avoid duplicate tunnels
    # while still allowing multiple domains behind the same connector
    my %join_remote_seen;
    for my $id ( keys %{ $self->{_domain_config} } ) {
        my $data = $self->{_domain_config}{$id};
        next unless isenabled($data->{'use_connector'});
        my $port = $data->{'ntlm_auth_port'};
        next unless defined $port;
        my $connector = $self->find_connector( $data->{ad_server} );
        my $local_port = $port + JOIN_REMOTE_PORT_OFFSET;
        my $key = "${connector}:${local_port}";
        next if $join_remote_seen{$key};
        $join_remote_seen{$key} = 1;
        my $r = "${local_port}:127.0.0.1:" . JOIN_REMOTE_TARGET_PORT . "/tcp";
        push @{ $hash{$connector} }, $r;
    }
    return \%hash;
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
