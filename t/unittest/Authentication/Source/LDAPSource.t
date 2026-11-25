#!/usr/bin/perl

=head1 NAME

LDAPSource

=cut

=head1 DESCRIPTION

unit test for LDAPSource

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

our (@CACHEABLE_RULES, @NON_CACHEABLE_RULES);

use pf::authentication;

BEGIN {

    @CACHEABLE_RULES = (

        pf::Authentication::Rule->new(
            {
                id         => "No conditions is cachable",
                class      => $Rules::AUTH,
                match      => $Rules::ANY,
                conditions => [],
            }
        ),

        pf::Authentication::Rule->new(
            {
                id         => "Non date related is cachable",
                class      => $Rules::AUTH,
                match      => $Rules::ANY,
                conditions => [
                    pf::Authentication::Condition->new(
                        {
                            attribute => 'bob',
                            operator  => $Conditions::STARTS,
                            value     => 'bob',
                        }
                    )
                ],
            }
        )
    );

    @NON_CACHEABLE_RULES = (

        pf::Authentication::Rule->new(
            {
                id         => "If one condition is a IN_TIME_PERIOD then fail",
                class      => $Rules::AUTH,
                match      => $Rules::ANY,
                conditions => [
                    pf::Authentication::Condition->new(
                        {
                            attribute => 'bob',
                            operator  => $Conditions::IN_TIME_PERIOD,
                            value     => time,
                        }
                    )
                ],
            }
        ),
        pf::Authentication::Rule->new(
            {
                id         => "If one condition is a IS_BEFORE then fail",
                class      => $Rules::AUTH,
                match      => $Rules::ANY,
                conditions => [
                    pf::Authentication::Condition->new(
                        {
                            attribute => 'bob',
                            operator  => $Conditions::IS_BEFORE,
                            value     => time,
                        }
                    )
                ],
            }
        ),
        pf::Authentication::Rule->new(
            {
                id         => "If one condition is a IS_AFTER then fail",
                class      => $Rules::AUTH,
                match      => $Rules::ANY,
                conditions => [
                    pf::Authentication::Condition->new(
                        {
                            attribute => 'bob',
                            operator  => $Conditions::IS_AFTER,
                            value     => time,
                        }
                    )
                ],
            }
        ),

    ),

}

use Test::More tests => 35 + 2 * ( scalar @CACHEABLE_RULES + scalar @NON_CACHEABLE_RULES);

#This test will running last
use Test::NoWarnings;

{
    my $source = getAuthenticationSource('LDAP');
    my $rules = $source->rules;
    is_deeply(
        $source->rule_cache_key($rules->[0], {username => 'bob', SSID => 'james'}, {}),
        ['LDAP', 'Network_Team_Auth' , 'authentication', 'ldap:memberOf,equals,CN=NOC Users,DC=ldap,DC=inverse,DC=caSSID,starts,Network_Team_Auth', 'bob', 'SSID', 'james'],
        'rule cache key',
    );
}

my $source_id = 'LDAPCACHEMATCH';

my $source = getAuthenticationSource($source_id);

ok($source, "Got source id $source_id");

BAIL_OUT("Cannot get $source_id") unless $source;

for my $rule (@CACHEABLE_RULES) {
    ok($source->is_rule_cacheable($rule), $rule->{id});
}

for my $rule (@NON_CACHEABLE_RULES) {
    ok(!$source->is_rule_cacheable($rule), $rule->{id});
}
ok(!$source->is_rule_cacheable(undef), "undef is always uncacheable");

$source_id = 'LDAPCACHEMATCH_OFF';

$source = getAuthenticationSource($source_id);

ok($source, "Got source id $source_id");

BAIL_OUT("Cannot get $source_id") unless $source;

for my $rule (@CACHEABLE_RULES) {
    ok(!$source->is_rule_cacheable($rule), "Cache is disabled no rule can be cached : " . $rule->{id});
}

