#!/usr/bin/perl

=head1 NAME

fingerbank

=cut

=head1 DESCRIPTION

fingerbank

=cut

use strict;
use warnings;
# pf core libs
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 26;

use Test::NoWarnings;
use Test::Exception;
use Test::MockModule;
use HTTP::Response;
use pf::config qw(%Config);

use_ok("pf::fingerbank");

my $result;

# test invalid data
my $non_existing_device = "DUMMYKJFSKJFLKJAJKLFKJLKLJDFJKLDKJLFJKLDFLKJKLSF";
$result = pf::fingerbank::device_class_transition_allowed($non_existing_device, $non_existing_device, $non_existing_device, $non_existing_device);
ok(!defined($result), "Invalid device name provides undefined result");

# Disable the device class transition check for all device classes to test the manual trigger
$Config{fingerbank_device_change}{trigger_on_device_class_change} = "disabled";

# test manual transition trigger
$result = pf::fingerbank::device_class_transition_allowed("Windows OS", "Windows OS", "Medical Device", "Abbott Medical");
ok(!$result, "Manual trigger provides not allowed result");

# Re-enable the device class transition check for all device classes 
$Config{fingerbank_device_change}{trigger_on_device_class_change} = "enabled";

# test valid transition
$result = pf::fingerbank::device_class_transition_allowed("Windows OS", "Windows OS", "Windows OS", "Microsoft Windows Kernel 10.0");
ok($result, "Not switching device class provides allowed result");

# test transition to same device
$result = pf::fingerbank::device_class_transition_allowed("Windows OS", "Windows OS", "Windows OS", "Windows OS");
ok($result, "Not switching device class provides allowed result");

# test invalid transition
$result = pf::fingerbank::device_class_transition_allowed("Windows OS", "Windows OS", "Android OS", "Galaxy S8");
ok(!$result, "Switching device class provides not allowed result");

# test whitelisted transition
$result = pf::fingerbank::device_class_transition_allowed("Windows OS", "Windows OS", "Printer or Scanner", "Printer or Scanner");
ok($result, "Whitelisted transition provides allowed result");

# _collector_suffix_for_mac decides which fingerbank collector a device is looked up
# on: the collector co-located with the pfconnector the device connected through, or
# the configured (clustered) one. Everything that cannot be resolved must land on the
# configured collector, which is what the deployment used before this targeting existed.

{
    package test::connector;
    sub new { my ($class, $id) = @_; return bless({ id => $id }, $class) }
    sub id { return $_[0]->{id} }
}

my $fingerbank_mock = Test::MockModule->new("pf::fingerbank");
my $factory_mock    = Test::MockModule->new("pf::factory::connector");

my $test_mac = "00:11:22:33:44:55";

# Helper: run _collector_suffix_for_mac with a given locationlog entry and connector
sub collector_suffix_for {
    my ($entry, $for_ip) = @_;
    $fingerbank_mock->mock(locationlog_view_open_mac => sub { return $entry });
    $factory_mock->mock(for_ip => $for_ip);
    return pf::fingerbank::_collector_suffix_for_mac($test_mac);
}

my $connector_a = test::connector->new("connA");

is(collector_suffix_for(undef, sub { return $connector_a }), "local",
    "A device with no open locationlog session uses the configured collector");

is(collector_suffix_for({ mac => $test_mac }, sub { return $connector_a }), "local",
    "An open session with no switch IP uses the configured collector");

is(collector_suffix_for({ switch_ip => "10.1.2.3" }, sub { return $connector_a }), "connA",
    "A device behind a pfconnector uses that connector's collector");

is(collector_suffix_for({ switch => "10.1.2.3" }, sub { return $connector_a }), "connA",
    "The switch field is used when switch_ip is absent");

is(collector_suffix_for({ switch_ip => "10.1.2.3" }, sub { return test::connector->new("local_connector") }), "local",
    "A device on the local connector uses the configured collector");

is(collector_suffix_for({ switch_ip => "10.1.2.3" }, sub { die "no connector for this IP
" }), "local",
    "A failure to resolve the connector falls back to the configured collector");

$fingerbank_mock->unmock_all();
$factory_mock->unmock_all();

# A connector's collector is cached for $CONNECTOR_COLLECTOR_TTL seconds only, and a
# dedicated collector that fails is retried on the configured one.

{
    package test::collector;
    sub new { my ($class, $name) = @_; return bless({ name => $name }, $class) }
    sub name { return $_[0]->{name} }
    sub get_lwp_client { return "ua-".$_[0]->{name} }
}

my $local = test::collector->new("local");
my $builds = 0;
my $build_result;
$fingerbank_mock->mock(_collector_suffix_for_mac => sub { return "connA" });
$fingerbank_mock->mock(_build_connector_collector => sub { $builds++; return $build_result });
$fingerbank_mock->mock(_local_collector => sub { return ($local, "ua-local", "local") });

sub collector_name_for_mac {
    my ($collector) = pf::fingerbank::_collector_for_mac($test_mac);
    return $collector->name;
}

pf::fingerbank::CLONE();
$build_result = test::collector->new("connA");
collector_name_for_mac() for 1..2;
is($builds, 1, "A connector's collector is resolved once within the TTL");

{
    local $pf::fingerbank::CONNECTOR_COLLECTOR_TTL = 0;
    pf::fingerbank::CLONE();
    $builds = 0;
    collector_name_for_mac() for 1..2;
    is($builds, 2, "A connector's collector is resolved again once the TTL expired");
}

pf::fingerbank::CLONE();
$builds = 0;
$build_result = undef;
is(collector_name_for_mac(), "local", "A connector without a dedicated collector uses the configured collector");
collector_name_for_mac();
is($builds, 1, "A connector without a dedicated collector is not resolved again within the TTL");

# Helper: run _collector_request with the dedicated collector answering $dedicated_code
# and the configured one $local_code; returns the collectors called and the response code.
sub collector_request_with {
    my ($dedicated_code, $local_code) = @_;
    my @called;
    $fingerbank_mock->mock(_send_collector_request => sub {
        my ($collector) = @_;
        push @called, $collector->name;
        return HTTP::Response->new($collector->name eq "local" ? $local_code : $dedicated_code);
    });
    my $res = pf::fingerbank::_collector_request("endpoint_attributes", "GET", $test_mac);
    return (\@called, $res->code);
}

pf::fingerbank::CLONE();
$builds = 0;
$build_result = test::collector->new("connA");

my ($called, $code) = collector_request_with(200, 200);
is_deeply($called, ["connA"], "A dedicated collector that answers is not retried");

($called, $code) = collector_request_with(404, 200);
is_deeply($called, ["connA", "local"], "A dedicated collector answering an error is retried on the configured collector");
is($code, 200, "The configured collector's answer is returned");
collector_name_for_mac();
is($builds, 1, "A dedicated collector answering a client error is kept");

($called, $code) = collector_request_with(500, 200);
is_deeply($called, ["connA", "local"], "An unreachable dedicated collector is retried on the configured collector");
collector_name_for_mac();
is($builds, 2, "An unreachable dedicated collector is resolved again on the next lookup");

($called, $code) = collector_request_with(500, 500);
is($code, 500, "The configured collector's failure is returned when both fail");

$fingerbank_mock->mock(_collector_suffix_for_mac => sub { return "local" });
($called, $code) = collector_request_with(200, 500);
is_deeply($called, ["local"], "A failure on the configured collector is not retried");

pf::fingerbank::CLONE();
$fingerbank_mock->unmock_all();

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

