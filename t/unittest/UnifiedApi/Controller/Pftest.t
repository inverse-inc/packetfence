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

use Test::More tests => 7;
use Test::NoWarnings;

use pf::UnifiedApi::Controller::Pftest;

# Validation: missing user/password -> 422
{
    my $resp = pf::UnifiedApi::Controller::Pftest::_run_authentication(undef, {});
    is($resp->{status}, 422, "missing user+password -> 422");
}

{
    my $resp = pf::UnifiedApi::Controller::Pftest::_run_authentication(undef, { user => 'u' });
    is($resp->{status}, 422, "missing password -> 422");
}

# Validation: bad MAC -> 422
{
    my $resp = pf::UnifiedApi::Controller::Pftest::_run_profile_filter(undef, { mac => 'not-a-mac' });
    is($resp->{status}, 422, "bad MAC -> 422");
}

# Validation: params filter strips non-conforming keys
# (we exercise this via a mocked _spawn so we do not actually fork pftest)
{
    no warnings 'redefine';
    my @captured;
    local *pf::UnifiedApi::Controller::Pftest::_spawn = sub {
        @captured = @_;
        return { status => 200, json => { output => '', output_raw => '', exit_code => 0 } };
    };
    pf::UnifiedApi::Controller::Pftest::_run_profile_filter(undef, {
        mac    => 'aa:bb:cc:dd:ee:ff',
        params => { last_ssid => 'ok', 'bad key with space' => 'x', valid => 'yes' },
    });
    is($captured[0], 'profile_filter', "subcmd forwarded");
    is($captured[1], 'aa:bb:cc:dd:ee:ff', "clean MAC forwarded");
    is_deeply([sort @captured[2..$#captured]],
              [sort 'last_ssid=ok', 'valid=yes'],
              "bad key dropped; good keys forwarded as k=v");
}
