package pfconfig::namespaces::resource::pfconnector_static_connections;

=head1 NAME

pfconfig::namespaces::resource::pfconnector_static_connections -

=head1 DESCRIPTION

pfconfig::namespaces::resource::pfconnector_static_connections

=cut

use strict;
use warnings;
use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;
    $self->{_authentication_config} =
      $self->{cache}->get_cache('config::Authentication');
}

sub find_connector {

}

sub build {
    my ($self) = @_;
    my %hash;
    while ( my ( $id, $data ) =
        each %{ $self->{_authentication_config}{authentication_config_hash} } )
    {
        next unless $data->{'type'} eq 'RADIUS';
        my $port = $data->{'connect_through_port'};
        next unless defined $port;
        my $connector = $self->find_connector( $data->{host} );
        my $r         = "100.64.0.1:${port}:$data->{host}:$data->{port}/udp";
        push @{ $hash{$connector} }, $r;
    }
    return \%hash;
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
