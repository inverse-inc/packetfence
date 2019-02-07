package pf::pffilter::client;

=head1 NAME

pf::pffilter::client -

=cut

=head1 DESCRIPTION

pf::pffilter::client

=cut

use strict;
use warnings;
use pf::file_paths qw($var_dir $pffilter_socket_path);
use IO::Socket::UNIX;
use JSON::MaybeXS;
use pf::log;

=head2 new

Constructor for pf::pffilter::client

=cut

sub new {
    my ($proto) = @_;
    return bless {}, ref($proto) || $proto;
}

=head2 filter_profile

Send the filter profile request

=cut

sub filter_profile {
    my ($self, $data) = @_;
    return $self->send_request('filter_profile', $data);
}


=head2 filter_radius

filter_radius

=cut

sub filter_radius {
    my ($self, $scope, $data) = @_;
    return $self->send_request('filter_radius', [$scope, $data]);
}


=head2 filter_dns

filter_dns

=cut

sub filter_dns {
    my ($self, $scope, $data) = @_;
    return $self->send_request('filter_dns', [$scope, $data]);
}

=head2 filter_dhcp

filter_dhcp

=cut

sub filter_dhcp {
    my ($self, $scope, $data) = @_;
    return $self->send_request('filter_dhcp', [$scope, $data]);
}


=head2 filter_vlan

filter_vlan

=cut

sub filter_vlan {
    my ($self, $scope, $data) = @_;
    return $self->send_request('filter_vlan', [$scope, $data]);
}

=head2 send_request

Send the request to the pffilter service

=cut

sub send_request {
    my ($self, $method, $params) = @_;
    my $socket = $self->get_socket;
    my %request  = (
        method => $method,
        params => $params
    );
    my $bytes = encode_json(\%request);
    print $socket $bytes . "\n";
    $bytes = <$socket>;
    if (!defined $bytes) {
        die "Error ";
    }
    if ($bytes) {
        my $response = decode_json($bytes);
        if ($response->{error}) {
            die $response->{error}->{message}
        }
        return $response->{result};
    }
}

=head2 get_socket

Get the socket for the pffilter service

=cut

sub get_socket {
    return IO::Socket::UNIX->new(
        Type => SOCK_STREAM(),
        Peer => $pffilter_socket_path
    );
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

