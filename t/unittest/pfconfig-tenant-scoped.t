#!/usr/bin/perl

=head1 NAME

pfconfig-tenant-scoped

=cut

=head1 DESCRIPTION

unit test for pfconfig-tenant-scoped

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 15;
use Test::NoWarnings;
use pfconfig::cached_hash;
use pf::config::tenant;

tie our %ConfigTest, 'pfconfig::cached_hash', 'resource::tenant_aware_hash_test', tenant_id_scoped => 1;
tie our @ConfigTest, 'pfconfig::cached_array', 'resource::tenant_aware_array_test', tenant_id_scoped => 1;
is($ConfigTest{'inverse.ca'}{admin_strip_username}, "disabled", "Found inverse.ca=>admin_strip_username");
is_deeply(
    $ConfigTest{'inverse.ca'},
    {
        admin_strip_username  => 'disabled',
        portal_strip_username => 'enabled'
    },
    "Scoped 'inverse.ca' is_deeply",
);

ok(!exists $ConfigTest{'bob.com'}, "Bob.com does not exists");
ok(!exists $ConfigTest{'7623'}, "7623 does not exists");
ok(exists $ConfigTest{'inverse.ca'}, "inverse.ca exists");

{
    local $pf::config::tenant::CURRENT_TENANT = 2;
    is($ConfigTest{'bob.com'}{admin_strip_username}, "enabled", "Found bob.com=>admin_strip_username");
    is_deeply(
        $ConfigTest{'bob.com'},
        {
            admin_strip_username  => 'enabled',
            portal_strip_username => 'disabled'
        },
        "Scoped 'bob.com' is_deeply",
    );
    ok(exists $ConfigTest{'bob.com'}, "Bob does exists");
    ok(!exists $ConfigTest{'bob.com'}{unknown}, "bob.com=>unknown does exists");
    ok(!exists $ConfigTest{'7623'}, "7623 does not exists");
    ok(!exists $ConfigTest{'inverse.ca'}, "inverse.ca does not exists");
}

{
    is_deeply(\@ConfigTest, ['a'...'f'], "ConfigTest => ['a'...'f']");
}

{
    local $pf::config::tenant::CURRENT_TENANT = 2;
    is_deeply(\@ConfigTest, ['g'...'z'], "ConfigTest => ['g'...'z']");
}

{
    is_deeply(\@ConfigTest, ['a'...'f'], "ConfigTest => ['a'...'f']");
}

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
