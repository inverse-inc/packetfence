#!/usr/bin/perl

=head1 NAME

Unifi

=head1 DESCRIPTION

unit test for pf::Switch::Ubiquiti::Unifi against a UniFi OS controller
(#9260 / #9107): the CSRF token of the session must be captured and sent on
the commands, from the login response, from the session cookie when the
controller sends no header, and refreshed when the controller rotates it.

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

use Test::More tests => 18;

#This test will running last
use Test::NoWarnings;

use pf::Switch::Ubiquiti::Unifi;
use pf::file_paths qw($var_dir);
use Symbol 'gensym';
use IPC::Open3;
use POSIX qw(WNOHANG);
use LWP::UserAgent;
use JSON::MaybeXS;

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
    SNMPUseConnector => 'N',
    radiusDeauthUseConnector => 'N',
});
ok($switch, "Got the Unifi controller switch");
is(ref($switch), 'pf::Switch::Ubiquiti::Unifi', "It is a Unifi controller");

my $mock = LWP::UserAgent->new();

# 1. Fresh session: status answers 401, login gives the token
my ($ua, $base_url) = $switch->_connect();
is($base_url, "http://127.0.0.3:$UOS_PORT/proxy/network", "UniFi OS detected: the API is under /proxy/network");
is($ua->default_header('X-CSRF-Token'), 'csrf-token-1', "The CSRF token of the login response is sent on every request");

my $post = $ua->post("$base_url/api/s/default/cmd/stamgr", Content => encode_json({ cmd => 'authorize-guest', mac => 'aa:bb:cc:dd:ee:ff', minutes => 60 }));
ok($post->is_success, "A command with the CSRF token is accepted") or diag($post->status_line);
is(decode_json($post->decoded_content)->{data}[0]{mac}, 'aa:bb:cc:dd:ee:ff', "The command reached the controller");
is($ua->default_header('X-CSRF-Token'), 'csrf-token-2', "The rotated token handed out by the controller replaces the old one");

# The same session without the header is what UniFi OS refuses (the bug)
my $bare = LWP::UserAgent->new();
$bare->cookie_jar($ua->cookie_jar);
$bare->default_header('Content-Type' => 'application/json');
my $refused = $bare->post("$base_url/api/s/default/cmd/stamgr", Content => encode_json({ cmd => 'authorize-guest', mac => 'aa:bb:cc:dd:ee:ff' }));
is($refused->code, 403, "The controller refuses the command without the CSRF token");

# 2. Existing session: no login, the token comes with the status response
($ua, $base_url) = $switch->_connect();
is($base_url, "http://127.0.0.3:$UOS_PORT/proxy/network", "Still the UniFi OS API");
is($ua->default_header('X-CSRF-Token'), 'csrf-token-1', "The token comes with the status response of an authenticated session");

# 3. Controller sending no CSRF header: the token is read from the TOKEN cookie (JWT)
ok($mock->post("http://127.0.0.3:$UOS_PORT/mock/csrf-headers/off")->is_success, "Mock: no CSRF headers");
unlink $cookie_file;
($ua, $base_url) = $switch->_connect();
is($ua->default_header('X-CSRF-Token'), 'csrf-token-1', "The token is taken from the csrfToken claim of the session cookie");
$post = $ua->post("$base_url/api/s/default/cmd/stamgr", Content => encode_json({ cmd => 'unauthorize-guest', mac => 'aa:bb:cc:dd:ee:ff' }));
ok($post->is_success, "A command with the cookie-derived token is accepted") or diag($post->status_line);
ok($mock->post("http://127.0.0.3:$UOS_PORT/mock/csrf-headers/on")->is_success, "Mock: CSRF headers back on");

# 4. The per-client lookup of Network 10.6 answers 400: the site scan must not die
my $sites = $ua->get("$base_url/api/self/sites");
ok($sites->is_success, "Site list readable through the prefixed API");
my $sta = $ua->get("$base_url/api/s/default/stat/sta/aa:bb:cc:dd:ee:ff");
is($sta->code, 400, "Network 10.6 answers 400 to the per-client lookup (the command is then sent to every site)");

# 5. Wrong credentials: the login is refused with 403 and _connect dies
{
    unlink $cookie_file;
    local $switch->{_wsPwd} = 'wrong';
    my $died = !eval { $switch->_connect(); 1 };
    ok($died, "A refused login makes _connect die instead of returning a broken session");
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
