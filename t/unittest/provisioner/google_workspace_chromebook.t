#!/usr/bin/perl

=head1 NAME

google_workspace_chromebook

=head1 DESCRIPTION

unit test for google_workspace_chromebook

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

our @activeImportedDevices;
our @nonActiveImportedDevices;
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    @activeImportedDevices = (
        "00:22:44:66:88:ac",
        "00:22:44:66:88:ad",
        "00:22:44:66:88:ae"
    );
    @nonActiveImportedDevices = (
        "00:22:44:66:88:af"
    );
}

use Test::More tests => 16 + (scalar @activeImportedDevices) * 3 + (scalar @nonActiveImportedDevices);

#This test will running last
use IPC::Open3;
use IO::Handle;
use Test::NoWarnings;
use JSON;
use pf::provisioner::google_workspace_chromebook;
use pf::constants;
use pf::security_event;
use pf::node;
use pf::defer;
use pf::factory::provisioner;
use Symbol 'gensym';

my $child_err = gensym;
my $date = "2021-06-02T15:09:11.657Z";
is(pf::provisioner::google_workspace_chromebook::syncDateToQuery($date), "sync:2021-06-02T15:09:11..", "Formating sync date to a query");
my $p = pf::factory::provisioner->new('google_workspace_chromebook');
my $baseUri = $p->baseUri;
isa_ok($p, 'pf::provisioner::google_workspace_chromebook');
my $pid = open3(my $chld_out, my $chld_in, $child_err, "/usr/local/pf/t/mock_servers/google-provisioner-chromebook.pl", "daemon", "-l", $p->baseUri);
sleep(1);
my $defer = pf::defer::defer(
    sub {
        kill( 'INT', $pid );
        waitpid( $pid, 0 );
    }
);

$p->_clock(sub { 200 });

is($baseUri, "http://127.0.0.1:34356", "Base Uri");
is($p->baseUrl, "http://127.0.0.1:34356/admin/directory/v1/customer", "Base Url");
my $token = $p->access_token();

is($token, "123", "Access token");

is(
    $p->urlForList,
    "http://127.0.0.1:34356/admin/directory/v1/customer/my_customer/devices/chromeos?access_token=$token",
    "URL for list"
);

is(
    $p->urlForList({ query => "001122334455" }),
    "http://127.0.0.1:34356/admin/directory/v1/customer/my_customer/devices/chromeos?access_token=$token&query=001122334455",
    "URL for list with query"
);

is(
    $p->urlForList({ query => "id:%" }),
    "http://127.0.0.1:34356/admin/directory/v1/customer/my_customer/devices/chromeos?access_token=$token&query=id%3A%25",
    "URL for list with query url encoded"
);

{
    my $authorizedMac = '00:22:44:66:88:aa';
    is($p->authorize($authorizedMac), $TRUE, "authorize mac $authorizedMac");
    my $node = node_view($authorizedMac);
    is($node->{pid}, '00:22:44:66:88:aa@test.test', "Proper pid applied");
}

my $unAuthorizedMac = '00:22:44:66:88:ab';
is($p->authorize($unAuthorizedMac), $FALSE, "unauthorize mac $unAuthorizedMac");

is_deeply(
    $p->make_payload('https://www.googleapis.com/auth/admin.directory.device.chromeos.readonly'),
    {
        scope => 'https://www.googleapis.com/auth/admin.directory.device.chromeos.readonly',
        iss => 'test@test.com',
        sub => 'bob@example.com',
        aud => 'http://127.0.0.1:34356/token',
        exp => 800,
        iat => 200,
    },
    "Make Payload"
);

my $disabled_mac = "00:22:44:66:88:ab";
my $se = $p->{non_compliance_security_event};
security_event_force_close($disabled_mac, $se);
$p->cache->clear;
is(
    $p->syncQuery,
    "sync:0000-01-02..",
    "Initial sync query"
);

$p->pollAndEnforce(2323);
ok(security_event_exist_open($disabled_mac, $se), "Security event $se triggered for $disabled_mac");
for my $mac (@activeImportedDevices, @nonActiveImportedDevices) {
    node_delete($mac);
}

is(
    $p->syncQuery,
    "sync:2021-06-02T15:09:13..",
    "After Sync query"
);

$p->importDevices();
for my $mac (@activeImportedDevices) {
    ok(node_exist($mac), "$mac imported");
    my $node = node_view($mac);
    is($node->{category}, $p->role_to_apply, "Proper role applied");
    is($node->{pid}, "$mac\@test.test", "The proper email is applied");
}

for my $mac (@nonActiveImportedDevices) {
    ok(!node_exist($mac), "$mac not imported");
}

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

1;
