#!/usr/bin/perl
=head1 NAME

autentication

=cut

=head1 DESCRIPTION

autentication

=cut

use strict;
use warnings;

use Test::More tests => 56;                      # last test to print

use Test::NoWarnings;
use diagnostics;
use lib '/usr/local/pf/lib';
BEGIN {
    use lib '/usr/local/pf/t';
    use setup_test_config;
}

use pf::constants;
use pf::constants::realm;
use pf::constants::authentication::messages;

# pf core libs

use_ok("pf::authentication");

is(pf::authentication::match("bad_source_name",{ username => 'test', context => $pf::constants::realm::ADMIN_CONTEXT }), undef, "Return undef for an invalid name of source");

is(pf::authentication::match2("bad_source_name",{ username => 'test', context => $pf::constants::realm::ADMIN_CONTEXT }), undef, "Return undef for an invalid name of source");

is_deeply(
    pf::authentication::match("email", { username => 'user_manager', rule_class => 'authentication', context => $pf::constants::realm::ADMIN_CONTEXT }),
    [
        pf::Authentication::Action->new({
            'value' => 'guest',
            'type'  => 'set_role',
            'class' => 'authentication',
        }),
        pf::Authentication::Action->new({
            'value' => '1D',
            'type'  => 'set_access_duration',
            'class' => 'authentication',
        }),
    ],
    "match all authentication email actions"
);

my $results = pf::authentication::match2("email", { username => 'user_manager', rule_class => 'authentication', context => $pf::constants::realm::ADMIN_CONTEXT });

ok($results, "match2 authentication email actions");

is_deeply(
    $results->{actions},
    [
        pf::Authentication::Action->new({
            'value' => 'guest',
            'type'  => 'set_role',
            'class' => 'authentication',
        }),
        pf::Authentication::Action->new({
            'value' => '1D',
            'type'  => 'set_access_duration',
            'class' => 'authentication',
        }),
    ],
    "match2 all authentication email actions"
);

is($results->{source_id}, "email", "source id matched");

is_deeply(
    pf::authentication::match("email", { username => 'user_manager', rule_class => 'administration', context => $pf::constants::realm::ADMIN_CONTEXT }),
    [
        pf::Authentication::Action->new({
            'value' => '1',
            'type'  => 'mark_as_sponsor',
            'class' => 'administration',
        })
    ],
    "match all administration email actions"
);

my $source_id_ref;
is_deeply(
    pf::authentication::match("htpasswd1", { username => 'user_manager', rule_class => 'administration', context => $pf::constants::realm::ADMIN_CONTEXT }, undef, \$source_id_ref),
    [
        pf::Authentication::Action->new({
            'value' => 'User Manager',
            'type'  => 'set_access_level',
            'class' => 'administration',
        })
    ],
    "match htpasswd1 by username"
);

is($source_id_ref, "htpasswd1", "Source id ref is found");

is( pf::authentication::match(
        [getAuthenticationSource("htpasswd1"), getAuthenticationSource("email")],
        {username => 'user@domain.com', rule_class => 'administration', context => $pf::constants::realm::ADMIN_CONTEXT},
        'mark_as_sponsor'
    ),
    1,
    "Return action in second matching source"
);

is( pf::authentication::match(
        [getAuthenticationSource("htpasswd1"), getAuthenticationSource("email")],
        {username => 'user@domain.com', rule_class => 'administration', context => $pf::constants::realm::ADMIN_CONTEXT},
        'set_access_level'
    ),
    'Violation Manager',
    "Return action in first matching source"
);

is(
    pf::authentication::match("htpasswd1", { username => 'set_access_duration_test', rule_class => 'authentication', context => $pf::constants::realm::ADMIN_CONTEXT }, 'set_access_duration'),undef,
    "No longer match on set_access_duration "
);

is(
    pf::authentication::match("htpasswd1", { username => 'match_on_authentication_class_without_rule_class_test', context => $pf::constants::realm::ADMIN_CONTEXT }, 'set_role'),
    'default',
    "Defaulting to 'authentication' rule class when none is specified while calling match for authentication"
);

is(
    pf::authentication::match("htpasswd1", { username => 'match_on_administration_class_without_rule_class_test', context => $pf::constants::realm::ADMIN_CONTEXT }, 'mark_as_sponsor'),
    undef,
    "Defaulting to 'authentication' rule class when none is specified while calling match for administration"
);

