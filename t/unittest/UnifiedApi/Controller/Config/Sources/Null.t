#!/usr/bin/perl

=head1 NAME

Null

=head1 DESCRIPTION

unit test for Null

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 3;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');
use pf::ConfigStore::Source;
use Utils;
use Test::Mojo;
my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Source");
my $collection_base_url = '/api/v1/config/sources';
my $base_url = '/api/v1/config/source';
#This is the second test
$t->post_ok("$collection_base_url" =>
    json => {
        type => 'Null',
        id   => 'test',
        description => "Test",
        "email_required" => undef,
      "authentication_rules" =>  [
        {
          "id" =>  "hhhh",
          "status" =>  "enabled",
          "description" =>  undef,
          "match" =>  "all",
          "actions" =>  [
            {
              "type" =>  "set_role",
              "value" =>  "default"
            },
            {
              "type" =>  "set_access_duration",
              "value" =>  "1h"
            }
          ],
          "conditions" =>  []
        }
      ],
    }
  )
  ->status_is(201);


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

