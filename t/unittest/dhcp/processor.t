#!/usr/bin/perl

=head1 NAME

processor

=head1 DESCRIPTION

unit test for pf::dhcp::processor

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

use Test::More tests => 9;

#Test no warnings will run last
use Test::NoWarnings;
use pf::dhcp::processor;

{
    package FakeClient;
    sub new { bless { notified => [] }, shift }
    sub notify { my ($self, $method, @args) = @_; push @{$self->{notified}}, [$method, @args] }
    sub count { scalar @{$_[0]->{notified}} }
}

{
    # No DHCP filter rule matches: processFingerbank must reach its own gate
    package FakeFilterEngine;
    sub new { bless {}, shift }
    sub filter { {} }
}

# processFingerbank: fingerbank_process is enqueued when the device's DHCP
# signature changes, and when the node was deleted and recreated since the last
# packet, even with the very same signature.
{
    no warnings qw(redefine once);
    my %nodes;
    local *pf::dhcp::processor::node_attributes = sub { $nodes{$_[0]} };

    my $client = FakeClient->new;
    my $processor = pf::dhcp::processor->new(apiClient => $client, filterEngine => FakeFilterEngine->new);

    my $mac = sprintf("00:11:22:33:%02x:%02x", $$ % 256, int($$ / 256) % 256);
    my %request = (
        client_mac             => $mac,
        ipv4_requested_options => '1,3,6,15,31,33,43,44,46,47,119,121,249,252',
        ipv4_vendor            => 'MSFT 5.0',
        client_hostname        => 'laptop',
    );

    $nodes{$mac} = { mac => $mac, detect_date => '2026-10-30 10:00:00' };
    $processor->processFingerbank({ %request });
    is($client->count, 1, "the first DHCP packet of a node triggers fingerbank_process");
    is($client->{notified}[0][0], 'fingerbank_process', "the task is fingerbank_process");
    is($client->{notified}[0][1], $mac, "for the node's MAC");
    is_deeply(
        $client->{notified}[0][2],
        { hostname => 'laptop', dhcp_fingerprint => $request{ipv4_requested_options}, dhcp_vendor => 'MSFT 5.0' },
        "with the attributes parsed from the packet"
    );

    $processor->processFingerbank({ %request });
    is($client->count, 1, "a renewal with the same signature is suppressed");

    # The node is deleted and reconnects: the recreated node carries a new detect_date
    $nodes{$mac} = { mac => $mac, detect_date => '2026-10-30 10:05:00' };
    $processor->processFingerbank({ %request });
    is($client->count, 2, "a node recreated since the last packet is profiled again, with the same signature");

    $processor->processFingerbank({ %request });
    is($client->count, 2, "then its renewals are suppressed again");

    $processor->processFingerbank({ %request, client_hostname => 'renamed' });
    is($client->count, 3, "a signature change (hostname) still triggers fingerbank_process");
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