for my $rule (@NON_CACHEABLE_RULES) {
    ok(!$source->is_rule_cacheable($rule), "Cache is disabled no rule can be cached : " . $rule->{id});
}

ok(!$source->is_rule_cacheable(undef), "undef is always uncacheable");

{
    my $source_id = 'LDAPADVANCED';

    my $source = getAuthenticationSource($source_id);

    ok($source, "Got source id $source_id");

    BAIL_OUT("Cannot get $source_id") unless $source;

    my $rule = $source->rules->[0];

    ok($rule, "Got rule for $source_id");
    my ($filter, $basedn) = $source->ldap_filter_for_conditions($rule->conditions, $rule->match, $source->{usernameattribute}, { username => 'bob', 'radius.username' => "bobette" });
    is(
        $filter,
        '(&(|(cn=bob)(samaccountname=bobette))(|(memberof=student)(memberof=staff)))',
        "Use the advanced filter"
    );

    is ($basedn, undef, "undef basedn");
}

{
    my $source_id = 'LDAPBASEDNSOURCE';

    my $source = getAuthenticationSource($source_id);

    ok($source, "Got source id $source_id");

    BAIL_OUT("Cannot get $source_id") unless $source;

    my $rule = $source->rules->[0];

    ok($rule, "Got rule for $source_id");
    my ($filter, $basedn) = $source->ldap_filter_for_conditions($rule->conditions, $rule->match, $source->{usernameattribute}, { username => 'bob', 'radius.username' => "bobette" });
    is(
        $filter,
        '(user=bob)',
        "basic filter"
    );

    is ($basedn, "CN=IS_Assurance,DC=ldap,DC=inverse,DC=ca", "Condition basedn");
}

{
    my $source_id = 'LDAPADVANCED';
    my $source = getAuthenticationSource($source_id);
    ok($source, "Got source id $source_id");
    my %args = $source->_LDAPArgs();

    is_deeply(
        \%args,
        {
          'read_timeout' => 10,
          'write_timeout' => 5,
          'timeout' => '5',
          'encryption' => 'none',
          'port' => '33389',
          'credentials' => [],
        }
    )
}

{
    my $source_id = 'SSL_ARGS';
    my $source = getAuthenticationSource($source_id);
    ok($source, "Got source id $source_id");
    my %args = $source->_LDAPArgs();
    is_deeply(
        \%args,
        {
          'read_timeout' => 10,
          'write_timeout' => 5,
          'timeout' => '5',
          'encryption' => 'ssl',
          'port' => '33389',
          'credentials' => [],
          'verify' => 'none',
          'clientcert' => '/usr/local/pf/t/server.crt',
          'clientkey' => '/usr/local/pf/t/server.key',
        }
    )
}

{
    my $source_id = 'SSL_ARGS2';
    my $source = getAuthenticationSource($source_id);
    ok($source, "Got source id $source_id");
    my %args = $source->_LDAPArgs();

    is_deeply(
        \%args,
        {
          'read_timeout' => 10,
          'write_timeout' => 5,
          'timeout' => '5',
          'encryption' => 'ssl',
          'port' => '33389',
          'credentials' => [],
          'verify' => 'none',
        }
    )
}

{
    my $source_id = 'TLS_ARGS';
    my $source    = getAuthenticationSource($source_id);
    ok( $source, "Got source id $source_id" );
    my %args = $source->_LDAPArgs();
    is_deeply(
        \%args,
        {
            'read_timeout'      => 10,
            'write_timeout'     => 5,
            'timeout'           => '5',
            'encryption'        => 'starttls',
            'port'              => '33389',
            'credentials'       => [],
            'start_tls_options' => {
                'verify'     => 'none',
                'clientcert' => '/usr/local/pf/t/server.crt',
                'clientkey'  => '/usr/local/pf/t/server.key',
            }
        }
      )
}

