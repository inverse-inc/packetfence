package pf::UnifiedApi::Controller::Configurator;

=head1 NAME

pf::UnifiedApi::Controller::Configurator -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Configurator

=cut

use strict;
use warnings;
use Mojo::UserAgent;
use Mojo::Transaction::HTTP;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::config qw(%Config);
use pf::util;
use pf::constants;
use pf::api::unifiedapiclient;


sub allowed {
    my ($self) = @_;
    if (isenabled($Config{advanced}{configurator})) {
        return $TRUE;
    }
    return $self->render_error(401, "The configurator is turned off");
}

sub proxy_api_frontend {
    my ($self) = @_;
    my $req = $self->req->clone;
    my $url = $req->url;
    $url->scheme("https")->port(9999)->host('localhost');
    my $path = $url->path;
    $path =~ s#/api/v1/configurator/#/api/v1/#;
    $url->path($path);
    add_token($req);
    my $ua = Mojo::UserAgent->new;
    $ua->insecure(1);
    my $tx = $ua->start(Mojo::Transaction::HTTP->new(req => $req));
    return _proxy_tx($self, $tx);
}

sub add_token {
    my ($req) = @_;
    my $headers = $req->headers;
    if ($headers->authorization) {
        return;
    }

    my $default_client = pf::api::unifiedapiclient->default_client;
    my $token = $default_client->token;
    if (!$token) {
        $default_client->login();
        $token = $default_client->token;
    }
    if ($token) {
        $headers->authorization("Bearer $token");
    }
}

sub _proxy_tx {
    my ( $self, $tx ) = @_;
    my $error = $tx->error;
    if ( !$error || $error->{code} ) {
        my $res = $tx->res;
        $self->tx->res($res);
        $self->rendered;
    }
    else {
        $self->tx->res->headers->add( 'X-Remote-Status',
            ( $error->{status} // 500 ) . ': ' . $error->{message} );
        $self->render( status => 500, json => $error );
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

