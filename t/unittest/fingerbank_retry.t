#!/usr/bin/perl

=head1 NAME

fingerbank_retry

=head1 DESCRIPTION

Retries of pf::fingerbank::process after a failed lookup

=cut

use strict;
use warnings;
# pf core libs
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 15;
use Test::MockModule;
use Test::NoWarnings;
use DateTime;
use pf::fingerbank;
use pf::constants::fingerbank qw($MAX_RETRIES);

my $mac = '00:11:22:33:55:46';

my @queued;
my $queue = Test::MockModule->new('pf::api::queue');
$queue->mock('notify_delayed', sub { my ($self, @args) = @_; push @queued, \@args; return });

my $fb_config = Test::MockModule->new('fingerbank::Config');
$fb_config->mock('is_api_key_configured', sub { 1 });

my $query_ok = 0;
my $queries = 0;
my $recorded = 0;
my $fingerbank = Test::MockModule->new('pf::fingerbank');
$fingerbank->mock('endpoint_attributes', sub {
    return { dhcp_fingerprint => '1,3,6,15', last_updated => DateTime->now(time_zone => 'local')->subtract(hours => 1) };
});
$fingerbank->mock('_query', sub {
    $queries++;
    return undef unless $query_ok;
    return { device => { id => 33, name => 'Debian', parents => [ { id => 5, name => 'Linux OS' } ] }, score => 50 };
});
$fingerbank->mock('find_device_class', sub { $_[0] });
$fingerbank->mock('record_result', sub { $recorded++ });
$fingerbank->mock('node_attributes', sub { { mac => $mac } });
$fingerbank->mock('check_device_class_change', sub { });
$fingerbank->mock('_trigger_new_dhcp_security_event', sub { });

my $cache = pf::fingerbank::cache();
my $query_cache_key = "fingerbank::_query-" . pf::fingerbank::_query_cache_key({ dhcp_fingerprint => '1,3,6,15', mac => $mac });
$cache->remove($_) for ("pf::fingerbank::process($mac)", pf::fingerbank::_retry_cache_key($mac), $query_cache_key);

# First lookup fails: a retry is scheduled
ok(!pf::fingerbank::process($mac, undef, { hostname => 'host1' }), 'failed lookup returns false');
is(scalar @queued, 1, 'a retry is scheduled');
is_deeply([ @{ $queued[0] }[1, 2, 3] ], [ 'fingerbank_process', $mac, { hostname => 'host1' } ], 'the retry processes the same device with the same attributes');
is($cache->get(pf::fingerbank::_retry_cache_key($mac)), 1, 'one retry counted');

# The retry is not skipped although the collector has no new data, and the failure is not served from the cache
$query_ok = 1;
$queries = 0;
ok(pf::fingerbank::process($mac, undef, { hostname => 'host1' }), 'retry succeeds');
is($queries, 1, 'retry queried Fingerbank again');
is($recorded, 1, 'result recorded');
ok(!defined($cache->get(pf::fingerbank::_retry_cache_key($mac))), 'retry counter cleared after success');
is(scalar @queued, 1, 'no new retry after success');

# Without new data, the next process is skipped as before
$queries = 0;
ok(pf::fingerbank::process($mac), 'next process without new data');
is($queries, 0, 'no query without new data');

# Retries are bounded
$query_ok = 0;
@queued = ();
$cache->remove("pf::fingerbank::process($mac)");
# Drop the successful result kept by the rate limiting cache
$cache->remove($query_cache_key);
for (1 .. $MAX_RETRIES + 1) {
    pf::fingerbank::process($mac);
}
is(scalar @queued, $MAX_RETRIES, "at most $MAX_RETRIES retries in a row");
ok(!defined($cache->get(pf::fingerbank::_retry_cache_key($mac))), 'retry counter reset after giving up');

$cache->remove("pf::fingerbank::process($mac)");

# Failure to fetch the attributes from the collector also schedules a retry
@queued = ();
$fingerbank->mock('endpoint_attributes', sub { undef });
pf::fingerbank::process($mac);
is(scalar @queued, 1, 'collector failure schedules a retry');
$cache->remove($_) for ("pf::fingerbank::process($mac)", pf::fingerbank::_retry_cache_key($mac), $query_cache_key);

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
