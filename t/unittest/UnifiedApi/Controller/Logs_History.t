#!/usr/bin/perl

=head1 NAME

Logs_History

=head1 DESCRIPTION

unit test for pf::UnifiedApi::Controller::Logs::History helpers

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 12;
use Test::NoWarnings;

use pf::UnifiedApi::Controller::Logs::History;

my $C = 'pf::UnifiedApi::Controller::Logs::History';

# --- _iso_to_ms -------------------------------------------------------------

is(pf::UnifiedApi::Controller::Logs::History::_iso_to_ms(undef),          undef, "undef -> undef");
is(pf::UnifiedApi::Controller::Logs::History::_iso_to_ms(''),             undef, "empty -> undef");
is(pf::UnifiedApi::Controller::Logs::History::_iso_to_ms('not-a-date'),   undef, "garbage -> undef");

# 2026-06-01T00:00:00Z == 1780617600 epoch
is(pf::UnifiedApi::Controller::Logs::History::_iso_to_ms('2026-06-01T00:00:00Z'),
    1780617600 * 1000,
    "Z timezone parsed");

# +02:00 offset shifts the epoch by -2h to land on the same UTC instant.
is(pf::UnifiedApi::Controller::Logs::History::_iso_to_ms('2026-06-01T02:00:00+02:00'),
    1780617600 * 1000,
    "+02:00 offset parsed");

is(pf::UnifiedApi::Controller::Logs::History::_iso_to_ms('2026-06-01T00:00:00.123456Z'),
    1780617600 * 1000 + 123,
    "microsecond fraction clipped to ms");

# --- _parse_line ------------------------------------------------------------

my $line = '2026-06-01T02:36:06.330130+02:00 packetfence1 pfperl-api-docker-wrapper[78580]: pfperl-api(11) INFO: hello world';
my $m = pf::UnifiedApi::Controller::Logs::History::_parse_line($line, 'packetfence.log');
is($m->{hostname},  'packetfence1',                "hostname parsed");
is($m->{process},   'pfperl-api-docker-wrapper',   "process parsed (PID stripped)");
is($m->{log_level}, 'INFO',                        "log_level extracted from message body");
ok(defined $m->{timestamp_ms},                     "timestamp_ms set");

# Apache-style line: process with dotted name.
my $apache = '2026-06-01T19:32:06.051494+02:00 packetfence1 api-frontend-docker-wrapper[62826]: api-frontend-access 100.64.0.1 - - [01/Jun/2026:17:32:06 +0000] "POST /api/v1/login HTTP/1.1" 200 76 "-" "Go-http-client/1.1"';
my $am = pf::UnifiedApi::Controller::Logs::History::_parse_line($apache, 'httpd.apache');
is($am->{process},  'api-frontend-docker-wrapper', "apache-line process parsed");
