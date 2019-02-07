package pf::dhcp::api;

=head1 NAME

pf::dhcp::api

=cut

=head1 DESCRIPTION

Allows to access the pfdhcp API through the Unified API

=head1 SYNOPSIS

    use pf::dhcp::api;

    my $dhcp_api = pf::dhcp::api->new(host => 'localhost');

    my $data = $dhcp_api->get_lease("ip", "10.229.25.247");

=cut

use strict;
use warnings;
use Moo;
use MIME::Base64;
use pf::log;
use pf::cluster;
use POSIX::AtFork;
use pf::api::unifiedapiclient;
use pf::config qw(%Config);
use pf::StatsD::Timer;
use DateTime::Format::RFC3339;

our $VERSION = '0.01';
my $default_client;

=head1 ATTRIBUTES

=head2 host

host of dhcp server

=cut

has host => (is => 'rw', default => sub  { 'localhost' });

=head2 after host

Set the host in the Unified API client after setting it here

=cut

after 'host' => sub {
    my ($self) = @_;
    $self->unified_api_client->host($self->{host});
};

=head2 unified_api_client

The Unified API client

=cut

has unified_api_client => (is => 'rw');

=head2 get_lease

Get a lease on the pfdhcp API

=cut

sub get_lease {
    my $timer = pf::StatsD::Timer->new();

    my ($self, $type, $value) = @_;
    my $logger = get_logger;

    my $res;
    eval {
        $res = $self->unified_api_client->call("GET", "/api/v1/dhcp/$type/$value");
        my $f = DateTime::Format::RFC3339->new();
        $res->{ends_at} = $f->parse_datetime( $res->{ends_at} )->epoch;
    };
    if($@) {
        $logger->warn("Cannot get lease for $value through the pfdhcp API: $@");
        return undef;
    }
    return $res;
}

=head2 default_client

Get the default DHCP API client based on the configuration

=cut

sub default_client {
    return $default_client;
}

sub CLONE {
    my $api_host = $cluster_enabled ? pf::cluster::management_cluster_ip : '127.0.0.1'; 
    $default_client = pf::dhcp::api->new;
    $default_client->unified_api_client(pf::api::unifiedapiclient->new);
    $default_client->host($api_host);

    $default_client->unified_api_client->timeout_ms($Config{pfdhcp}{timeout_ms});
    $default_client->unified_api_client->connect_timeout_ms($Config{pfdhcp}{connect_timeout_ms});
}
POSIX::AtFork->add_to_child(\&CLONE);
CLONE();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
