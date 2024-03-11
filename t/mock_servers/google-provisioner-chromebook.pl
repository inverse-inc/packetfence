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
@@ GET/admin/directory/v1/customer/my_customer/devices/chromeos.json+query=0022446688aa.ep

%# Test authorize pass

{
  "kind": "admin#directory#chromeosdevices",
  "etag": "\"swLRVvvLuHfCKiJORq8j43HfhSe9XvfGVMcLgfvLY0Y/i5vFr_y-WXYwvilWIWe8rL9FSzk\"",
  "chromeosdevices": [
    {
      "status": "ACTIVE",
      "macAddress": "0022446688aa",
      "recentUsers": [
        {
          "type": "USER_TYPE_MANAGED",
          "email": "00:22:44:66:88:aa@test.test"
        }
      ]
    }
  ]
}

@@ GET/admin/directory/v1/customer/my_customer/devices/chromeos.json+query=0022446688ab.ep

%# Test authorize fail

{
  "kind": "admin#directory#chromeosdevices",
  "etag": "\"swLRVvvLuHfCKiJORq8j43HfhSe9XvfGVMcLgfvLY0Y/i5vFr_y-WXYwvilWIWe8rL9FSzk\"",
  "chromeosdevices": [
    {
      "status": "DISABLED",
      "macAddress": "0022446688ab"
    }
  ]
}

@@ GET/admin/directory/v1/customer/my_customer/devices/chromeos.json+query=sync%3A0000-01-02...ep

%# Test polling for devices

{
  "kind": "admin#directory#chromeosdevices",
  "etag": "\"swLRVvvLuHfCKiJORq8j43HfhSe9XvfGVMcLgfvLY0Y/i5vFr_y-WXYwvilWIWe8rL9FSzk\"",
  "chromeosdevices": [
    {
      "status": "ACTIVE",
      "macAddress": "0022446688aa",
      "lastSync": "2021-06-02T15:09:11.657Z"
    }
  ],
  "nextPageToken": "123"
}

@@ GET/admin/directory/v1/customer/my_customer/devices/chromeos.json+pageToken=123.ep

%# Test polling for devices

{
  "kind": "admin#directory#chromeosdevices",
  "etag": "\"swLRVvvLuHfCKiJORq8j43HfhSe9XvfGVMcLgfvLY0Y/i5vFr_y-WXYwvilWIWe8rL9FSzk\"",
  "chromeosdevices": [
    {
      "status": "DISABLED",
      "macAddress": "0022446688ab",
      "lastSync": "2021-06-02T15:09:12.657Z"
    },
    {
      "status": "DISABLED",
      "macAddress": "0022446688cb",
      "lastSync": "2021-06-02T15:09:13.657Z"
    }
  ]
}

@@ GET/admin/directory/v1/customer/my_customer/devices/chromeos.json+query=sync%3A0000-01-01...ep

%# Test importing devices

{
  "kind": "admin#directory#chromeosdevices",
  "etag": "\"swLRVvvLuHfCKiJORq8j43HfhSe9XvfGVMcLgfvLY0Y/i5vFr_y-WXYwvilWIWe8rL9FSzk\"",
  "chromeosdevices": [
    {
      "status": "ACTIVE",
      "macAddress": "0022446688ac",
      "lastSync" : "",
      "recentUsers": [
        {
          "type": "USER_TYPE_MANAGED",
          "email": "00:22:44:66:88:ac@test.test"
        }
      ]
    },
    {
      "status": "ACTIVE",
      "macAddress": "0022446688ad",
      "lastSync" : "",
      "recentUsers": [
        {
          "type": "USER_TYPE_MANAGED",
          "email": "00:22:44:66:88:ad@test.test"
        }
      ]
    }
  ],
  "nextPageToken": "124"
}

@@ GET/admin/directory/v1/customer/my_customer/devices/chromeos.json+pageToken=124.ep

%# Test importing devices

{
  "kind": "admin#directory#chromeosdevices",
  "etag": "\"swLRVvvLuHfCKiJORq8j43HfhSe9XvfGVMcLgfvLY0Y/i5vFr_y-WXYwvilWIWe8rL9FSzk\"",
  "chromeosdevices": [
    {
      "status": "ACTIVE",
      "macAddress": "0022446688ae",
      "recentUsers": [
        {
          "type": "USER_TYPE_MANAGED",
          "email": "00:22:44:66:88:ae@test.test"
        }
      ]
    },
    {
      "status": "DISABLED",
      "macAddress": "0022446688af"
    }
  ]
}

@@ POST/token.json.ep
%# Test caching of the access_token

{
  "access_token": "<%= $main::ACCESS_TOKEN++ %>",
  "expires_in": 3599,
  "token_type": "Bearer"
}
