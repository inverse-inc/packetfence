#!/usr/bin/perl

=head1 NAME

client_ip

=head1 DESCRIPTION

IP address of the client of the captive portal, and the haproxy-portal rules
for the forwarding headers

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 21;
use Test::NoWarnings;

use pf::web::client_ip;
use pf::services::manager::haproxy_portal;

my %trusted = map { $_ => 1 } qw(127.0.0.1 ::1 100.64.0.1 192.0.2.10 192.0.2.11);
my $trusted = \%trusted;
sub client_ip { pf::web::client_ip::client_ip(@_[0, 1], $trusted) }

is(client_ip('100.64.0.1', '10.0.0.5'), '10.0.0.5', 'local proxy: the forwarded address');
is(client_ip('127.0.0.1', '10.0.0.5'), '10.0.0.5', 'loopback proxy: the forwarded address');
is(client_ip('100.64.0.1', '10.0.0.99, 10.0.0.5'), '10.0.0.5', 'the right-most forwarded address');
is(client_ip('100.64.0.1', '10.0.0.99,10.0.0.5'), '10.0.0.5', 'the right-most forwarded address (no space)');
is(client_ip('100.64.0.1', '10.0.0.5, 192.0.2.10'), '10.0.0.5', 'the load balancer address is skipped');
is(client_ip('100.64.0.1', '10.0.0.5, 192.0.2.11, 192.0.2.10'), '10.0.0.5', 'the load balancers addresses are skipped');
is(client_ip('100.64.0.1', undef), '100.64.0.1', 'local proxy without header: the peer');
is(client_ip('100.64.0.1', '127.0.0.1'), '100.64.0.1', 'local proxy with trusted addresses only: the peer');
is(client_ip('10.0.0.7', '10.0.0.5'), '10.0.0.7', 'other peer: the header is ignored');
is(client_ip('10.0.0.7', '127.0.0.1'), '10.0.0.7', 'other peer: a loopback header is ignored');
is(client_ip('::1', '2001:db8::5'), '2001:db8::5', 'IPv6 loopback proxy');

ok(pf::web::client_ip::is_internal_preview('100.64.0.1', '127.0.0.1', $trusted), 'preview from the local proxy');
ok(!pf::web::client_ip::is_internal_preview('10.0.0.7', '127.0.0.1', $trusted), 'no preview from another peer');
ok(!pf::web::client_ip::is_internal_preview('100.64.0.1', '127.0.0.10', $trusted), 'no preview for another address');
ok(!pf::web::client_ip::is_internal_preview('100.64.0.1', '10.0.0.5, 127.0.0.1', $trusted), 'no preview for a list');
ok(!pf::web::client_ip::is_internal_preview('100.64.0.1', undef, $trusted), 'no preview without the header');

my $default_trusted = pf::web::client_ip::trusted_proxies();
ok(
    (scalar grep { $default_trusted->{$_} } qw(127.0.0.1 ::1 100.64.0.1)) == 3,
    'the local addresses are trusted proxies'
);

is(
    pf::services::manager::haproxy_portal::forwarded_headers_rules(''),
    "        http-request del-header X-Forwarded-For-Packetfence\n        http-request del-header X-Forwarded-For",
    'without load balancers, both headers are removed'
);

is(
    pf::services::manager::haproxy_portal::forwarded_headers_rules('192.0.2.10, 192.0.2.11'),
    "        http-request del-header X-Forwarded-For-Packetfence\n        http-request del-header X-Forwarded-For unless { src 192.0.2.10 192.0.2.11 }",
    'with load balancers, their X-Forwarded-For header is kept'
);

is(
    pf::services::manager::haproxy_portal::forwarded_headers_rules(undef),
    "        http-request del-header X-Forwarded-For-Packetfence\n        http-request del-header X-Forwarded-For",
    'undefined load balancers'
);

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