{
    my $source_id = 'TLS_ARGS2';
    my $source    = getAuthenticationSource($source_id);
    ok( $source, "Got source id $source_id" );
    my %args = $source->_LDAPArgs();
    is_deeply(
        \%args,
        {
            'read_timeout'      => 10,
            'write_timeout'     => 5,
            'timeout'           => '5',
            'encryption'        => 'starttls',
            'port'              => '33389',
            'credentials'       => [],
            'start_tls_options' => { 
                'verify'            => 'none',
            },
        }
      )
}


# A server name the connector can't resolve is marked dead like a server that
# can't be reached, so the resolver is not asked again on every bind
{
    require pf::factory::connector;
    my $resolves = 0;
    no warnings qw(redefine once);
    local *pf::factory::connector::resolve = sub { $resolves++; return undef };
    my $source = pf::Authentication::Source::LDAPSource->new(
        id => 'ldap_unresolvable', host => ['unresolvable.example.com'], port => 389,
        encryption => 'none', use_connector => 1, dead_duration => 60,
        basedn => 'dc=example,dc=com', binddn => '', password => '', scope => 'sub',
        usernameattribute => 'sAMAccountName',
    );
    my $dead_key = "SERVER_DEAD:ldap_unresolvable:unresolvable.example.com";
    $source->cache->remove($dead_key);
    my ($connection) = $source->_connect();
    ok(!defined $connection, "no connection to a server whose name can't be resolved");
    ok($source->cache->get($dead_key), "the server is marked dead");
    $resolves = 0;
    $source->_connect();
    is($resolves, 1, "the next bind only resolves it in the pass that ignores the dead servers");
    $source->cache->remove($dead_key);
}

# Through a connector the TLS session goes to the dynreverse endpoint: whenever
# the certificate is verified, it must be verified against the configured server
{
    require pf::factory::connector;
    my @calls;
    no warnings qw(redefine once);
    local *pf::factory::connector::resolve = sub { '192.0.2.10' };
    local *pf::factory::connector::for_ip = sub { bless {}, 'LDAPSourceTest::Connector' };
    local *LDAPSourceTest::Connector::dynreverse = sub { { host => 'containers-gateway.internal', port => 40389 } };
    local *pf::LDAP::new = sub { my ($class, $server, %args) = @_; push @calls, [$server, \%args]; undef };
    my $connect = sub {
        my (%attrs) = @_;
        @calls = ();
        my $source = pf::Authentication::Source::LDAPSource->new(
            id => 'ldap_connector_tls', host => ['ldap.example.com'], port => 636,
            use_connector => 1, dead_duration => 0, basedn => 'dc=example,dc=com',
            binddn => '', password => '', scope => 'sub', usernameattribute => 'uid',
            %attrs,
        );
        $source->_connect();
        return $calls[0];
    };

    my $call = $connect->(encryption => 'ssl', verify => 'require');
    is($call->[0], 'containers-gateway.internal', "ssl/require connects to the connector endpoint");
    is($call->[1]{sslserver}, 'ldap.example.com', "ssl/require verifies the configured server");

    $call = $connect->(encryption => 'ssl', verify => 'optional');
    is($call->[1]{sslserver}, 'ldap.example.com', "ssl/optional verifies the configured server");

    $call = $connect->(encryption => 'starttls', verify => 'require');
    is($call->[1]{start_tls_options}{sslserver}, 'ldap.example.com', "starttls/require verifies the configured server");
    is($call->[1]{start_tls_options}{verify}, 'require', "starttls/require keeps the other start_tls options");

    $call = $connect->(encryption => 'starttls', verify => 'optional');
    is($call->[1]{start_tls_options}{sslserver}, 'ldap.example.com', "starttls/optional verifies the configured server");

    $call = $connect->(encryption => 'ssl', verify => 'none');
    ok(!exists $call->[1]{sslserver}, "ssl/none adds no server name");

    $call = $connect->(encryption => 'none', verify => 'require');
    ok(!exists $call->[1]{sslserver} && !exists $call->[1]{start_tls_options}, "no encryption adds no server name");
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
