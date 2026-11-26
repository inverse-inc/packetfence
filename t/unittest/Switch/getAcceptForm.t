#!/usr/bin/perl

=head1 NAME

getAcceptForm

=head1 DESCRIPTION

The web release forms of the switches format the values of the external
portal session for the place they are inserted in

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 44;
use Test::NoWarnings;

use pf::web::release_form qw(html_attr js_string http_url url_host url_port url_param);
use pf::Switch::AeroHIVE::AP;
use pf::Switch::Cambium;
use pf::Switch::CoovaChilli;
use pf::Switch::F5;
use pf::Switch::Fortinet::FortiGate;
use pf::Switch::Meraki::MR;
use pf::Switch::Mikrotik;
use pf::Switch::Mojo;
use pf::Switch::Ruckus;
use pf::Switch::Xirrus;

my $markup = q{"><b id="markup">x</b><};
my $action = 'javascript:void(0)';
my %action_params = map { ("ecwp-original-param-$_" => 1) } qw(post post_url login_url link-login-only ga_srvr uamip uamport);

# An external portal session with the same markup in every value, and a
# non-http URL in the values used as form actions or hosts
{
    package test_session;
    sub new { my ($class, %values) = @_; bless { %values }, $class }
    sub param { my ($self, $name) = @_; exists $self->{$name} ? $self->{$name} : $action_params{$name} ? $action : $markup }
}

{
    no warnings 'redefine';
    *pf::Switch::AeroHIVE::AP::node_view = sub { { last_ssid => $markup } };
}

my $mac = '00:11:22:33:44:55';
my @drivers = map { "pf::Switch::$_" } qw(AeroHIVE::AP Cambium CoovaChilli F5 Fortinet::FortiGate Meraki::MR Mikrotik Mojo Ruckus Xirrus);

for my $driver (@drivers) {
    my $switch = $driver->new({ id => '192.0.2.1', ip => '192.0.2.1' });
    my $form = $switch->getAcceptForm($mac, $markup, test_session->new, $markup);
    ok(index($form, '<b id="markup">') == -1, "$driver: the values are not inserted as markup");
    ok($form !~ /(?:action="|location = "|host = ")javascript:/, "$driver: a non-http URL is not used as form action, location or host");
}

# Helpers
is(html_attr(q{a"b<c>&'}), 'a&quot;b&lt;c&gt;&amp;&#39;', 'html_attr');
is(html_attr(undef), '', 'html_attr of undef');
is(js_string(q{a"b</script>}), q{"a\\"b<\\/script>"}, 'js_string');
is(js_string("\x{2028}"), q{"\\u2028"}, 'js_string escapes the line separators');
is(http_url('https://fw.example.org:1000/fgtauth?abc'), 'https://fw.example.org:1000/fgtauth?abc', 'http_url keeps an https URL');
is(http_url('http://192.0.2.1/login'), 'http://192.0.2.1/login', 'http_url keeps an http URL');
is(http_url('javascript:void(0)'), '', 'http_url refuses javascript:');
is(http_url('//example.org/x'), '', 'http_url refuses a URL without scheme');
is(http_url('http://:/logon'), '', 'http_url refuses a URL without host');
is(http_url('http://[2001:db8::1]:8080/x'), 'http://[2001:db8::1]:8080/x', 'http_url keeps an IPv6 URL');
is(url_host('[2001:db8::1]'), '[2001:db8::1]', 'url_host keeps an IPv6 address in brackets');
is(url_host('192.0.2.1'), '192.0.2.1', 'url_host keeps an IP address');
is(url_host('ap.example.org'), 'ap.example.org', 'url_host keeps a host name');
is(url_host('evil.example.org/x?'), '', 'url_host refuses a path');
is(url_port('3990'), '3990', 'url_port keeps a port');
is(url_port('3990/x'), '', 'url_port refuses other values');
is(url_param('a b&c=d'), 'a%20b%26c%3Dd', 'url_param');

# Expected values are kept
{
    my $session = test_session->new('ecwp-original-param-post' => 'https://fw.example.org:1000/fgtauth', 'ecwp-original-param-magic' => '0123abcd');
    my $form = pf::Switch::Fortinet::FortiGate->new({ id => '192.0.2.1' })->getAcceptForm($mac, '', $session);
    like($form, qr{action="https://fw\.example\.org:1000/fgtauth"}, 'FortiGate: the form action');
    like($form, qr{name="magic" value="0123abcd"}, 'FortiGate: the magic');
}

{
    my $form = pf::Switch::Xirrus->new({ id => '192.0.2.1' })->getAcceptForm($mac, 'http://example.org/', test_session->new);
    like($form, qr{window\.location = ""}, 'Xirrus: no logon URL without a valid host');
    my $session = test_session->new('ecwp-original-param-uamip' => '10.0.0.1', 'ecwp-original-param-uamport' => '3990', 'ecwp-original-param-challenge' => '00112233445566778899aabbccddeeff');
    $form = pf::Switch::Xirrus->new({ id => '192.0.2.1' })->getAcceptForm($mac, 'http://example.org/?a=1&b=2', $session);
    like($form, qr{window\.location = "http://10\.0\.0\.1:3990/logon\?username=00-11-22-33-44-55&password=[0-9a-f]{32}&userurl=http%3A%2F%2Fexample\.org%2F%3Fa%3D1%26b%3D2"}, 'Xirrus: the logon URL with its parameters encoded');
}

{
    my $session = test_session->new('ecwp-original-param-uamip' => '10.0.0.1', 'ecwp-original-param-uamport' => '3990');
    my $form = pf::Switch::CoovaChilli->new({ id => '192.0.2.1' })->getAcceptForm($mac, '', $session);
    like($form, qr{chilliController\.host = "10\.0\.0\.1";}, 'CoovaChilli: the host');
    like($form, qr{chilliController\.port = "3990";}, 'CoovaChilli: the port');
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
