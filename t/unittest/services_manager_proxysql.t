#!/usr/bin/perl

=head1 NAME

services_manager_proxysql

=head1 DESCRIPTION

unit test for the ProxySQL capacity planner

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/lib);
    use lib qw(/usr/local/pf/lib_perl/lib/perl5);
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 68;
use Test::NoWarnings;

use pf::services::manager::proxysql;

my %weights = ( small => 2, radius => 2, medium => 3, large => 5 );

sub plan_for {
    my (%override) = @_;
    my %capacity = (
        db_max_connections => 4000,
        tenants            => 120,
        reserve_pct        => 20,
        min_per_tier       => 2,
        %override,
    );
    return pf::services::manager::proxysql::compute_tier_connections(\%capacity, \%weights);
}

sub total_of {
    my ($plan) = @_;
    my $t = 0;
    $t += $_ for values %$plan;
    return $t;
}

# The values shipped in generateConfig.
my $plan = plan_for();
is($plan->{small},  4,  "default plan: catch-all tier");
is($plan->{radius}, 4,  "default plan: radius tier");
is($plan->{medium}, 6,  "default plan: medium tier");
is($plan->{large},  12, "default plan: large tier gets the rounding remainder");
is(total_of($plan), 26, "tiers add up to the per-tenant budget, nothing lost to rounding");

# The whole point of the knobs: changing an input changes the output.
my $tighter = plan_for(tenants => 240);
ok(total_of($tighter) < total_of($plan), "doubling the tenant count shrinks each tenant's budget");
is(total_of($tighter), 13, "3200 usable / 240 tenants = 13 per tenant");

my $bigger = plan_for(db_max_connections => 8000);
is(total_of($bigger), 53, "a larger ceiling raises the budget (6400/120)");

my $stingier = plan_for(reserve_pct => 50);
is(total_of($stingier), 16, "reserving more leaves less to divide (2000/120)");

# The fleet must fit inside the ceiling it was derived from.
cmp_ok(total_of($plan) * 120, '<=', 4000,
    "the whole fleet fits under the ceiling if every tenant maxes out at once");

# Ordering is what the tier design depends on.
cmp_ok($plan->{large}, '>', $plan->{medium}, "large tier outranks medium");
cmp_ok($plan->{medium}, '>', $plan->{small}, "medium tier outranks catch-all");

# Edge cases.
my $tight = plan_for(tenants => 400);
is(total_of($tight), 8, "a budget that exactly seats every tier at the floor is still honoured");
cmp_ok((sort { $a <=> $b } values %$tight)[0], '>=', 2, "no tier drops below the floor");

my $starved = plan_for(tenants => 100_000);
is_deeply($starved, {}, "a budget too small to seat every tier at the floor yields no plan");

# The floor must never push the tiers past the budget: that would hand back a
# plan adding up to more than the database allows.
for my $tenants (1, 50, 120, 200, 300, 399, 400, 401, 500, 1000) {
    my $plan = plan_for(tenants => $tenants);
    next unless keys %$plan;
    my $budget = int(int(4000 * 80 / 100) / $tenants);
    cmp_ok(total_of($plan), '<=', $budget, "tenants=$tenants: tiers stay within the budget")
        or diag("plan: " . join(', ', map { "$_=$plan->{$_}" } sort keys %$plan));
}

my $zero_weight = pf::services::manager::proxysql::compute_tier_connections(
    { db_max_connections => 4000, tenants => 120, reserve_pct => 20, min_per_tier => 2 },
    {},
);
is_deeply($zero_weight, {}, "no weights yields no tiers rather than dividing by zero");

# tier_budget is the single source of the arithmetic the generated file prints.
my ($usable, $budget) = pf::services::manager::proxysql::tier_budget(
    { db_max_connections => 4000, tenants => 120, reserve_pct => 20 });
is($usable, 3200, "tier_budget: usable is the ceiling less the reserve");
is($budget, 26,   "tier_budget: budget is one tenant's share of it");
is(total_of($plan), $budget, "the plan splits exactly the budget tier_budget reports");

