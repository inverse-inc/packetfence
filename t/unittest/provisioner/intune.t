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

use Test::More tests => 47;
use Test::NoWarnings;

use_ok("pf::provisioner::intune");

my $MAC = 'aa:bb:cc:dd:ee:ff';
my $AAD = '8df07f7e-d98e-4579-aa97-bfcfaaa7fe38';
my $OTHER_AAD = '0b1c2d3e-4f50-4a6b-8c7d-9e0f1a2b3c4d';

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
    # authorize() reads the node; the tests give it a stale 802.1X username
    *pf::provisioner::intune::node_view = sub { return { mac => $_[0], last_dot1x_username => $OTHER_AAD } };
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
    { mac => $MAC, azure_ad_device_id => $AAD, intune_device_id => $AAD },
    "GUID identity feeds both device ID methods",
);
is_deeply(
    $p->lookup_identities($MAC, { last_dot1x_username => 'host/laptop-42.corp.example' }),
    { mac => $MAC, device_name => 'laptop-42' },
    "machine identity feeds device_name",
);
is_deeply($p->lookup_identities($MAC, { computername => 'LAPTOP-42' }), { mac => $MAC }, "the DHCP computer name is not used");
is_deeply($p->lookup_identities($MAC, { last_dot1x_username => 'alice@corp.example' }), { mac => $MAC }, "a user identity feeds no method");
is_deeply($p->lookup_identities($MAC, {}), { mac => $MAC }, "no node data leaves the MAC only");

# --- identity of the current RADIUS request -------------------------------
my $stale = { last_dot1x_username => $OTHER_AAD };
is($p->lookup_identities($MAC, $stale, { user_name => $AAD })->{azure_ad_device_id}, $AAD,
   "the request's username wins over the node's last 802.1X username");
is($p->lookup_identities($MAC, $stale, { user_name => 'alice@corp.example', radius_request => { 'TLS-Client-Cert-Common-Name' => uc $AAD } })->{azure_ad_device_id}, $AAD,
   "the certificate CN is used when the username comes from the SAN");
is($p->lookup_identities($MAC, $stale, { user_name => $OTHER_AAD, radius_request => { 'TLS-Client-Cert-Common-Name' => $AAD } })->{azure_ad_device_id}, $AAD,
   "the certificate CN comes before the username");
is_deeply($p->lookup_identities($MAC, $stale, { user_name => 'aabbccddeeff' }), { mac => $MAC },
   "MAC authentication: no fallback to the previous session's identity");
is($p->lookup_identities($MAC, $stale, { radius_request => {} })->{azure_ad_device_id}, $OTHER_AAD,
   "without a request username, the node's last 802.1X username is used");

# --- find_device: order, fallbacks, failures ------------------------------
my $node = { last_dot1x_username => "$AAD\@corp.example" };
my $ctx_name = { user_name => 'host/LAPTOP-42.corp.example', radius_request => { 'TLS-Client-Cert-Common-Name' => $AAD } };

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
$found = $p->find_device($MAC, $node, $ctx_name);
is($found, undef, "a device name shared by several devices is not used");
is(scalar @calls, 3, "device ID miss, ambiguous device name, then the MAC scan");

%answers = (name => { value => [ { id => 'dev-name', deviceName => 'LAPTOP-42' } ] });
@calls = ();
my $method;
($found, $method) = $p->find_device($MAC, $node, $ctx_name);
is($found->{id}, 'dev-name', "falls back to a unique device name");
is($method, 'device_name', "the method is returned in list context");

%answers = (list => { value => [ { id => 'dev-mac', wiFiMacAddress => 'AABBCCDDEEFF' } ] });
@calls = ();
$found = $p->find_device($MAC, $node, $ctx_name);
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

# --- the rules get the full managed device record --------------------------
my @enforced;
{
    no warnings qw(redefine once);
    *pf::provisioner::intune::handleAuthorizeEnforce = sub { my ($self, $mac, $data, $return_empty) = @_; push @enforced, $data; return $return_empty };
}
my $full = { id => 'dev-aad', deviceName => 'LAPTOP-42', complianceState => 'compliant', operatingSystem => 'Windows', isEncrypted => JSON::MaybeXS::true() };
%answers = (aad => { value => [ { id => 'dev-aad', complianceState => 'compliant' } ] }, byid => $full);
@calls = (); @enforced = ();
ok($p->authorize($MAC, { user_name => $AAD }), "compliant device found by Azure AD device ID is authorized");
is($enforced[0]{intune}{operatingSystem}, 'Windows', "the rules get the full record");
unlike($calls[-1], qr/\$select/, "the full record is fetched without \$select");

my $p_id = pf::provisioner::intune->new({ id => 'intune-id', access_token => 'token', device_lookup => ['intune_device_id'] });
%answers = (byid => $full);
@calls = (); @enforced = ();
ok($p_id->authorize($MAC, { user_name => $AAD }), "compliant device found by Intune device ID is authorized");
is(scalar @calls, 1, "the lookup by Intune ID is not repeated");
unlike($calls[0], qr/\$select/, "the lookup by Intune ID fetches the full record");
is($enforced[0]{intune}{operatingSystem}, 'Windows', "and the rules get it");

# --- authorize_apply_role cache is per identity ----------------------------
is(pf::provisioner::intune->new({})->authorize_cache_key_suffix($MAC, { user_name => $AAD }), '', "MAC-only lookup: the cache key is the MAC");
isnt($p->authorize_cache_key_suffix($MAC, { user_name => $AAD }), $p->authorize_cache_key_suffix($MAC, { user_name => $OTHER_AAD }),
     "identity lookup: devices sharing a MAC get different cache keys");
my $p_role = pf::provisioner::intune->new({ id => 'intune-role', type => 'intune', access_token => 'token', device_lookup => ['azure_ad_device_id'], apply_role => 'enabled', role_to_apply => 'compliant_role' });
my $DOCK = '02:00:00:95:17:01';
$p_role->cache->remove($_) for map { "intune-authorize_apply_role($DOCK)-azure_ad_device_id=$_-intune_device_id=$_" } $AAD, $OTHER_AAD;
%answers = (aad => { value => [ { id => 'dev-aad', complianceState => 'compliant' } ] }, byid => $full);
is($p_role->authorize_apply_role($DOCK, { user_name => $AAD }), 'compliant_role', "compliant laptop on the dock gets the role");
%answers = ();
is($p_role->authorize_apply_role($DOCK, { user_name => $OTHER_AAD }), undef, "an unenrolled laptop on the same dock doesn't reuse the cached result");

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
