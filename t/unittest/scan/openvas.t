#!/usr/bin/perl

=head1 NAME

openvas

=head1 DESCRIPTION

unit test for pf::scan::openvas

The SSH channel to the GMP service is replaced by a fake one replaying canned GMP responses

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

{
    package FakeChannel;
    # Replays the queued chunks on read and records what is written
    sub new { my ($class, @chunks) = @_; return bless { chunks => [@chunks], sent => [] }, $class }
    sub write { my ($self, $data) = @_; push @{$self->{sent}}, $data; return length($data) }
    sub read {
        my ($self, undef, $size) = @_;
        my $chunk = shift @{$self->{chunks}};
        return 0 if !defined $chunk;
        $_[1] = $chunk;
        return length($chunk);
    }
    sub close { $_[0]{closed} = 1 }
    sub sent { return join('', @{$_[0]{sent}}) }

    package FakeSSH;
    sub new { return bless {}, shift }
    sub error { return (-1, 'LIBSSH2_ERROR', 'fake error') }
    sub disconnect { $_[0]{disconnected} = 1 }
}

use Test::More tests => 51;
use Test::MockModule;
# Loaded before being mocked, so that the require in gmpConnect does not redefine the mocked subs
use Net::SSH2;

#This test will running last
use Test::NoWarnings;
use pf::scan::openvas;

my $TARGET_ID = 'b493b7a8-7489-11df-a3ec-002264764cea';
my $TASK_ID   = '267a3405-e84a-47da-97b2-5fa0d2e8995e';
my $REPORT_ID = 'f0fdf522-276d-4893-9274-fb8699dc2270';
my %SCAN_INFO = (report_id => $REPORT_ID, task_id => $TASK_ID, target_id => $TARGET_ID, mac => '02:00:00:00:00:15', id => 'greenbone', scan_id => 'greenbone');
my $AUTH_OK   = '<authenticate_response status="200" status_text="OK"><role>User</role><timezone>UTC</timezone></authenticate_response>';

my %cache;
my @triggered;
my $synced = 0;
my $module = Test::MockModule->new('pf::scan::openvas');
$module->mock(setScanInfo => sub { my ($self, $id, $info) = @_; $cache{$id} = $info });
$module->mock(getScanInfo => sub { my ($self, $id) = @_; $cache{$id} });
$module->mock(removeScanInfo => sub { my ($self, $id) = @_; delete $cache{$id} });
$module->mock(security_event_trigger => sub { push @triggered, $_[0] });
$module->mock(statusReportSyncToDb => sub { $synced++ });
my $client = Test::MockModule->new('pf::api::jsonrpcclient');
my @notified;
$client->mock(notify => sub { shift; push @notified, [@_] });

sub new_scanner {
    my (%args) = @_;
    return pf::scan::openvas->new(
        id       => 'greenbone',
        ip       => '192.0.2.10',
        port     => 22,
        username => 'packetfence',
        password => 'p&ss<word>',
        type     => 'openvas',
        scanIp   => '192.0.2.15',
        scanMac  => '02:00:00:00:00:15',
        scanner_id => 'greenbone',
        openvas_alertid => '0a4c6daa-ae67-4da2-9d70-ecd0dbd513b6',
        openvas_ssh_username => 'gmpuser',
        openvas_ssh_password => 'ssh-secret',
        %args,
    );
}

sub attach {
    my ($scanner, @chunks) = @_;
    my $channel = FakeChannel->new(@chunks);
    @{$scanner}{qw(_ssh _channel)} = (FakeSSH->new, $channel);
    return $channel;
}

