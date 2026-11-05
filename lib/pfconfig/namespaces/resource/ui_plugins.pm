package pfconfig::namespaces::resource::ui_plugins;

=head1 NAME

pfconfig::namespaces::resource::ui_plugins

=cut

=head1 DESCRIPTION

The admin UI plugins registered in redis (see
docs/ui-plugins/README.md).

A plugin service registers itself in the redis-cache hash C<pf:ui_plugins>
(field: the plugin id, value: a JSON registration) when it starts and removes
itself when it stops, then expires this namespace. Building it reads that hash
and returns { id => registration } for the valid registrations.

An unreachable redis gives an empty list: the admin UI must work without any
plugin.

=cut

use strict;
use warnings;

use JSON::MaybeXS;
use Redis::Fast;
use pf::log;

use base 'pfconfig::namespaces::resource';

our $REDIS_KEY = 'pf:ui_plugins';

# a plugin id, also used in the UI routes and the API paths
our $ID_RE = qr/^[a-z][a-z0-9_-]{0,62}$/;

sub init {
    my ($self) = @_;
    $self->{config} = $self->{cache}->get_cache('config::Pf');
}

=head2 redis

The redis-cache connection, from services.redis_cache_host/port

=cut

sub redis {
    my ($self) = @_;
    my $services = $self->{config}{services} // {};
    my $host = $services->{redis_cache_host} || '127.0.0.1';
    my $port = $services->{redis_cache_port} || 6379;
    return Redis::Fast->new(
        server        => "$host:$port",
        reconnect     => 0,
        cnx_timeout   => 2,
        read_timeout  => 2,
        write_timeout => 2,
    );
}

=head2 validate

Returns the normalized registration, or undef with the reason

=cut

sub validate {
    my ($id, $json) = @_;
    return (undef, "invalid id") unless defined $id && $id =~ $ID_RE;
    my $registration = eval { decode_json($json) };
    return (undef, "invalid JSON: $@") if $@ || ref($registration) ne 'HASH';
    my ($host, $port, $path) = @{$registration}{qw(host port manifest_path)};
    my $scheme = $registration->{scheme} // 'http';
    return (undef, "id mismatch") if defined $registration->{id} && $registration->{id} ne $id;
    return (undef, "invalid host") unless defined $host && !ref($host) && $host =~ /^[A-Za-z0-9.:\[\]_-]+$/;
    return (undef, "invalid port") unless defined $port && !ref($port) && $port =~ /^\d+$/ && $port > 0 && $port < 65536;
    return (undef, "invalid manifest_path") unless defined $path && !ref($path) && $path =~ m{^/[^\s?#]*$};
    return (undef, "invalid scheme") unless $scheme eq 'http' || $scheme eq 'https';
    return ({ id => $id, scheme => $scheme, host => $host, port => $port + 0, manifest_path => $path }, undef);
}

sub build {
    my ($self) = @_;
    my $logger = get_logger;
    my @raw = eval { $self->redis->hgetall($REDIS_KEY) };
    if ($@) {
        $logger->warn("Unable to read the UI plugins from redis: $@");
        return {};
    }
    my %raw = @raw;
    my %plugins;
    for my $id (sort keys %raw) {
        my ($registration, $error) = validate($id, $raw{$id});
        if ($error) {
            $logger->warn("UI plugin '$id' ignored: $error");
            next;
        }
        $plugins{$id} = $registration;
    }
    return \%plugins;
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
