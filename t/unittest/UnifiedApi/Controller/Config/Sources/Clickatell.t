#!/usr/bin/perl

=head1 NAME

Clickatell

=head1 DESCRIPTION

unit test for Clickatell

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;

#This test will running last
use Test::NoWarnings;
use Test::Mojo;

my $t = Test::Mojo->new('pf::UnifiedApi');
use pf::ConfigStore::Source;
use Utils;
my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Source");
my $true = bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' );
my $false = bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' );

my $collection_base_url = '/api/v1/config/sources';

my $base_url = '/api/v1/config/source';
my $id1 = "id_$$";
my $id2 = "id2_$$";

#This is the second test
$t->post_ok("$collection_base_url" =>
    json => {
        type => 'Clickatell',
        description => 'das',
        hash_passwords => 'plaintext',
        password_length => '10',
        id   => $id1,
        message => qq{
        Hello
        World
        },
        api_key => 'asasasaas',
    }
  )
  ->status_is(201)
  ;
#This is the second test
$t->patch_ok("$base_url/$id1" =>
    json => {
        type => 'Clickatell',
        description => 'das',
        hash_passwords => 'plaintext',
        password_length => '10',
        message => qq{
        Hello
        World
        },
        api_key => 'asasasaas',
    }
  )
  ->status_is(200)
  ;

$t->get_ok("$collection_base_url")
  ->status_is(200)
  ;
use Data::Dumper; print Dumper($t->tx->res->json);


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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