# Routing: which rule each statement lands in. ProxySQL evaluates the rules in
# order (large, medium, radius, pfcron, catch-all) with the CASELESS modifier.
# 'pfcron' is the catch-all hostgroup with the long timeout.
my $patterns = pf::services::manager::proxysql::tier_route_patterns();
sub tier_of {
    my ($sql) = @_;
    for my $tier (qw(large medium radius pfcron)) {
        return $tier if $sql =~ /$patterns->{$tier}/i;
    }
    return 'small';
}

my @routes = (
    # the auth hot path
    [ '/* pf:httpd.aaa */ SELECT * FROM node WHERE mac = ?',                 'large',  'httpd.aaa' ],
    [ '/* pf:httpd.aaa */ SELECT value, expires_at FROM chi_cache WHERE `key` = ?',
                                                                             'large',  'chi_cache read from httpd.aaa (decorated through pf::CHI::db)' ],
    [ '/* pf:pfacct */ UPDATE radacct SET acctstoptime = NOW()',             'large',  'pfacct' ],
    [ '/* pf:pfconfig */ SELECT value FROM keyed WHERE id = ?',              'large',  'pfconfig keyed read' ],
    [ '/* pf:pfacct:bandwidth */ SELECT 1',                                   'large',  'pfacct with a unit' ],
    # frontend and API
    [ '/* pf:pfhttpd */ SELECT 1',                                            'medium', 'pfhttpd' ],
    [ '/* pf:pfperl-api */ SELECT 1',                                         'medium', 'pfperl-api' ],
    [ '/* pf:httpd.webservices */ SELECT 1',                                  'medium', 'httpd.webservices' ],
    [ '/* pf:pfqueue:api */ SELECT 1',                                        'medium', 'pfqueue api tasks (sbin/pfqueue-backend stamps pf_unit with the task type)' ],
    [ '/* pf:pfhttpd2 */ SELECT 1',                                           'small',  'no prefix collision: pfhttpd2 is not pfhttpd' ],
    [ '/* pf:httpdXaaa */ SELECT 1',                                          'small',  'the dot in httpd.aaa is literal' ],
    [ '/* pf:pfconfigurator */ SELECT 1',                                     'small',  'no prefix collision: pfconfigurator is not pfconfig' ],
    [ '/* pf:pfqueue:populate_ntlm_redis_cache */ SELECT 1',                  'small',  'non-API pfqueue tasks stay in the catch-all' ],
    # FreeRADIUS rlm_sql (undecorated)
    [ "CALL acct_start ('a', 'b')",                                           'radius', 'rlm_sql accounting start' ],
    [ "          CALL acct_update ( \n FROM_UNIXTIME(1) )",                    'radius', 'rlm_sql interim update, leading whitespace and newlines' ],
    [ "CALL acct_stop ('a')",                                                 'radius', 'rlm_sql accounting stop' ],
    [ "UPDATE radacct SET acctstoptime = FROM_UNIXTIME(1) WHERE 1",           'radius', 'rlm_sql accounting-on' ],
    [ "INSERT INTO radacct (acctsessionid) VALUES ('Gi1/0/1')",               'radius', 'rlm_sql alternate insert, with a slash in a value' ],
    [ "INSERT INTO radius_audit_log (mac) VALUES ('aa')",                     'radius', 'rlm_sql post-auth audit log' ],
    [ "SELECT id, nasname FROM radius_nas where 1=0",                         'radius', 'rlm_sql client_query' ],
    [ "SELECT 1, pid, (\n CASE WHEN 1 THEN 'x' END ) AS passwordhash FROM password JOIN activation using (pid) WHERE pid = 'u'",
                                                                             'radius', 'rlm_sql guest/local authorize_check_query' ],
    # maintenance and undecorated scripts must not take RADIUS connections
    [ '/* pf:pfcron:acct_cleanup */ DELETE FROM radacct WHERE acctstoptime < ? LIMIT 100',
                                                                             'pfcron', 'decorated pfcron cleanup of radacct: catch-all, long timeout' ],
    [ '/* pf:pfcron */ SELECT * FROM radacct',                                'pfcron', 'decorated SELECT on radacct keeps its own route' ],
    [ '/* pf:pfcronX */ SELECT 1',                                            'small',  'no prefix collision: pfcronX is not pfcron' ],
    [ 'ALTER TABLE radacct ADD COLUMN x INT',                                  'small',  'undecorated ALTER on radacct' ],
    [ 'DELETE FROM radacct WHERE 1',                                          'small',  'undecorated DELETE on radacct' ],
    [ 'SELECT password FROM password WHERE pid = 1',                          'small',  'undecorated password lookup without the rlm_sql join' ],
    [ 'START TRANSACTION',                                                    'small',  'undecorated BEGIN (driver without the wrapper)' ],
    # go/db/sqlcomment decorates BEGIN, so a transaction is opened in its caller's tier
    [ '/* pf:pfhttpd */ START TRANSACTION',                                   'medium', 'Go BEGIN from pfhttpd' ],
    [ '/* pf:pfacct */ START TRANSACTION READ ONLY',                          'large',  'Go read-only BEGIN from pfacct' ],
);
is(tier_of($_->[0]), $_->[1], "route: $_->[2] -> $_->[1]") for @routes;