my $value = pf::authentication::match("htpasswd1", { username => 'set_access_duration_test', rule_class => 'authentication', context => $pf::constants::realm::ADMIN_CONTEXT }, 'set_unreg_date');

ok( $value , "set_access_duration matched on set_unreg_date");

ok ( $value =~ /\d{4}-\d\d-\d\d \d\d:\d\d:\d\d/, "Value returned by set_access_duration is a date");

$source_id_ref = undef;

is(pf::authentication::match("htpasswd1", { username => 'set_unreg_date_test', rule_class => 'authentication', context => $pf::constants::realm::ADMIN_CONTEXT }, 'set_unreg_date'),'2022-02-02', "Set unreg date test");

is_deeply(
    pf::authentication::match("tls_all", { username => 'bobbe', SSID => 'tls',
        radius_request => {'TLS-Client-Cert-Serial' => 'tls' }, rule_class => 'authentication', context => $pf::constants::realm::ADMIN_CONTEXT
    }, undef, \$source_id_ref),
    [
        pf::Authentication::Action->new({
            'value' => 'default',
            'type'  => 'set_role',
            'class' => 'authentication',
        }),
        pf::Authentication::Action->new({
            'value' => '12h',
            'type'  => 'set_access_duration',
            'class' => 'authentication',
        })
    ],
    "match tls source rule all conditions"
);

is($source_id_ref, "tls_all", "Source id ref is found");

$source_id_ref = undef;

is_deeply(
    pf::authentication::match("tls_any", { username => 'bobbe', SSID => 'tls',
        radius_request => {'TLS-Client-Cert-Serial' => 'notls' }, rule_class => 'authentication', context => $pf::constants::realm::ADMIN_CONTEXT
    }, undef, \$source_id_ref),
    [
        pf::Authentication::Action->new({
            'value' => 'default',
            'type'  => 'set_role',
            'class' => 'authentication',
        }),
        pf::Authentication::Action->new({
            'value' => '12h',
            'type'  => 'set_access_duration',
            'class' => 'authentication',
        })
    ],
    "match tls_any source rule any conditions"
);

is($source_id_ref, "tls_any", "Source id ref is found");

$source_id_ref = undef;

is_deeply(
    pf::authentication::match("tls_any", { username => 'bobbe', SSID => 'notls',
        radius_request => {'TLS-Client-Cert-Serial' => 'tls' }, rule_class => 'authentication', context => $pf::constants::realm::ADMIN_CONTEXT
    }, undef, \$source_id_ref),
    [
        pf::Authentication::Action->new({
            'value' => 'default',
            'type'  => 'set_role',
            'class' => 'authentication',
        }),
        pf::Authentication::Action->new({
            'value' => '12h',
            'type'  => 'set_access_duration',
            'class' => 'authentication',
        })
    ],
    "match tls_any source rule any conditions"
);

is($source_id_ref, "tls_any", "Source id ref is found");

$source_id_ref = undef;

is(
    pf::authentication::match("tls_any", { username => 'bobbe', SSID => 'notls',
        radius_request => {'TLS-Client-Cert-Serial' => 'notls' }, rule_class => 'authentication', context => $pf::constants::realm::ADMIN_CONTEXT
    }, undef, \$source_id_ref),
    undef,
    "match tls_any source rule any conditions"
);

is($source_id_ref, undef, "Source id ref shouldn't be found");

is_deeply(
    pf::authentication::match("htpasswd1", { username => 'match_action', rule_class => 'administration', context => $pf::constants::realm::ADMIN_CONTEXT }, undef, \$source_id_ref),
    [
        pf::Authentication::Action->new({
            'value' => 'Violation Manager',
            'type'  => 'set_access_level',
            'class' => 'administration',
        })
    ],
    "match first rule htpasswd1 by username with no action"
);

is(
    pf::authentication::match(
        "htpasswd1", {username => 'match_action', rule_class => 'administration', context => $pf::constants::realm::ADMIN_CONTEXT},
        'set_access_level', \$source_id_ref
    ),
    'Violation Manager',
    "match first rule htpasswd1 by username with action"
);

is(
    pf::authentication::match(
        "htpasswd1", {username => 'match_action', rule_class => 'administration', context => $pf::constants::realm::ADMIN_CONTEXT},
        'mark_as_sponsor', \$source_id_ref
    ),
    1,
    "match second rule htpasswd1 by username with action"
);

