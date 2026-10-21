#!/usr/bin/perl

=head1 NAME

Unifi

=head1 DESCRIPTION

unit test for pf::Switch::Ubiquiti::Unifi against a UniFi OS controller
(#9260 / #9107): the CSRF token of the session must be captured and sent on
the commands, from the login response, from the session cookie when the
controller sends no header, and refreshed when the controller rotates it
together with the session cookie.

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

use Test::More tests => 40;

#This test will running last
use Test::NoWarnings;

use pf::Switch::Ubiquiti::Unifi;
use pf::file_paths qw($var_dir);
use Symbol 'gensym';
use IPC::Open3;
use POSIX qw(WNOHANG);
use LWP::UserAgent;
use JSON::MaybeXS;
use HTTP::Cookies;
use MIME::Base64 ();
use Test::MockModule;
use pf::dal::locationlog;
use pf::dal::node;
use pf::dal::locationlog_history;
use pf::constants qw($ZERO_DATE);
use pf::config qw(%connection_type_to_str $WEBAUTH_WIRELESS);

$SIG{PIPE} = "IGNORE";

# The mock emulates a UniFi OS controller on this port only
my $UOS_PORT = 8445;
$pf::Switch::Ubiquiti::Unifi::DEFAULT_HTTP_PORT = $UOS_PORT;

my $child_err = gensym;
my $pid = eval {
    open3(my $chld_out, my $chld_in, $child_err, "/usr/local/pf/t/mock_servers/ubiquiti_ap_mac_to_ip.pl", "daemon", "-l", "http://127.0.0.3:$UOS_PORT")
};
END {
    if ($pid) {
        local $?;
        kill('KILL', $pid);
        waitpid($pid, 0);
    }
}
if ($@) {
    diag("Cannot start the mock controller: $@");
    exit 1;
}
sleep(1);
if (waitpid($pid, WNOHANG)) {
    local $/;
    diag("Mock controller died: " . <$child_err>);
    exit 1;
}

my $cookie_file = "$var_dir/run/.ubiquiti.cookies.txt";
unlink $cookie_file;

# Built directly (no switch cache, no database) with the values of the
# [172.16.8.32] entry of t/data/switches.conf
my $switch = pf::Switch::Ubiquiti::Unifi->new({
    id           => '172.16.8.32',
    ip           => '172.16.8.32',
    controllerIp => '127.0.0.3',
    wsTransport  => 'http',
    wsUser       => 'admin',
    wsPwd        => 'admin',
    type         => 'Ubiquiti::Unifi',
    group        => 'default',
    SNMPUseConnector => 'N',
    radiusDeauthUseConnector => 'N',
});
ok($switch, "Got the Unifi controller switch");
is(ref($switch), 'pf::Switch::Ubiquiti::Unifi', "It is a Unifi controller");

my $mock = LWP::UserAgent->new();
my $mock_url = "http://127.0.0.3:$UOS_PORT";
sub mock_state { return decode_json($mock->get("$mock_url/mock/state")->decoded_content) }

# The jar is saved to the cookie file when the user agent goes away, as it does
# between two commands of PacketFence
sub add_token_cookie {
    my ($domain, $claims) = @_;
    my $jar = HTTP::Cookies->new(file => $cookie_file, autosave => 1, ignore_discard => 1);
    my $payload = MIME::Base64::encode_base64(encode_json($claims), '');
    $payload =~ tr{+/}{-_};
    $payload =~ s/=+$//;
    $jar->set_cookie(0, 'TOKEN', "header.$payload.signature", '/', $domain, undef, 1, 0, 3600, 0);
    $jar->save;
}

# 1. Fresh session: status answers 401, login gives the token
my ($ua, $base_url) = $switch->_connect();
is($base_url, "$mock_url/proxy/network", "UniFi OS detected: the API is under /proxy/network");
is($ua->default_header('X-CSRF-Token'), 'csrf-token-1', "The CSRF token of the login response is sent on every request");
is($pf::Switch::Ubiquiti::Unifi::DETECTED_CONTROLLERS{"http://127.0.0.3"}{url}, $mock_url, "The controller location is remembered for the next commands");

my $post = $ua->post("$base_url/api/s/default/cmd/stamgr", Content => encode_json({ cmd => 'authorize-guest', mac => 'aa:bb:cc:dd:ee:ff', minutes => 60 }));
ok($post->is_success, "A command with the CSRF token is accepted") or diag($post->status_line);
is(decode_json($post->decoded_content)->{data}[0]{mac}, 'aa:bb:cc:dd:ee:ff', "The command reached the controller");
is($ua->default_header('X-CSRF-Token'), 'csrf-token-2', "The rotated token handed out by the controller replaces the old one");

# The controller renewed the session cookie along with the token: both must be kept
$post = $ua->post("$base_url/api/s/default/cmd/stamgr", Content => encode_json({ cmd => 'authorize-guest', mac => 'aa:bb:cc:dd:ee:ff', minutes => 60 }));
ok($post->is_success, "A second command uses the renewed session cookie and token") or diag($post->status_line);

# The same session without the header is what UniFi OS refuses (the bug)
my $bare = LWP::UserAgent->new();
$bare->cookie_jar($ua->cookie_jar);
$bare->default_header('Content-Type' => 'application/json');
my $refused = $bare->post("$base_url/api/s/default/cmd/stamgr", Content => encode_json({ cmd => 'authorize-guest', mac => 'aa:bb:cc:dd:ee:ff' }));
is($refused->code, 403, "The controller refuses the command without the CSRF token");
undef $bare;
undef $ua;

# 2. Existing session: no login, the token comes with the status response
my $logins = mock_state()->{logins};
($ua, $base_url) = $switch->_connect();
is($base_url, "$mock_url/proxy/network", "Still the UniFi OS API");
is($ua->default_header('X-CSRF-Token'), 'csrf-token-3', "The token comes with the status response of an authenticated session");
is(mock_state()->{logins}, $logins, "The saved session is reused without logging in");
undef $ua;

# 3. Controller sending no CSRF header: the token is read from the TOKEN cookie (JWT)
ok($mock->post("$mock_url/mock/csrf-headers/off")->is_success, "Mock: no CSRF headers");
unlink $cookie_file;
($ua, $base_url) = $switch->_connect();
is($ua->default_header('X-CSRF-Token'), 'csrf-token-1', "The token is taken from the csrfToken claim of the session cookie");
$post = $ua->post("$base_url/api/s/default/cmd/stamgr", Content => encode_json({ cmd => 'unauthorize-guest', mac => 'aa:bb:cc:dd:ee:ff' }));
ok($post->is_success, "A command with the cookie-derived token is accepted") or diag($post->status_line);
undef $ua;

# The cookie file is shared by every controller: the TOKEN of another one is ignored
add_token_cookie('127.0.0.2', { csrfToken => 'foreign-token' });
$logins = mock_state()->{logins};
($ua, $base_url) = $switch->_connect();
is($ua->default_header('X-CSRF-Token'), 'csrf-token-2', "The token comes from this controller's cookie, not another controller's");
is(mock_state()->{logins}, $logins, "No login needed when the session cookie carries the token");
undef $ua;

# A session with no token at all cannot send commands: log in again to get one
add_token_cookie('127.0.0.3', { userId => 'test' });
($ua, $base_url) = $switch->_connect();
is(mock_state()->{logins}, $logins + 1, "A session without any CSRF token triggers a new login");
is($ua->default_header('X-CSRF-Token'), 'csrf-token-1', "The new login provides the token");
undef $ua;
ok($mock->post("$mock_url/mock/csrf-headers/on")->is_success, "Mock: CSRF headers back on");

# 4. Full deauth: Network 10.6 answers 400 to the per-client lookup, so the
# command goes to every site and must be accepted
{
    my $module = Test::MockModule->new('pf::Switch::Ubiquiti::Unifi');
    $module->mock(node_view => sub { return { status => 'reg', unregdate => $ZERO_DATE, last_connection_type => $connection_type_to_str{$WEBAUTH_WIRELESS} } });
    $module->mock(security_event_count_reevaluate_access => sub { 0 });
    my $commands = scalar @{ mock_state()->{commands} };
    $switch->_deauthenticateMacWithHTTP('aa:bb:cc:dd:ee:01');
    my @sent = @{ mock_state()->{commands} }[$commands .. $#{ mock_state()->{commands} }];
    is(scalar @sent, 1, "The command was accepted on the single site");
    is_deeply([ map { [ $_->{site}, $_->{cmd}, $_->{mac} ] } @sent ], [ [ 'default', 'authorize-guest', 'aa:bb:cc:dd:ee:01' ] ], "authorize-guest sent to the default site");
}

# 5. Wrong credentials: the login is refused with 403 and _connect dies
{
    unlink $cookie_file;
    local $switch->{_wsPwd} = 'wrong';
    my $died = !eval { $switch->_connect(); 1 };
    ok($died, "A refused login makes _connect die instead of returning a broken session");
}

# 6. Probe timeouts: only the 11443 candidate gets the short timeout, so a
# controller without UniFi OS Server is found on its old port without waiting
# the full request timeout there
{
    my @probes;
    my $lwp = Test::MockModule->new('LWP::UserAgent');
    $lwp->mock(get => sub {
        my ($ua, $url) = @_;
        my ($port) = $url =~ m{^\w+://[^/:]+:(\d+)};
        push @probes, [ $port, $ua->timeout ];
        return HTTP::Response->new(500, "unreachable");
    });
    local $switch->{_controllerIp} = '127.0.0.4';
    local $switch->{_wsTransport} = 'https';
    $switch->_connect();
    is_deeply(\@probes, [ [ 443, 10 ], [ 11443, 3 ], [ 8443, 10 ] ], "The 11443 probe uses a 3s timeout, the other requests keep 10s");

    @probes = ();
    local $switch->{_controllerPort} = 11443;
    $switch->_connect();
    is_deeply(\@probes, [ [ 11443, 10 ], [ 11443, 10 ] ], "A configured controller port keeps the full timeout");
}

# 7. Certificate checking: off by default (self-signed controllers), full
# verification (chain and host) when wsVerifyCertificate is enabled
{
    my @ssl;
    my $lwp = Test::MockModule->new('LWP::UserAgent');
    $lwp->mock(get => sub {
        my ($ua) = @_;
        push @ssl, [ $ua->ssl_opts('verify_hostname'), $ua->ssl_opts('SSL_verify_mode') ];
        return HTTP::Response->new(500, "unreachable");
    });
    local $switch->{_controllerIp} = '127.0.0.4';
    local $switch->{_wsTransport} = 'https';
    local $switch->{_controllerPort} = 11443;
    $switch->_connect();
    is_deeply($ssl[0], [ 0, IO::Socket::SSL::SSL_VERIFY_NONE() ], "The certificate is not checked by default");
    @ssl = ();
    local $switch->{_wsVerifyCertificate} = 'Y';
    $switch->_connect();
    is_deeply($ssl[0], [ 1, IO::Socket::SSL::SSL_VERIFY_PEER() ], "wsVerifyCertificate checks the certificate and its host");
}

# 8. Redirects of the probe: only to the same host, keeping or upgrading to https,
# since the login with the controller password is then posted there
{
    my %answers;
    my @gets;
    my @posts;
    my $lwp = Test::MockModule->new('LWP::UserAgent');
    # The login is refused: a login posted anywhere makes _connect die
    $lwp->mock(post => sub { my ($ua, $url) = @_; push @posts, $url; return HTTP::Response->new(403, "refused") });
    $lwp->mock(get => sub {
        my ($ua, $url) = @_;
        push @gets, $url;
        my ($port) = $url =~ m{^\w+://[^/:]+:(\d+)};
        my $answer = $answers{$port} or return HTTP::Response->new(500, "unreachable");
        my $response = HTTP::Response->new($answer->[0], "answer");
        $response->request(HTTP::Request->new(GET => $answer->[1]));
        $response->header('x-csrf-token' => 'redirected-token');
        return $response;
    });
    local $switch->{_controllerIp} = '127.0.0.4';
    local $switch->{_controllerPort};

    local $switch->{_wsTransport} = 'http';
    %answers = ($UOS_PORT => [ 401, "https://other.example.com/proxy/network/status" ]);
    my ($ua, $base_url) = eval { $switch->_connect() };
    is($base_url, "http://127.0.0.4:8443", "A redirect to another host is ignored: the controller is looked for on its own address");
    ok(!grep({ /other\.example\.com/ } @gets, @posts), "The login is not posted to the other host");
    ok(!grep({ ($_->{url} // '') =~ /other\.example\.com/ } values %pf::Switch::Ubiquiti::Unifi::DETECTED_CONTROLLERS), "The other host is not remembered as the controller");

    %answers = ($UOS_PORT => [ 200, "https://127.0.0.4:443/proxy/network/status" ]);
    ($ua, $base_url) = $switch->_connect();
    is($base_url, "https://127.0.0.4:443/proxy/network", "A redirect from http to https on the same host is followed");
    is($ua->default_header('X-CSRF-Token'), 'redirected-token', "The session found at the redirected location is used");
    delete $pf::Switch::Ubiquiti::Unifi::DETECTED_CONTROLLERS{"http://127.0.0.4"};

    local $switch->{_wsTransport} = 'https';
    local $pf::Switch::Ubiquiti::Unifi::DEFAULT_HTTPS_PORT = $UOS_PORT;
    %answers = ($UOS_PORT => [ 401, "http://127.0.0.4:80/proxy/network/status" ]);
    @posts = ();
    ($ua, $base_url) = eval { $switch->_connect() };
    is($base_url, "https://127.0.0.4:8443", "A redirect from https to http is ignored: the login is not posted over http");
    delete $pf::Switch::Ubiquiti::Unifi::DETECTED_CONTROLLERS{"https://127.0.0.4"};
}

# radiusDisconnect without an open locationlog: the NAS-Identifier comes from the
# last known AP, never an empty one (#8065)
{
    my $mac = '00:65:80:65:00:01';
    my $ap  = 'aa:bb:cc:dd:ee:01';
    pf::dal::node->remove_items(-where => { mac => $mac });
    pf::dal::locationlog->remove_items(-where => { mac => $mac });
    pf::dal::locationlog_history->remove_items(-where => { mac => $mac });
    pf::dal::node->new({ mac => $mac })->insert;

    my @sent;
    my $mock = Test::MockModule->new('pf::Switch');
    $mock->mock('handleRadiusDisconnect', sub { push @sent, $_[2]; return { Code => 'Disconnect-ACK' } });
    $mock->mock('radius_deauth_connection_info', sub { {} });

    my $switch = pf::Switch::Ubiquiti::Unifi->new({ id => '10.0.0.1', ip => '10.0.0.1', radiusSecret => 'x' });

    # 1. no locationlog at all
    @sent = ();
    $switch->radiusDisconnect($mac);
    ok(!exists $sent[0]{'NAS-Identifier'}, 'no locationlog: no empty NAS-Identifier');

    # 2. closed locationlog (node deleted / disconnected)
    pf::dal::locationlog->new({ mac => $mac, switch => '10.0.0.1', switch_ip => '10.0.0.1', switch_mac => $ap,
        port => 0, vlan => 1, connection_type => 'Wireless-802.11-NoEAP', start_time => '2026-10-11 10:00:00',
        end_time => '2026-10-11 10:05:00' })->insert;
    @sent = ();
    $switch->radiusDisconnect($mac);
    is($sent[0]{'NAS-Identifier'}, 'aabbccddee01', 'closed locationlog: last AP used');
    is($sent[0]{'Calling-Station-Id'}, '00-65-80-65-00-01', 'Calling-Station-Id format');

    # 3. open locationlog on another AP wins
    pf::dal::locationlog->update_items(-set => { switch_mac => 'aa:bb:cc:dd:ee:02', end_time => '0000-00-00 00:00:00' }, -where => { mac => $mac });
    @sent = ();
    $switch->radiusDisconnect($mac);
    is($sent[0]{'NAS-Identifier'}, 'aabbccddee02', 'open locationlog: current AP used');

    # 4. caller attributes still merged
    @sent = ();
    $switch->radiusDisconnect($mac, { 'NAS-IP-Address' => '10.0.0.9' });
    is($sent[0]{'NAS-IP-Address'}, '10.0.0.9', 'additional attributes merged');


    pf::dal::locationlog->remove_items(-where => { mac => $mac });
    pf::dal::locationlog_history->remove_items(-where => { mac => $mac });
    pf::dal::node->remove_items(-where => { mac => $mac });
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
