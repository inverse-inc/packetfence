package fingerbank::Collector;

=head1 NAME

fingerbank::API

=head1 DESCRIPTION

Object oriented module to work with the Fingerbank Collector

=cut

use fingerbank::Config;
use fingerbank::Util;
use HTTP::Request;
use URI;
use URI::https;
use fingerbank::Util qw(is_enabled);
use fingerbank::NullCache;
use fingerbank::Constant qw($FALSE);

use Moose;

has 'host' => (is => 'rw');
has 'port' => (is => 'rw');
has 'use_https' => (is => 'rw');
has 'cache' => (is => 'rw', default => sub { fingerbank::NullCache->new });

=head2 new_from_config

Create a new collector client from the configured parameters in fingerbank.conf

=cut

sub new_from_config {
    my ($class) = @_;
    my $Config = fingerbank::Config::get_config();
    return $class->new(
        cache => $fingerbank::Config::CACHE,
        map{$_ => $Config->{collector}->{$_}} qw(host port use_https),
    );
}

=head2 get_lwp_client

Get the LWP client to talk to the collector

=cut

sub get_lwp_client {
    my $ua = fingerbank::Util::get_lwp_client(keep_alive => 1, use_proxy => $FALSE);
    $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
    $ua->timeout(2);   # An query should not take more than 2 seconds
    return $ua;
}

=head2 build_request

Given a verb and a path, build the HTTP::Request  based on the client configuration

=cut

sub build_request {
    my ($self, $verb, $path) = @_;
    
    my $Config = fingerbank::Config::get_config();

    my $proto = is_enabled($self->use_https) ? "https" : "http";
    my $host = $self->host;
    my $port = $self->port;
    my $url = URI->new("$proto://$host:$port$path");

    my $req = HTTP::Request->new($verb => $url->as_string);
    $req->header(Authorization => "Token ".$Config->{'upstream'}{'api_key'});

    return $req;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
