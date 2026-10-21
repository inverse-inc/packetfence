#!/usr/bin/perl

=head1 NAME

ldap-auth-filter-bitwise

=cut

=head1 DESCRIPTION

Unit tests for the AD-specific "has bit" / "not has bit" condition operators
in pf::Authentication::Source::LDAPSource::ldap_filter_for_conditions.

The bitwise operators emit a filter based on the LDAP_MATCHING_RULE_BIT_AND
extensible match OID (1.2.840.113556.1.4.803). These tests assert the exact
filter string produced, including parenthesis grouping and negation placement,
so regressions in the generator are caught without needing a live LDAP server.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 5;
use Test::NoWarnings;

use pf::authentication;
use pf::Authentication::Condition;
use pf::Authentication::constants;
use pf::constants::realm;

my $source = getAuthenticationSource('LDAP0');
isa_ok($source, 'pf::Authentication::Source::LDAPSource');

my $params = {
    username => 'bob',
    context  => $pf::constants::realm::ADMIN_CONTEXT,
};

# userAccountControl bit 2 = ACCOUNTDISABLE (disabled account in AD).
my $has_bit = pf::Authentication::Condition->new({
    attribute => 'userAccountControl',
    operator  => $Conditions::HAS_BIT,
    value     => '2',
});

my $not_has_bit = pf::Authentication::Condition->new({
    attribute => 'userAccountControl',
    operator  => $Conditions::NOT_HAS_BIT,
    value     => '2',
});

{
    my ($filter) = $source->ldap_filter_for_conditions(
        [$has_bit], $Rules::ANY, $source->{usernameattribute}, $params,
    );
    is(
        $filter,
        '(&(user=bob)(userAccountControl:1.2.840.113556.1.4.803:=2))',
        'has bit produces AD bitwise-AND extensible match filter',
    );
}

{
    my ($filter) = $source->ldap_filter_for_conditions(
        [$not_has_bit], $Rules::ANY, $source->{usernameattribute}, $params,
    );
    is(
        $filter,
        '(&(user=bob)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))',
        'not has bit wraps the extensible match in a negation',
    );
}

# Two bitwise conditions with match=any exercise the logical OR grouping
# around the extensible matches while keeping the negation intact.
{
    my $has_trust = pf::Authentication::Condition->new({
        attribute => 'userAccountControl',
        operator  => $Conditions::HAS_BIT,
        value     => '8192',
    });

    my ($filter) = $source->ldap_filter_for_conditions(
        [$has_trust, $not_has_bit], $Rules::ANY,
        $source->{usernameattribute}, $params,
    );
    is(
        $filter,
        '(&(user=bob)(|(userAccountControl:1.2.840.113556.1.4.803:=8192)(!(userAccountControl:1.2.840.113556.1.4.803:=2))))',
        'combining has bit and not has bit groups under logical OR with match=any',
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