is(
    pf::authentication::match(
        "htpasswd1",
        {
            current_time_period => 1484846231,
            rule_class          => 'administration',
            username => 'in_time_period',
            context => $pf::constants::realm::ADMIN_CONTEXT,
        },
        'set_access_level',
        \$source_id_ref
    ),
    'Violation Manager',
    "match time period condition ",
);

is($source_id_ref, 'htpasswd1', "Source id ref found");

my @tests = (
    # Stripped username in a non-stripping context to a stripped source
    {
        sources => [ pf::authentication::getAuthenticationSource("htpasswd-stripped") ],
        params => {
            username => 'lzammit',
            password => "test",
            context => $pf::constants::realm::ADMIN_CONTEXT,
        },
        expected_auth => [$TRUE, $AUTH_SUCCESS_MSG],
        expected_match => {set_role => "default", set_unreg_date => "2038-01-01"},
    },
    # Non-stripped username in a non-stripping context to a stripped source
    {
        sources => [ pf::authentication::getAuthenticationSource("htpasswd-stripped") ],
        params => {
            username => 'lzammit@inverse.ca',
            password => "test",
            context => $pf::constants::realm::ADMIN_CONTEXT,
        },
        expected_auth => [$FALSE, $AUTH_FAIL_MSG],
        expected_match => undef,
    },
    # Stripped username in a stripping context to a stripped source
    {
        sources => [ pf::authentication::getAuthenticationSource("htpasswd-stripped") ],
        params => {
            username => 'lzammit',
            password => "test",
            context => $pf::constants::realm::PORTAL_CONTEXT,
        },
        expected_auth => [$TRUE, $AUTH_SUCCESS_MSG],
        expected_match => {set_role => "default", set_unreg_date => "2038-01-01"},
    },
    # Non-stripped username in a stripping context to a stripped source
    {
        sources => [ pf::authentication::getAuthenticationSource("htpasswd-stripped") ],
        params => {
            username => 'lzammit@inverse.ca',
            password => "test",
            context => $pf::constants::realm::PORTAL_CONTEXT,
        },
        expected_auth => [$TRUE, $AUTH_SUCCESS_MSG],
        expected_match => {set_role => "default", set_unreg_date => "2038-01-01"},
    },

    # Stripped username in a non-stripping context to a non-stripped source
    {
        sources => [ pf::authentication::getAuthenticationSource("htpasswd-unstripped") ],
        params => {
            username => 'lzammit',
            password => "test",
            context => $pf::constants::realm::ADMIN_CONTEXT,
        },
        expected_auth => [$FALSE, $AUTH_FAIL_MSG],
        expected_match => undef,
    },
    # Non-stripped username in a non-stripping context to a non-stripped source
    {
        sources => [ pf::authentication::getAuthenticationSource("htpasswd-unstripped") ],
        params => {
            username => 'lzammit@inverse.ca',
            password => "test",
            context => $pf::constants::realm::ADMIN_CONTEXT,
        },
        expected_auth => [$TRUE, $AUTH_SUCCESS_MSG],
        expected_match => {set_role => "default", set_unreg_date => "2038-01-01"},
    },
    # Stripped username in a stripping context to a non-stripped source
    {
        sources => [ pf::authentication::getAuthenticationSource("htpasswd-unstripped") ],
        params => {
            username => 'lzammit',
            password => "test",
            context => $pf::constants::realm::PORTAL_CONTEXT,
        },
        expected_auth => [$FALSE, $AUTH_FAIL_MSG],
        expected_match => undef,
    },
    # Non-stripped username in a stripping context to a non-stripped source
    {
        sources => [ pf::authentication::getAuthenticationSource("htpasswd-unstripped") ],
        params => {
            username => 'lzammit@inverse.ca',
            password => "test",
            context => $pf::constants::realm::PORTAL_CONTEXT,
        },
        expected_auth => [$FALSE, $AUTH_FAIL_MSG],
        expected_match => undef,
    },
);

my $i = 0;
for my $test (@tests) {
    $i++;

    my @sources = exists($test->{sources}) ? @{$test->{sources}} : ();

    my ($res, $msg) = pf::authentication::authenticate($test->{params}, @sources);
    is($res, $test->{expected_auth}->[0], "Test $i authentication result is correct");
    is($msg, $test->{expected_auth}->[1], "Test $i authentication message is correct");

    my $result = pf::authentication::match2([@sources], $test->{params});

    is_deeply($result->{values}, $test->{expected_match}, "Test $i authentication match2 result is correct")


}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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


