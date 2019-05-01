#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use test_paths;
    use setup_test_config;
    use pf::log;
}

use Test::More;
use Test::Deep;
use Config::IniFiles;

use_ok('pf::accounting_events_history');

my $history = pf::accounting_events_history->new();
$history->flush_all();

my $mac = "00:11:22:33:44:55";

ok(!defined($history->latest_mac_history($mac)), "Undefined result when fetching on empty history");

my $h = $history->get_new_history_hash();

$history->add_to_history_hash($h, $mac, "TOT5BM");

ok(!defined($history->latest_mac_history($mac)), "Data doesn't exist before its commited");

$history->commit($h, 3600);

ok(${$history->latest_mac_history($mac)}[0] eq 'TOT5BM', "Right result when fetching history");

$h = $history->get_new_history_hash();

$history->add_to_history_hash($h, $mac, "TOT10BM");

ok(${$history->latest_mac_history($mac)}[0] eq "TOT5BM", "Previous historical is provided before new data is commited");

ok(${$history->latest_mac_history($mac)}[0] ne "TOT10BM", "New historical data isn't there before its commited");

$history->commit($h, 3600);

ok(${$history->latest_mac_history($mac)}[0] ne "TOT5BM", "Previous historical isn't there anymore after new one is commited");

ok(${$history->latest_mac_history($mac)}[0] eq "TOT10BM", "New historical data is there after its commited");

$history->flush_all();

ok(!defined($history->latest_mac_history($mac)), "Undefined result when fetching on flushed history");
done_testing();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

