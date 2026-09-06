#!/usr/bin/perl

=head1 NAME

dns

=head1 DESCRIPTION

unit test for pf::connector::dns

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 12;
use Test::NoWarnings;

use pf::connector::dns qw(parse_dns_server_line format_dns_server expand_dns_servers flatten_dns_servers dns_server_id);

is_deeply(
    parse_dns_server_line("10.5.1.53 port=53 tunnel_port=30001 domains=inverse.local,corp.local"),
    { ip => '10.5.1.53', port => 53, tunnel_port => 30001, domains => ['inverse.local', 'corp.local'] },
    "parse a full line"
);

is_deeply(
    parse_dns_server_line("  10.5.1.53  "),
    { ip => '10.5.1.53', port => 53, tunnel_port => '', domains => [] },
    "parse a bare IP: default port, no tunnel port, no domain"
);

is(parse_dns_server_line("10.5.1.53 bogus=1"), undef, "unknown word is rejected");
is(parse_dns_server_line(""), undef, "empty line is rejected");

is(
    format_dns_server({ ip => '10.5.1.53', port => 53, tunnel_port => 30001, domains => ['inverse.local', ' corp.local '] }),
    "10.5.1.53 port=53 tunnel_port=30001 domains=inverse.local,corp.local",
    "format trims and joins the domains"
);

is(format_dns_server({ ip => '10.5.1.53', port => 53, tunnel_port => '', domains => [] }), "10.5.1.53 port=53", "format leaves out empty tunnel port and domains");

my $line = "10.5.1.53 port=5353 tunnel_port=30010 domains=a.local";
is(format_dns_server(parse_dns_server_line($line)), $line, "round trip");

is(dns_server_id('amsterdam', { ip => '10.5.1.53', port => 53 }), 'amsterdam:10.5.1.53:53', "derived namespace id");

my $cfg = { dns_servers => "10.5.1.53 domains=a.local\ngarbage=x\n10.5.1.54 port=53 domains=b.local" };
expand_dns_servers($cfg);
is_deeply([ map { $_->{ip} } @{ $cfg->{dns_servers} } ], ['10.5.1.53', '10.5.1.54'], "expand drops unparseable lines");

flatten_dns_servers($cfg);
is_deeply($cfg->{dns_servers}, ["10.5.1.53 port=53 domains=a.local", "10.5.1.54 port=53 domains=b.local"], "flatten back to lines");

flatten_dns_servers(my $empty = { dns_servers => [] });
ok(!defined $empty->{dns_servers}, "empty list flattens to undef so the key is removed");

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
