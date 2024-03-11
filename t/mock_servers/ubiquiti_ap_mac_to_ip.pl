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
use URI::Escape qw(uri_escape);

our $ACCESS_TOKEN = 123;

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
