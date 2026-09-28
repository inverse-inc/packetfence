#!/usr/bin/perl

=head1 NAME

google-provisioner-chromebook -

=head1 DESCRIPTION

google-provisioner-chromebook

=cut

use strict;
use warnings;
use lib qw(
    /usr/local/pf/lib
    /usr/local/pf/lib_perl/lib/perl5
);
use Mojolicious::Lite;
use Mojo::JSON;
use MIME::Base64 ();
use URI::Escape qw(uri_escape);
$SIG{PIPE} = "IGNORE";

# UniFi OS emulation (UDM / Cloud Key Gen2 / UniFi OS Server), served on port
# 8445 only so the classic-controller emulation below keeps its behaviour on the
# other ports: /proxy/network prefix, /api/auth/login, TOKEN cookie whose JWT
# carries the csrfToken claim, and POST commands refused with 403 unless the
# X-CSRF-Token header matches. The token is rotated on each command.
my $UOS_PORT = 8445;
my $CSRF_TOKEN = 'csrf-token-1';
my $CSRF_ROTATED = 'csrf-token-2';
my $SEND_CSRF_HEADERS = 1;

sub uos { return $_[0]->tx->local_port == $UOS_PORT }
sub b64url { my $b = MIME::Base64::encode_base64($_[0], ''); $b =~ tr{+/}{-_}; $b =~ s/=+$//; return $b }
sub uos_cookie_ok { my $t = $_[0]->cookie('TOKEN'); return defined $t && $t =~ /^header\./ }
sub send_csrf { my ($c, $t) = @_; return unless $SEND_CSRF_HEADERS; $c->res->headers->header('x-csrf-token' => $t); $c->res->headers->header('x-updated-csrf-token' => $t) }

post '/mock/csrf-headers/:state' => sub {
    my ($c) = @_;
    $SEND_CSRF_HEADERS = $c->stash('state') eq 'on' ? 1 : 0;
    $c->render(json => { csrf_headers => $SEND_CSRF_HEADERS });
};

get '/proxy/network/status' => sub {
    my ($c) = @_;
    return $c->render(status => 404, json => {}) unless uos($c);
    return $c->render(status => 401, json => { code => 'AUTHENTICATION_REQUIRED' }) unless uos_cookie_ok($c);
    send_csrf($c, $CSRF_TOKEN);
    $c->render(json => { meta => { rc => 'ok' }, data => [] });
};

post '/api/auth/login' => sub {
    my ($c) = @_;
    return $c->render(status => 404, json => {}) unless uos($c);
    my $body = $c->req->json // {};
    return $c->render(status => 403, json => { code => 'AUTHENTICATION_FAILED' })
      unless ($body->{username} // '') eq 'admin' && ($body->{password} // '') eq 'admin';
    $c->cookie(TOKEN => 'header.' . b64url(Mojo::JSON::encode_json({ csrfToken => $CSRF_TOKEN, userId => 'test' })) . '.signature', { path => '/' });
    send_csrf($c, $CSRF_TOKEN);
    $c->render(json => { unique_id => 'test', username => 'admin' });
};

get '/proxy/network/api/self/sites' => sub {
    my ($c) = @_;
    return $c->render(status => 404, json => {}) unless uos($c);
    return $c->render(status => 401, json => {}) unless uos_cookie_ok($c);
    $c->render(json => { meta => { rc => 'ok' }, data => [ { _id => '3ae8b9ce33ee7dce23eb989e38da25a1', desc => 'Default', name => 'default', role => 'admin' } ] });
};

# Network 10.6 answers 400 to the per-client lookup (as reported in #9260)
get '/proxy/network/api/s/:site/stat/sta/*mac' => sub {
    my ($c) = @_;
    return $c->render(status => 404, json => {}) unless uos($c);
    $c->render(status => 400, json => { meta => { rc => 'error', msg => 'api.err.InvalidArgument' } });
};

post '/proxy/network/api/s/:site/cmd/stamgr' => sub {
    my ($c) = @_;
    return $c->render(status => 404, json => {}) unless uos($c);
    return $c->render(status => 401, json => {}) unless uos_cookie_ok($c);
    my $token = $c->req->headers->header('X-CSRF-Token') // '';
    return $c->rendered(403) unless $token eq $CSRF_TOKEN || $token eq $CSRF_ROTATED;
    send_csrf($c, $CSRF_ROTATED);
    my $body = $c->req->json // {};
    $c->render(json => { meta => { rc => 'ok' }, data => [ { mac => $body->{mac}, authorized_by => 'api' } ] });
};

any '/*dapath' => sub {
    my ($c) = @_;
    my $req = $c->req;
    return $c->rendered( 204 ) if $req->method eq 'OPTIONS';
    my $variant = variant($req);
    return $c->render(
        template => join( '/', uc $req->method, $c->stash('dapath') ),
        variant  => $variant,
        format   => 'json',
    );

};

sub variant {
    my ($req) = @_;
    my $query_params = $req->query_params;
    for my $k (qw(pageToken query)) {
        my $value = $query_params->param($k);
        if ($value) {
            return "$k=" . uri_escape($value);
        }
    }

    return undef;
}

app->start;

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

__DATA__
@@ POST/api/login.json.ep

%# Test login in

{
  "meta": {
    "rc": "ok"
  },
  "data": []
}

@@ GET/api/self/sites.json.ep

{
  "meta": {
    "rc": "ok"
  },
  "data": [
    {
      "_id": "3ae8b9ce33ee7dce23eb989e38da25a1",
      "anonymous_id": "15e05e3e-8469-4ae7-a85e-71f04d07ed8f",
      "attr_hidden_id": "default",
      "attr_no_delete": true,
      "desc": "Default",
      "name": "default",
      "role": "admin"
    }
  ]
}

@@ GET/api/s/default/stat/device/.json.ep

{
  "meta": {
    "rc": "ok"
  },
  "data": [
    {
      "ip": "1.2.3.4",
      "mac": "47:11:f7:d7:d6:a1",
      "vap_table": [
        {
          "bssid": "47:11:f7:d7:d6:a2"
        },
        {
          "bssid": "47:11:f7:d7:d6:a3"
        },
        {
          "bssid": "47:11:f7:d7:d6:a4"
        },
        {
          "bssid": "47:11:f7:d7:d6:a5"
        }
      ]
    },
    {
      "ip": "1.2.3.5",
      "mac": "47:11:f7:d7:d6:a6",
      "vap_table": [
        {
          "bssid": "47:11:f7:d7:d6:a7"
        },
        {
          "bssid": "47:11:f7:d7:d6:a8"
        },
        {
          "bssid": "47:11:f7:d7:d6:a9"
        },
        {
          "bssid": "47:11:f7:d7:d6:aa"
        }
      ]
    }
  ]
}

@@ GET/api/proxy/network/api/self/sites.json.ep
{
  "meta": {
    "rc": "ok"
  },
  "data": [
    {
      "anonymous_id": "45187dde-4107-442c-97e0-5ac517097af3",
      "name": "default",
      "external_id": "88f7af54-98f8-306a-a1c7-c9349722b1f6",
      "_id": "58949c38f69b8a3bf14bfc2b",
      "attr_no_delete": true,
      "attr_hidden_id": "default",
      "desc": "AMV",
      "role": "admin",
      "role_hotspot": false,
      "device_count": 9
    }
  ]
}