# _xml_escape
is(pf::scan::openvas::_xml_escape(q{<a href="x">&'</a>}), '&lt;a href=&quot;x&quot;&gt;&amp;&apos;&lt;/a&gt;', 'XML special characters are escaped');
is(pf::scan::openvas::_xml_escape(undef), '', 'undef is escaped to an empty string');

# gmpCommand and the response framing
{
    my $scanner = new_scanner();
    my $channel = attach($scanner, '<?xml version="1.0"?><get_version_response status="200" status_text="OK">', '<version>22.7</version></get_version_response>');
    my $response = $scanner->gmpCommand('<get_version/>', 'get_version');
    ok($response, 'a response split over several reads is reassembled');
    is($response->findvalue('version'), '22.7', 'the response is parsed');
    is($channel->sent, '<get_version/>', 'the command is written to the channel');
}
{
    # A large response whose closing tag is split between two reads
    my $scanner = new_scanner();
    my $xml = '<get_version_response status="200" status_text="OK"><version>22.7</version><padding>' . ('x' x 5000) . '</padding></get_version_response>';
    attach($scanner, (map { substr($xml, $_ * 1000, 1000) } 0 .. int(length($xml) / 1000) - 1), substr($xml, int(length($xml) / 1000) * 1000, -10), substr($xml, -10));
    my $response = $scanner->gmpCommand('<get_version/>', 'get_version');
    is($response && $response->findvalue('version'), '22.7', 'a large response is read until its closing tag');
}
{
    my $scanner = new_scanner();
    attach($scanner, '<get_version_response status="200" status_text="OK"><version>22.7</version>');
    ok(!$scanner->gmpCommand('<get_version/>', 'get_version'), 'an incomplete response is a failure');
}
{
    my $scanner = new_scanner();
    attach($scanner, '<delete_task_response status="200" status_text="OK"/>');
    ok($scanner->gmpCommand('<delete_task task_id="x"/>', 'delete_task'), 'an empty element response is complete');
}
{
    my $scanner = new_scanner();
    attach($scanner, '<delete_task_response status="200"', ' status_text="OK"/>');
    ok($scanner->gmpCommand('<delete_task task_id="x"/>', 'delete_task'), 'an empty element response split over several reads is complete');
}
{
    my $scanner = new_scanner();
    attach($scanner, '<authenticate_response status="400" status_text="Authentication failed"/>');
    ok(!$scanner->gmpCommand('<authenticate/>', 'authenticate'), 'an error status is a failure');
}
{
    my $scanner = new_scanner();
    attach($scanner, "Permission denied\n");
    ok(!$scanner->gmpCommand('<get_version/>', 'get_version'), 'a non-XML output is a failure');
}

# gmpConnect authenticates without leaking the escaped password into the logs
{
    my $ssh2 = Test::MockModule->new('Net::SSH2');
    my $channel = FakeChannel->new($AUTH_OK);
    my %connected;
    $ssh2->redefine(new => sub { return bless {}, 'Net::SSH2' });
    $ssh2->redefine(timeout => sub { 1 });
    $ssh2->redefine(connect => sub { @connected{qw(host port)} = @_[1, 2]; 1 });
    $ssh2->redefine(auth => sub { shift; %connected = (%connected, @_); 1 });
    $ssh2->redefine(channel => sub { $channel });
    $ssh2->redefine(disconnect => sub { 1 });
    # The fake objects are not libssh2 sessions
    $ssh2->redefine(DESTROY => sub { });
    my $exec = 0;
    {
        no warnings 'once';
        *FakeChannel::exec = sub { $exec++; 1 };
    }
    my $scanner = new_scanner();
    ok($scanner->gmpConnect(), 'gmpConnect succeeds');
    is_deeply([@connected{qw(host port username password)}], ['192.0.2.10', 22, 'gmpuser', 'ssh-secret'], 'the SSH host, port and credentials of the scan engine are used');
    is($exec, 1, 'the GMP session is started on the channel');
    is($channel->sent, '<authenticate><credentials><username>packetfence</username><password>p&amp;ss&lt;word&gt;</password></credentials></authenticate>', 'the GMP credentials are escaped');

    $channel = FakeChannel->new('<authenticate_response status="400" status_text="Authentication failed"/>');
    $scanner = new_scanner(openvas_ssh_username => 'admin', openvas_ssh_password => 'secret', port => 2222);
    ok(!$scanner->gmpConnect(), 'gmpConnect fails when GMP authentication fails');
    is_deeply([@connected{qw(port username password)}], [2222, 'admin', 'secret'], 'the configured SSH port and credentials are used');
    ok(!$scanner->{_channel}, 'the session is closed after a failed authentication');

    # No built-in SSH credentials
    my $connects = 0;
    $ssh2->redefine(connect => sub { $connects++; 1 });
    for my $missing ([openvas_ssh_username => undef], [openvas_ssh_password => '']) {
        $scanner = new_scanner(@$missing);
        ok(!$scanner->gmpConnect(), "gmpConnect fails without $missing->[0]");
    }
    is($connects, 0, 'no SSH connection is attempted without SSH credentials');
}

# startScan, the whole sequence
{
    my $scanner = new_scanner(registration => 0, pre_registration => 0);
    my $channel;
    $module->mock(gmpConnect => sub { my ($self) = @_; $channel = attach($self,
        qq{<create_target_response status="201" status_text="OK, resource created" id="$TARGET_ID"/>},
        qq{<create_task_response status="201" status_text="OK, resource created" id="$TASK_ID"/>},
        qq{<start_task_response status="202" status_text="OK, request submitted"><report_id>$REPORT_ID</report_id></start_task_response>},
    ); 1 });
    @notified = ();
    is($scanner->startScan(), undef, 'startScan succeeds');
    my $sent = $channel->sent;
    like($sent, qr{<create_target><name>greenbone[\d.]+</name><hosts>192\.0\.2\.15</hosts><port_list id="33d0cd82-57c6-11e1-8ed1-406186ea4fc5"/></create_target>}, 'the target uses the default port list');
    like($sent, qr{<create_task><name>greenbone[\d.]+</name><config id="daba56c8-73ec-11df-a475-002264764cea"/><target id="$TARGET_ID"/><scanner id="08b69003-5fc2-4037-a479-93b440211c73"/><alert id="0a4c6daa-ae67-4da2-9d70-ecd0dbd513b6"/></create_task>}, 'the task uses the default config and scanner, and the alert');
    like($sent, qr{<start_task task_id="$TASK_ID"/>}, 'the task is started');
    my ($name) = keys %cache;
    is_deeply($cache{$name}, { report_id => $REPORT_ID, task_id => $TASK_ID, target_id => $TARGET_ID, mac => '02:00:00:00:00:15', ip => '192.0.2.15', id => 'greenbone', scan_id => 'greenbone' }, 'the scan info is saved under the task name');
    is($scanner->{_status}, 'started', 'the scan is started');
    is(scalar @notified, 1, 'the scan security event is closed');
    ok(!$scanner->{_channel}, 'the session is closed');
}

# startScan stops when the target cannot be created
{
    my $scanner = new_scanner(registration => 1);
    my $channel;
    $module->mock(gmpConnect => sub { my ($self) = @_; $channel = attach($self,
        '<create_target_response status="400" status_text="Error in port range"/>',
    ); 1 });
    @notified = ();
    is($scanner->startScan(), $pf::constants::scan::SCAN_SECURITY_EVENT_ID, 'startScan returns the scan security event when the target cannot be created');
    unlike($channel->sent, qr/create_task|delete_/, 'no task is created and nothing is deleted');
    is(scalar @notified, 0, 'the scan security event is not closed');
}

# startScan removes the target when the task cannot be started
{
    my $scanner = new_scanner(openvas_portlistid => 'my<list', openvas_configid => 'cfg', openvas_scannerid => 'scn');
    my $channel;
    $module->mock(gmpConnect => sub { my ($self) = @_; $channel = attach($self,
        qq{<create_target_response status="201" status_text="OK, resource created" id="$TARGET_ID"/>},
        '<create_task_response status="404" status_text="Failed to find config"/>',
        '<delete_target_response status="200" status_text="OK"/>',
    ); 1 });
    is($scanner->startScan(), $pf::constants::scan::POST_SCAN_SECURITY_EVENT_ID, 'startScan returns the post scan security event when the task cannot be created');
    my $sent = $channel->sent;
    like($sent, qr{<port_list id="my&lt;list"/>}, 'the configured port list is escaped');
    like($sent, qr{<config id="cfg"/><target id="$TARGET_ID"/><scanner id="scn"/>}, 'the configured config and scanner are used');
    like($sent, qr{<delete_target target_id="$TARGET_ID" ultimate="1"/>\z}, 'the target is deleted');
}

# startScan when the GMP service cannot be reached
{
    my $scanner = new_scanner(pre_registration => 1);
    $module->mock(gmpConnect => sub { return });
    is($scanner->startScan(), $pf::constants::scan::PRE_SCAN_SECURITY_EVENT_ID, 'startScan returns the pre scan security event when GMP is unreachable');
}

# processReport
my $report = <<"EOF";
<get_reports_response status="200" status_text="OK"><report id="$REPORT_ID" format_id="a994b278-1f62-11e1-96ac-406186ea4fc5" extension="xml" content_type="text/xml"><owner><name>packetfence</name></owner><report id="$REPORT_ID"><results start="1" max="-1">
<result id="r1"><name>OpenSSH Information Disclosure</name><host>192.0.2.15</host><nvt oid="1.3.6.1.4.1.25623.1.0.100001"><name>x</name></nvt><threat>Medium</threat></result>
<result id="r2"><name>TCP timestamps</name><host>192.0.2.15</host><nvt oid="1.3.6.1.4.1.25623.1.0.80091"><name>y</name></nvt><threat>Low</threat></result>
<result id="r3"><name>TCP timestamps on another port</name><host>192.0.2.15</host><nvt oid="1.3.6.1.4.1.25623.1.0.80091"><name>y</name></nvt><threat>Low</threat></result>
</results></report></report></get_reports_response>
EOF
{
    %cache = (task1 => {%SCAN_INFO});
    @triggered = ();
    $synced = 0;
    my $scanner = new_scanner();
    my $channel;
    $module->mock(gmpConnect => sub { my ($self) = @_; $channel = attach($self,
        substr($report, 0, 200), substr($report, 200),
        '<delete_task_response status="200" status_text="OK"/>',
        '<delete_target_response status="200" status_text="OK"/>',
    ); 1 });
    ok($scanner->processReport('task1'), 'processReport succeeds');
    is_deeply([sort map { $_->{tid} } @triggered], ['1.3.6.1.4.1.25623.1.0.100001', '1.3.6.1.4.1.25623.1.0.80091'], 'one security event trigger per NVT OID');
    is_deeply([map { [@{$_}{qw(mac type)}] } @triggered], [(['02:00:00:00:00:15', 'OpenVAS']) x 2], 'the triggers are for the scanned node');
    like($channel->sent, qr{\A<get_reports report_id="$REPORT_ID" details="1" ignore_pagination="1"/><delete_task task_id="$TASK_ID" ultimate="1"/><delete_target target_id="$TARGET_ID" ultimate="1"/>\z}, 'the report is fetched, then the task and target are deleted');
    is($scanner->{_status}, 'closed', 'the scan is closed');
    ok(!exists $cache{task1}, 'the scan info is removed once the report is processed');
    $module->mock(gmpConnect => sub { fail('no GMP session for a processed report'); 0 });
    @triggered = ();
    ok(!$scanner->processReport('task1'), 'a report is processed once');
    is(scalar @triggered, 0, 'no security event is triggered again');
}
{
    @triggered = ();
    %cache = (task1 => {%SCAN_INFO});
    my $scanner = new_scanner(openvas_delete_scans => 'disabled');
    my $channel;
    $module->mock(gmpConnect => sub { my ($self) = @_; $channel = attach($self, $report); 1 });
    ok($scanner->processReport('task1'), 'processReport succeeds without deleting the scan');
    unlike($channel->sent, qr/delete_/, 'nothing is deleted when Delete scans is disabled');
}
{
    @triggered = ();
    %cache = (task1 => {%SCAN_INFO});
    my $scanner = new_scanner();
    $module->mock(gmpConnect => sub { my ($self) = @_; attach($self, '<get_reports_response status="404" status_text="Failed to find report"/>'); 1 });
    ok(!$scanner->processReport('task1'), 'processReport fails when the report cannot be fetched');
    ok(exists $cache{task1}, 'the scan info is kept when the report cannot be fetched');
    is(scalar @triggered, 0, 'no security event is triggered');
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
