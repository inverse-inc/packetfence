#!/usr/bin/perl

=head1 NAME

Pftest

=head1 DESCRIPTION

unit test for pf::UnifiedApi::Controller::Pftest

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 11;
use Test::NoWarnings;

use pf::UnifiedApi::Controller::Pftest;

# Validation: missing user -> 422
{
    my $resp = pf::UnifiedApi::Controller::Pftest::run_authentication({});
    is($resp->{status}, 422, "missing user -> 422");
}

# Password is optional by design (probes fail-closed sources); the runner
# must forward an empty string rather than reject the request.
{
    no warnings 'redefine';
    my @captured;
    local *pf::UnifiedApi::Controller::Pftest::_invoke = sub {
        @captured = @_;
        return { status => 200, json => { output => '', output_raw => '', exit_code => 0 } };
    };
    my $resp = pf::UnifiedApi::Controller::Pftest::run_authentication({ user => 'u' });
    is($resp->{status}, 200, "user without password accepted");
    is_deeply(\@captured, ['authentication', 'u', ''], "empty password forwarded");
}

# Validation: bad MAC -> 422
{
    my $resp = pf::UnifiedApi::Controller::Pftest::run_profile_filter({ mac => 'not-a-mac' });
    is($resp->{status}, 422, "bad MAC -> 422");
}

# Validation: params filter strips non-conforming keys
# (we exercise this via a mocked _invoke so we do not actually run pftest)
{
    no warnings 'redefine';
    my @captured;
    local *pf::UnifiedApi::Controller::Pftest::_invoke = sub {
        @captured = @_;
        return { status => 200, json => { output => '', output_raw => '', exit_code => 0 } };
    };
    pf::UnifiedApi::Controller::Pftest::run_profile_filter({
        mac    => 'aa:bb:cc:dd:ee:ff',
        params => { last_ssid => 'ok', 'bad key with space' => 'x', valid => 'yes' },
    });
    is($captured[0], 'profile_filter', "subcmd forwarded");
    is($captured[1], 'aa:bb:cc:dd:ee:ff', "clean MAC forwarded");
    is_deeply([sort @captured[2..$#captured]],
              [sort 'last_ssid=ok', 'valid=yes'],
              "bad key dropped; good keys forwarded as k=v");
}

# _invoke refuses subcommands outside the allow-list
{
    my $resp = pf::UnifiedApi::Controller::Pftest::_invoke('locationlog');
    is($resp->{status}, 422, "non-allow-listed subcommand -> 422");
}

# Rate limit: a second authentication run for the same tested user inside
# the window must be rejected. Unique user per test run — the cache
# persists across consecutive prove invocations.
{
    my $user = "rate-limit-test-$$-" . time();
    ok(!pf::UnifiedApi::Controller::Pftest::auth_rate_limit_exceeded($user),
        "first run for a user is allowed");
    ok(pf::UnifiedApi::Controller::Pftest::auth_rate_limit_exceeded($user),
        "second run within the window is rejected");
}
