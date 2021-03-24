#!/usr/bin/perl

=head1 NAME

LDAP

=head1 DESCRIPTION

unit test for LDAP

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

use Test::More tests => 5;

#This test will running last
use Test::NoWarnings;
use Test::Mojo;
use pf::ConfigStore::Source;
use Utils;
my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Source");
my $t = Test::Mojo->new('pf::UnifiedApi');
my $id = "id_$$";
my %args = (
    administration_rules => undef,
    authentication_rules => [
        {
            actions => [
                {
                    type  => "set_role",
                    value => "default"
                },
                {
                    type  => "set_access_duration",
                    value => "1h",
                }
            ],
            conditions  => [],
            description => undef,
            id          => "catchall",
            match       => "all"
        }
    ],
    binddn => 'CN=test,DC=inverse,DC=ca',
    basedn => 'DC=ldap,DC=inverse,DC=ca',
    cache_match        => 0,
    connection_timeout => 1,
    description        => "$id description",
    email_attribute    => "mail",
    encryption         => "starttls",
    host               => ['127.0.0.1'],
    id                 => $id,
    monitor            => 1,
    password           => "password",
    port               => 389,
    read_timeout       => 10,
    scope             => "sub",
    searchattributes  => "",
    shuffle           => 0,
    type              => "AD",
    usernameattribute => "sAMAccountName",
    write_timeout     => 5
);

$t->post_ok(
    '/api/v1/config/sources' => json => \%args
)
->status_is(201);

$t->post_ok(
    '/api/v1/config/sources' => json => {
        %args,
        host               => '127.0.0.1',
        id                 => "id_2_$$",
    }
)
->status_is(201);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
