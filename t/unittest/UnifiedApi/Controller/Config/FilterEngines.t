#!/usr/bin/perl

=head1 NAME

FilterEngines

=head1 DESCRIPTION

unit test for FilterEngines

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 18;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');
my $url = "/api/v1/config";

$t->post_ok("$url/parse_condition" => json => {})
  ->status_is(422);

$t->post_ok("$url/parse_condition" => json => { condition => []})
  ->status_is(422);

$t->post_ok("$url/parse_condition" => json => { condition => 'b == "bob" && a = "bobby"'})
  ->status_is(422);

$t->post_ok("$url/parse_condition" => json => { condition => "b && a"})
  ->status_is(200);

$t->post_ok(
    "$url/flatten_condition" => json => {
        condition => {
            value => '^a.s$',
            op    => 'regex',
            field => 'b',
        }
    }
  )
  ->status_is(200)
  ->json_is(
    {
        status => 200,
        item   => {
            condition => {
                value => '^a.s$',
                op    => 'regex',
                field => 'b',
            },
            condition_string => 'b =~ "^a.s$"'
        },
    }
  );

$t->post_ok("$url/parse_condition" => json => { condition => 'b =~ "^a\\\\.s$"'})
  ->status_is(200)
  ->json_is({
    status => 200,
    item => {
        condition => {
            value => '^a\\.s$',
            op => 'regex',
            field => 'b',
        },
        condition_string => 'b =~ "^a\\\\.s$"'
    },
  });

$t->post_ok(
    "$url/flatten_condition" => json => {
        condition => {
            value => '^a\\.s$',
            op    => 'regex',
            field => 'b',
        }
    }
  )
  ->status_is(200)
  ->json_is(
    {
        status => 200,
        item   => {
            condition => {
                value => '^a\\.s$',
                op    => 'regex',
                field => 'b',
            },
            condition_string => 'b =~ "^a\\\\.s$"'
        },
    }
  );


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
