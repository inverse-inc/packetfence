#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib 't';
use lib 'lib';

use Test::More;
use Test::Deep;
use Data::Dumper;
use Data::Compare;

BEGIN {
    use setup_tests qw(-seed);
    use data::seed;
}

use_ok('fingerbank::Source::LocalDB');

my $source = fingerbank::Source::LocalDB->new();

my $args = {
    dhcp_fingerprint => $data::seed::seed_data_ids{Valid_DHCP_Fingerprint}->{value},
    dhcp_vendor => $data::seed::seed_data_ids{Valid_DHCP_Vendor}->{value},
    user_agent => $data::seed::seed_data_ids{Valid_User_Agent}->{value},
    mac_vendor => $data::seed::seed_data_ids{Valid_MAC_Vendor}->{mac},
};

my ($status, $result);

# test exact matching
($status, $result) = $source->match($args);

ok($result->{SCHEMA} eq "Local",
    "Result is coming from the Local schema");

ok($result->{SOURCE} eq "Local",
    "Result is coming from the Local source");

ok($source->{combination_is_exact},
    "Combination exactness is properly detected");

ok($result->{id} eq $data::seed::seed_data_ids{FullMatchCombination}->{id},
    "Result matches the right combination");

ok($result->{device}->{id} eq $data::seed::seed_data_ids{FullMatchCombination}->{device_id},
    "Result matches the right device");

# test matching with a wildcard (L2 on user_agent_id)
$args->{user_agent} = $data::seed::seed_data_ids{UnmatchableUser_Agent}->{value};

# reset the source
$source = fingerbank::Source::LocalDB->new();
($status, $result) = $source->match($args);

ok($result->{SCHEMA} eq "Local",
    "Result is coming from the Local schema");

ok($result->{id} eq $data::seed::seed_data_ids{WildcardMatchCombination}->{id},
    "Result matches the right combination");

ok($result->{device}->{id} eq $data::seed::seed_data_ids{WildcardMatchCombination}->{device_id},
    "Result matches the right device");

ok($source->{combination_is_exact},
    "Combination exactness is properly detected");

# reset the source
$source = fingerbank::Source::LocalDB->new();

# matching with no user agent
delete $args->{user_agent};

($status, $result) = $source->match($args);

ok($result->{SCHEMA} eq "Local",
    "Result is coming from the Local schema");

ok($result->{id} eq $data::seed::seed_data_ids{WildcardMatchCombination}->{id},
    "Result matches the right combination");

ok($result->{device}->{id} eq $data::seed::seed_data_ids{WildcardMatchCombination}->{device_id},
    "Result matches the right device");

ok($source->{combination_is_exact},
    "Combination exactness is properly detected");

# reset the source
$source = fingerbank::Source::LocalDB->new();

# matching with part of the info right
delete $args->{mac_vendor};

($status, $result) = $source->match($args);

ok($result->{SCHEMA} eq "Local",
    "Result is coming from the Local schema");

ok($result->{id} eq $data::seed::seed_data_ids{WildcardMatchCombination}->{id},
    "Result matches the right combination");

ok($result->{device}->{id} eq $data::seed::seed_data_ids{WildcardMatchCombination}->{device_id},
    "Result matches the right device");

ok(!$source->{combination_is_exact},
    "Combination non-exactness is properly detected");

done_testing();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

