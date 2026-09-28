#!/usr/bin/perl

=head1 NAME

LDAPSource_search_memo

=head1 DESCRIPTION

unit test for the per-request search memo of pf::Authentication::Source::LDAPSource:
rules whose conditions are not part of the LDAP filter (matches regexp) must share
the result of the username lookup instead of one search per rule (#9273)

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

use Test::More tests => 13;
use Test::NoWarnings;

use pf::authentication;
use pf::Authentication::constants;
use pf::Authentication::Rule;
use pf::Authentication::Condition;
use pf::Authentication::Action;

# A Net::LDAP stand-in: every search returns the same single entry and counts calls
{
    package FakeLDAPEntry;
    sub new { my ($class, %attrs) = @_; return bless {%attrs}, $class }
    sub dn { 'CN=bob,DC=ldap,DC=inverse,DC=ca' }
    sub get_value { my ($self, $attr) = @_; return @{ $self->{$attr} // [] } }

    package FakeLDAPResult;
    sub new { my ($class, @entries) = @_; return bless { entries => [@entries] }, $class }
    sub is_error { 0 }
    sub error { '' }
    sub count { scalar @{ $_[0]{entries} } }
    sub entries { @{ $_[0]{entries} } }
    sub pop_entry { pop @{ $_[0]{entries} } }

    package FakeLDAP;
    our $SEARCHES = 0;
    sub new { return bless {}, shift }
    sub search {
        my ($self, %args) = @_;
        $SEARCHES++;
        return FakeLDAPResult->new(FakeLDAPEntry->new(memberOf => ['CN=B_VLAN_103,OU=Units,DC=ldap,DC=inverse,DC=ca']));
    }
}

my $source = getAuthenticationSource('LDAP');
ok($source, "Got the LDAP source");

no warnings 'redefine';
local *pf::Authentication::Source::LDAPSource::_connect = sub { return (FakeLDAP->new, 'ldap.test', 389) };
use warnings 'redefine';

my @rules = map {
    my $vlan = $_;
    pf::Authentication::Rule->new({
        id         => "VLAN_$vlan",
        class      => $Rules::AUTH,
        match      => $Rules::ALL,
        conditions => [
            pf::Authentication::Condition->new({
                attribute => 'memberOf',
                operator  => $Conditions::MATCHES,
                value     => "VLAN_$vlan",
                type      => $Conditions::LDAP_ATTRIBUTE,
            }),
        ],
        actions => [
            pf::Authentication::Action->new({ type => $Actions::SET_ROLE, class => $Rules::AUTH, value => "VLAN_$vlan" }),
        ],
    })
} (101, 102, 103);
$source->rules(\@rules);
$source->cache_match(0);

$FakeLDAP::SEARCHES = 0;
my ($rule, $ignore, $entry) = $source->match({ username => 'bob', rule_class => $Rules::AUTH });
ok($rule, "A rule matched");
is($rule->id, 'VLAN_103', "The third rule (regexp on the group) matched");
is($FakeLDAP::SEARCHES, 1, "One LDAP search served all three rules of the request");
ok(!defined $source->_search_memo, "The memo is dropped once the match is over");
ok(!defined $source->_cached_connection, "The connection is released once the match is over");

# A new request must not reuse the previous request's entries
$FakeLDAP::SEARCHES = 0;
($rule) = $source->match({ username => 'bob', rule_class => $Rules::AUTH });
is($rule->id, 'VLAN_103', "The third rule matched again");
is($FakeLDAP::SEARCHES, 1, "A new request runs its own search");

# Rules asking for different attributes get their own search
$FakeLDAP::SEARCHES = 0;
$rules[0]->conditions([
    pf::Authentication::Condition->new({
        attribute => 'department',
        operator  => $Conditions::MATCHES,
        value     => 'Network',
        type      => $Conditions::LDAP_ATTRIBUTE,
    }),
]);
($rule) = $source->match({ username => 'bob', rule_class => $Rules::AUTH });
is($rule->id, 'VLAN_103', "Still the third rule");
is($FakeLDAP::SEARCHES, 2, "A different attribute list is a different search, the other rules still share one");

# No match at all still costs a single search
$FakeLDAP::SEARCHES = 0;
$_->conditions([
    pf::Authentication::Condition->new({
        attribute => 'memberOf',
        operator  => $Conditions::MATCHES,
        value     => 'NOPE',
        type      => $Conditions::LDAP_ATTRIBUTE,
    }),
]) for @rules;
($rule) = $source->match({ username => 'bob', rule_class => $Rules::AUTH });
ok(!defined $rule, "No rule matched");
is($FakeLDAP::SEARCHES, 1, "Three non-matching regexp rules cost one search");

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
