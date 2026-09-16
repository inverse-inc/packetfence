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

use Test::More tests => 21;
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
my $starved = plan_for(tenants => 100_000);
is($starved->{small}, 2, "min_per_tier floors a tier that would otherwise round to zero");
cmp_ok((sort { $a <=> $b } values %$starved)[0], '>=', 2, "no tier ever drops below the floor");

my $zero_weight = pf::services::manager::proxysql::compute_tier_connections(
    { db_max_connections => 4000, tenants => 120, reserve_pct => 20, min_per_tier => 2 },
    {},
);
is_deeply($zero_weight, {}, "no weights yields no tiers rather than dividing by zero");

# On-prem: the database is the one PacketFence configures itself, so the ceiling
# is database_advanced.max_connections and this instance is its only user.
my $onprem = plan_for(db_max_connections => 1000, tenants => 1);
is(total_of($onprem), 800, "on-prem: 1000 ceiling less 20% reserved, all of it for one instance");
is($onprem->{large},  334, "on-prem: large tier");
is($onprem->{medium}, 200, "on-prem: medium tier");
cmp_ok(total_of($onprem), '<', 1000, "on-prem: the plan stays under what the local server accepts");

# The ceiling tracks the setting rather than assuming the 1000 default.
my $onprem_2k = plan_for(db_max_connections => 2000, tenants => 1);
is(total_of($onprem_2k), 1600, "on-prem: raising max_connections raises the budget with it");