# The template guard: placeholder present and rules rendered for a single server.
{
    use File::Temp qw(tempfile);
    my $guard = sub {
        my ($body) = @_;
        my ($fh, $path) = tempfile(UNLINK => 1);
        print $fh $body;
        close $fh;
        return pf::services::manager::proxysql::template_has_tier_placeholders($path);
    };
    my $vars  = "mysql_variables = {\n[% mysql_cloud_variables %]\n}\n";
    ok($guard->($vars . "[% mysql_query_rules %]\n"),
        "template guard: accepts the shipped layout");
    ok(!$guard->("[% mysql_query_rules %]\n"),
        "template guard: rejects a template without mysql_cloud_variables");
    ok(!$guard->($vars . "[% UNLESS single_server %]\n[% mysql_query_rules %]\n[% END %]\n"),
        "template guard: rejects rules still inside UNLESS single_server");
    ok(!$guard->($vars . "[% UNLESS single_server %]\n[% IF x %]y[% END %]\n[% mysql_query_rules %]\n[% END %]\n"),
        "template guard: rejects rules under UNLESS single_server past a nested block");
    ok($guard->($vars . "[% UNLESS single_server %]x[% END %]\n[% mysql_query_rules %]\n"),
        "template guard: accepts rules after a closed UNLESS single_server");
    ok(!$guard->($vars),
        "template guard: rejects a template without the rules placeholder");
    ok(pf::services::manager::proxysql::template_has_tier_placeholders('/usr/local/pf/conf/proxysql.conf.example'),
        "template guard: accepts the shipped conf/proxysql.conf.example");
}

# The handle subclass that carries the remark (used by pf::db, pf::CHI::db and
# pfconfig::backend::mysql).
use pf::db::dbi;
{
    local $0 = '/usr/local/pf/sbin/pfconfig';
    Log::Log4perl::MDC->remove('proc');
    Log::Log4perl::MDC->remove('pf_unit');
    is(pf::db::dbi::decorate_statement('SELECT 1'), '/* pf:pfconfig */ SELECT 1',
        "decorate_statement: falls back to basename(\$0) for the service");
    is(pf::db::dbi::decorate_statement('/* pf:x */ SELECT 1'), '/* pf:x */ SELECT 1',
        "decorate_statement: an already decorated statement is left alone");
    Log::Log4perl::MDC->put('proc', 'httpd.aaa');
    is(pf::db::dbi::decorate_statement('SELECT 1'), '/* pf:httpd.aaa */ SELECT 1',
        "decorate_statement: uses the proc MDC when set");
    Log::Log4perl::MDC->remove('proc');
}
ok(pf::db::dbi::db->can('prepare_cached') == \&pf::db::dbi::db::prepare_cached,
    "the db handle subclass overrides prepare_cached (used by CHI::Driver::DBI)");
