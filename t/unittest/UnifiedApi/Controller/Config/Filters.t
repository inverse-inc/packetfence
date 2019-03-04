#!/usr/bin/perl

=head1 NAME

Domains

=cut

=head1 DESCRIPTION

unit test for Domains

=cut

use strict;
use warnings;
#
use lib qw(
    /usr/local/pf/lib
);

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 13;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $base_url = '/api/v1/config/filter/vlan';
my $content = <<'CONTENT';
[2]
filter = node_info
attribute=category
operator = match
value = default

[3]
filter = ssid
operator = is
value = OPEN

[4]
filter = ssid
operator = is
value = TEST

[5]
filter = node_info.category
operator = match_not
value = bob

[6]
filter = node_info.status
operator = is
value = unreg

[2:2&3]
scope = RegistrationRole
role = registration

[3: 4 && ( 5 & 6 )]
scope = RegistrationRole
role = registration2
CONTENT

$t->put_ok($base_url => {} => $content)
  ->status_is(200)
  ->json_is({ status => 200 });

$t->get_ok($base_url)
  ->status_is(200)
  ->content_is($content);

$t->put_ok($base_url => {} => "This is a garbage")
  ->status_is(422)
  ->json_has("/errors");

$t->put_ok($base_url => {} => "This is a garbage\n")
  ->status_is(422)
  ->json_has("/errors");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

