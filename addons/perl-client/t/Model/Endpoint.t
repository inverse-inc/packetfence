#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib 'lib';

use Test::More;
use Test::Deep;
use Data::Dumper;
use Data::Compare;

use_ok('fingerbank::Model::Endpoint');

ok(my $endpoint = fingerbank::Model::Endpoint->new(name => "Microsoft Windows Kernel 6.1", version => "1.0", score => 5, parents => ["Windows OS"]),
    "Can create an endpoint");

ok($endpoint->is_a("Windows OS"),
    "Endpoint is detected as a Windows based device");
ok(!$endpoint->is_a("Macintosh"),
    "Endpoint is not detected as a Macintosh");

ok($endpoint->isWindows(),
    "Enpoint responds correctly to isWindows");
ok(!$endpoint->isMacOS(),
    "Endpoint responds correctly to isMacOS");

my $json_result = <<"RESULT";
{
    "device": {
        "created_at": "2014-09-09T15:09:51.000Z",
        "id": 33,
        "name": "Microsoft Windows Kernel 6.0",
        "parent_id": 7536,
        "parents": [
            {
                "created_at": "2015-09-18T12:51:27.000Z",
                "id": 7536,
                "name": "Microsoft Windows Kernel 6.x",
                "parent_id": 1,
                "updated_at": "2015-09-22T08:11:35.000Z",
                "virtual_parent_id": null
            },
            {
                "created_at": "2014-09-09T15:09:50.000Z",
                "id": 1,
                "name": "Windows OS",
                "parent_id": 16879,
                "updated_at": "2017-09-20T15:46:53.000Z",
                "virtual_parent_id": null
            },
            {
                "created_at": "2017-09-14T18:41:06.000Z",
                "id": 16879,
                "name": "Operating System",
                "parent_id": null,
                "updated_at": "2017-09-18T16:33:18.000Z",
                "virtual_parent_id": null
            }
        ],
        "updated_at": "2015-09-18T12:53:32.000Z",
        "virtual_parent_id": null
    },
    "device_name": "Operating System/Windows OS/Microsoft Windows Kernel 6.x/Microsoft Windows Kernel 6.0",
    "score": 75,
    "version": "Vista/Server 2008"
}
RESULT

use JSON;
my $result = decode_json($json_result);

$endpoint = fingerbank::Model::Endpoint->fromResult($result);

ok($endpoint->name eq "Microsoft Windows Kernel 6.0",
    "Endpoint name is properly populated from result");

ok($endpoint->version eq "Vista/Server 2008",
    "Endpoint version is properly populated from result");

ok($endpoint->score eq 75,
    "Endpoint score is properly populated from result");

my $expected_parents = ["Microsoft Windows Kernel 6.x", "Windows OS", "Operating System"];
my ($ok, $stack) = Test::Deep::cmp_details($endpoint->parents, $expected_parents);

ok($ok,
    "Endpoint parents are properly populated from result");

$endpoint = fingerbank::Model::Endpoint->new(name => "Samsung Android", score => 0, version => undef);

$expected_parents = ["Generic Android", "Phone, Tablet or Wearable"];
($ok, $stack) = Test::Deep::cmp_details($endpoint->parents, $expected_parents);

ok($ok,
    "Endpoint parents are properly looked up when they are not passed to constructor");

done_testing();

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

