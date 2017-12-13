#!/usr/bin/perl

=head1 NAME

TenantsOnboarding

=cut

=head1 DESCRIPTION

unit test for TenantsOnboarding

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    use lib qw(/usr/local/pf/t);
    use File::Spec::Functions qw(catfile catdir rel2abs);
    use File::Basename qw(dirname);
    use setup_test_config;
    my $test_dir = rel2abs(dirname($INC{'setup_test_config.pm'})) if exists $INC{'setup_test_config.pm'};
    $test_dir ||= catdir($pf::file_paths::install_dir,'t');
    $pf::file_paths::switches_config_file = catfile($test_dir,'data/switches.conf.tmp');
}

open(my $fh, ">", $pf::file_paths::switches_config_file);

use Test::More tests => 7;

#This test will running last
use Test::NoWarnings;
use Test::Mojo;
use test_lede;
test_lede::start_lede();

use pf::dal::tenant_code;

my $t = Test::Mojo->new('pf::UnifiedApi');

# First clear out the codes
pf::dal::tenant_code->remove_items();

my $test_code = "192168";
my $test_tenant_name = "bob-garauge";
my $test_switch_ip = "127.0.0.1";

# Onboard with an existing tenant
# Create a test code
my ($status,$code) = pf::dal::tenant_code->find_or_create({ code => $test_code, switch_ip => $test_switch_ip });
is($status, $STATUS::CREATED, "$test_code was successfully created");

# When missing token, we should get a 422
$t->post_ok('/api/v1/tenants_onboarding' => json => {  })
  ->status_is(422);

$t->post_ok('/api/v1/tenants_onboarding' => json => { code => $test_code, name => $test_tenant_name })
  ->status_is(201)
  ->header_like(Location => qr/^\/api\/v1\/tenants\//);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

