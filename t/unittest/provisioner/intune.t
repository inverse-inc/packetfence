#!/usr/bin/perl

=head1 NAME

intune

=head1 DESCRIPTION

unit test for pf::provisioner::intune device lookup (GitHub #9082)

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 27;
use Test::NoWarnings;

use_ok("pf::provisioner::intune");

my $MAC = 'aa:bb:cc:dd:ee:ff';
my $AAD = '8df07f7e-d98e-4579-aa97-bfcfaaa7fe38';

# Canned Graph answers per kind of request (filter on the Azure AD device
# ID, filter on the device name, GET by Intune ID, plain list for the MAC
# scan); @calls records the requests so the lookup order can be asserted.
my (@calls, %answers);
sub request_kind {
    my ($url) = @_;
    return 'aad'  if $url =~ /\$filter=azureADDeviceId/;
    return 'name' if $url =~ /\$filter=deviceName/;
    return 'byid' if $url =~ m{managedDevices/};
    return 'list';
}
{
    no warnings qw(redefine once);
    *pf::provisioner::intune::perform_get_device_info = sub {
        my ($self, $url) = @_;
        push @calls, $url;
        return $answers{request_kind($url)} // { value => [] };
    };
}

my $p = new_ok("pf::provisioner::intune", [{
    id            => 'intune-test',
    access_token  => 'token',
    device_lookup => ['azure_ad_device_id', 'device_name', 'mac'],
}]);

# --- lookup_methods -------------------------------------------------------
is_deeply([$p->lookup_methods], [qw(azure_ad_device_id device_name mac)], "configured order is kept");
is_deeply([pf::provisioner::intune->new({device_lookup => 'mac, bogus, device_name, mac'})->lookup_methods],
          [qw(mac device_name)], "comma-separated config is split, unknown and duplicate methods dropped");
is_deeply([pf::provisioner::intune->new({})->lookup_methods], ['mac'], "default is the MAC scan");
is_deeply([pf::provisioner::intune->new({device_lookup => []})->lookup_methods], ['mac'], "empty config falls back to the MAC scan");

# --- identity normalisation ----------------------------------------------
is($p->normalize_dot1x_identity("host/$AAD\@corp.example"), $AAD, "host/ prefix and realm stripped");
is($p->normalize_dot1x_identity('CORP\\LAPTOP-42$'), 'LAPTOP-42$', "DOMAIN\\ prefix stripped");
is($p->normalize_dot1x_identity(''), undef, "empty identity is undef");
is($p->normalize_dot1x_identity(undef), undef, "undef identity is undef");
ok($p->is_guid(uc $AAD), "GUID accepted in upper case");
ok(!$p->is_guid('LAPTOP-42'), "hostname is not a GUID");

is_deeply(
    $p->lookup_identities($MAC, { last_dot1x_username => "host/" . uc($AAD) . "\@corp.example", computername => 'LAPTOP-42.corp.example' }),
    { mac => $MAC, azure_ad_device_id => $AAD, intune_device_id => $AAD, device_name => 'LAPTOP-42' },
    "GUID identity feeds both device ID methods, computername feeds device_name",
);
is_deeply(
    $p->lookup_identities($MAC, { last_dot1x_username => 'host/laptop-42.corp.example' }),
    { mac => $MAC, device_name => 'laptop-42' },
    "machine identity without computername feeds device_name only",
);
is_deeply($p->lookup_identities($MAC, {}), { mac => $MAC }, "no node data leaves the MAC only");

# --- find_device: order, fallbacks, failures ------------------------------
my $node = { last_dot1x_username => "$AAD\@corp.example", computername => 'LAPTOP-42' };

%answers = (aad => { value => [ { id => 'dev-aad', deviceName => 'LAPTOP-42', complianceState => 'compliant' } ] });
@calls = ();
my $found = $p->find_device($MAC, $node);
is($found->{id}, 'dev-aad', "found by Azure AD device ID");
is(scalar @calls, 1, "one Graph call when the first method matches");
like($calls[0], qr/\$filter=azureADDeviceId%20eq%20%27\Q$AAD\E%27/, "filter query is URL-encoded with the device ID");

%answers = (name => { value => [
    { id => 'dev-old', deviceName => 'LAPTOP-42', lastSyncDateTime => '2026-01-01T00:00:00Z' },
    { id => 'dev-new', deviceName => 'LAPTOP-42', lastSyncDateTime => '2026-09-01T00:00:00Z' },
] });
@calls = ();
$found = $p->find_device($MAC, $node);
is($found->{id}, 'dev-new', "falls back to device name and prefers the most recently synced device");
is(scalar @calls, 2, "device ID miss then device name hit");

%answers = (list => { value => [ { id => 'dev-mac', wiFiMacAddress => 'AABBCCDDEEFF' } ] });
@calls = ();
$found = $p->find_device($MAC, $node);
is($found->{id}, 'dev-mac', "falls back to the MAC scan");
is(scalar @calls, 3, "all three methods tried in order");

%answers = ();
@calls = ();
is($p->find_device($MAC, $node), undef, "nothing matched: undef, no crash");

%answers = (aad => $pf::provisioner::COMMUNICATION_FAILED);
@calls = ();
is($p->find_device($MAC, $node), $pf::provisioner::COMMUNICATION_FAILED, "communication failure is propagated");
is(scalar @calls, 1, "and stops the lookup");

# --- get_device_by_id: 404 error document is 'not found' -----------------
%answers = (byid => { error => { code => 'ResourceNotFound' } });
is($p->get_device_by_id('nope'), undef, "Graph 404 error document is treated as not found");

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
