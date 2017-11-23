#!/usr/bin/perl

=head1 NAME

pf::tenant_code

=cut

=head1 DESCRIPTION

unit tests for pf::tenant_code

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

use pf::ConfigStore::Switch;
use pf::dal::tenant_code;
use pf::tenant_code;
use Test::More tests => 7;

#This test will running last
use Test::NoWarnings;

my $status;

# First clear out the codes
pf::dal::tenant_code->remove_items();

my $test_code = "192168";
my $test_tenant_name = "bob-garauge";
my $test_switch_ip = "192.168.5.3";

my $switch_cs = pf::ConfigStore::Switch->new;

# Onboard with an existing tenant
# Create a test code
($status, my $code) = pf::dal::tenant_code->find_or_create({ code => $test_code, switch_ip => $test_switch_ip });
is($status, $STATUS::CREATED, "$test_code was successfully created");

($status, my $tenant) = pf::dal::tenant->find_or_create({name => $test_tenant_name});
ok(($status == $STATUS::CREATED || $status == $STATUS::OK), "$test_tenant_name was successfully found/created");

$tenant = pf::dal::tenant->search(-where => {name => $test_tenant_name})->next;

pf::tenant_code->onboard($test_code, $tenant);

is($switch_cs->read($test_switch_ip)->{TenantId}, $tenant->{id}, "Onboarding set the tenant ID of the switch");

# Onboard with a new tenant
$test_tenant_name = "bob-garauge-".localtime();

($status, $code) = pf::dal::tenant_code->find_or_create({ code => $test_code, switch_ip => $test_switch_ip });
is($status, $STATUS::OK, "$test_code was successfully found");

pf::tenant_code->onboard($test_code, {name => $test_tenant_name});

$tenant = pf::dal::tenant->search(-where => { name => $test_tenant_name })->next;
is($tenant->{name}, $test_tenant_name, "Onboarding process for an inexisting tenant created the tenant");

is($switch_cs->read($test_switch_ip)->{TenantId}, $tenant->{id}, "Onboarding set the tenant ID of the switch");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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


