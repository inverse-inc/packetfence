#!/usr/bin/perl

=head1 NAME

rapid7 -

=head1 DESCRIPTION

rapid7

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use Mojolicious::Lite;

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
@@ GET/api/3/scan_templates.json.ep

%# Test authorize pass

{
  "links": [
    {
      "href": "https://hostname:3780/api/3/...",
      "rel": "self"
    }
  ],
  "resources": [
    {
      "id": "full-audit-without-web-spider",
      "name": "Full audit"
    }
  ]
}

@@ GET/api/3/scan_engines.json.ep

%# Test authorize pass

{
  "links": [
    {
      "href": "https://hostname:3780/api/3/...",
      "rel": "self"
    }
  ],
  "resources": [
    {
      "id": 6,
      "name": "Corporate Scan Engine 001"
    }
  ]
}

@@ GET/api/3/sites.json.ep

%# Test authorize pass

{
  "links": [
    {
      "href": "https://hostname:3780/api/3/...",
      "rel": "self"
    }
  ],
  "resources": [
    {
      "id": 5,
      "name": "Site Name"
    }
  ]
}

