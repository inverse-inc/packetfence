#!/usr/bin/perl

=head1 NAME

PortalModules

=cut

=head1 DESCRIPTION

unit test for PortalModules

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::ConfigStore::PortalModule;
use Utils;
use Test::More tests => 15;
use Test::Mojo;

my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::PortalModule");

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/portal_modules';

my $base_url = '/api/v1/config/portal_module';

$t->get_ok($collection_base_url)
  ->status_is(200);

$t->post_ok($collection_base_url => json => {})
  ->status_is(422);

$t->post_ok($collection_base_url, {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

my $pmod_1_id =  "test_${$}_1";
my $pmod_2_id =  "test_${$}_2";

my %pmod1 = (
        id      => $pmod_1_id,
        actions => [ { type => 'set_unreg_date', value => 'bob' } ],
        type    => 'Authentication::Login',
        signup_template => 'signin.html',
        aup_template => 'aup_text.html',
        description => $pmod_1_id,
);

my $false = bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' );

$t->post_ok( $collection_base_url => json => \%pmod1)
   ->status_is(201);

$t->post_ok(
    $collection_base_url => json => 
    {
        id      => $pmod_2_id,
        actions => [ { type => 'set_unregdate', value => 'bob' } ],
        type    => 'Authentication::Login',
        signup_template => 'signin.html',
        aup_template => 'aup_text.html',
        description => $pmod_2_id,
    }
)->status_is(422);



$t->get_ok("$base_url/${pmod_1_id}")
    ->status_is(200)
    ->json_is( "/item",
        {
            %pmod1,
            'multi_source_ids' => [],
            'not_deletable'    => $false,
            'fields_to_save'   => [],
            'custom_fields'    => [],
            'not_sortable'     => $false,
            'with_aup'         => '0',
            'signup_template'  => 'signin.html',
            'pid_field'        => 'username',
            'aup_template'     => 'aup_text.html',
        }
);

my $ini = pf::IniFiles->new( -file => $filename);
my $actions = $ini->val($pmod_1_id, 'actions');

is($actions, "set_unregdate(bob)", "Saved as set_unregdate");

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
