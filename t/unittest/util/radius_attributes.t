#!/usr/bin/perl

=head1 NAME

radius_attributes

=head1 DESCRIPTION

unit test for pf::util::radius_attributes

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 67;
use Test::NoWarnings;
use pf::util::radius_attributes qw(
    parse_radius_attribute_line
    radius_attribute_definition
    radius_attribute_entries
    radius_attribute_error
    radius_attribute_log_value
    radius_attribute_lines
    radius_attribute_line_errors
);

is_deeply([parse_radius_attribute_line('Filter-Id = staff')], ['Filter-Id', 'staff'], 'name and value');
is_deeply([parse_radius_attribute_line('  Cisco-AVPair=ip:inacl#101=permit ip any any  ')], ['Cisco-AVPair', 'ip:inacl#101=permit ip any any'], 'spaces around and = in the value');
is_deeply([parse_radius_attribute_line('Filter-Id =')], [], 'no value');
is_deeply([parse_radius_attribute_line('permit ip any any')], [], 'not an attribute');
is_deeply([parse_radius_attribute_line('Extreme-Dynamic-Config = "DAI"')], ['Extreme-Dynamic-Config', 'DAI'], 'the double quotes around the value are removed');
is_deeply([parse_radius_attribute_line('Filter-Id = "a "quoted" b" ')], ['Filter-Id', 'a "quoted" b'], 'only one pair of double quotes around the value is removed');
is_deeply([parse_radius_attribute_line('Filter-Id = ""staff""')], ['Filter-Id', '"staff"'], 'the inner double quotes are kept');
is_deeply([parse_radius_attribute_line('Filter-Id = "staff')], ['Filter-Id', '"staff'], 'a double quote that is not closed is kept');
is_deeply([parse_radius_attribute_line('Filter-Id = a "b"')], ['Filter-Id', 'a "b"'], 'the double quotes inside the value are kept');
is_deeply([parse_radius_attribute_line("Filter-Id = '\"'")], ['Filter-Id', "'\"'"], 'the single quotes are kept');
is_deeply([parse_radius_attribute_line('Filter-Id = ""')], [], 'an empty value in double quotes is no value');

ok(defined((radius_attribute_definition('Filter-Id'))[0]), 'standard attribute');
ok(defined((radius_attribute_definition('Cisco-AVPair'))[0]), 'vendor attribute');
ok(defined((radius_attribute_definition('tunnel-private-group-id'))[0]), 'the name is matched without regard to case');
ok(!defined((radius_attribute_definition('Lab-Unknown-Attribute'))[0]), 'unknown attribute');

is_deeply([(radius_attribute_definition('tunnel-type'))[0, 1]], ['Tunnel-Type', 'integer'], 'the definition of an attribute, whatever the case of its name');
is_deeply([(radius_attribute_definition('cisco-avpair'))[0, 1]], ['Cisco-AVPair', 'string'], 'the definition of a vendor attribute');
is_deeply([radius_attribute_definition('Lab-Unknown-Attribute')], [], 'no definition of an unknown attribute');

# The values of the types of the dictionary
my @valid = (
    ['Session-Timeout', '3600', 'integer'],
    ['Session-Timeout', '0x0E10', 'integer in hexadecimal'],
    ['Session-Timeout', '4294967295', 'largest integer'],
    ['Tunnel-Type', 'VLAN', 'integer named in the dictionary'],
    ['Tunnel-Type', 'vlan', 'integer named in the dictionary, whatever the case'],
    ['Cisco-Disconnect-Cause', 'Unknown', 'vendor integer named in the dictionary'],
    ['PKM-SAID', '65535', 'largest short'],
    ['ALU-AAA-Lawful-Intercept-Status', '255', 'largest byte'],
    ['Acct-Input-Octets-64', '18446744073709551615', 'largest integer64'],
    ['3GPP2-GMT-Time-Zone-Offset', '-60', 'signed'],
    ['Framed-IP-Address', '10.0.0.1', 'ipaddr'],
    ['NAS-IPv6-Address', '2001:db8::1', 'ipv6addr'],
    ['Framed-IPv6-Prefix', '2001:db8::/32', 'ipv6prefix'],
    ['Event-Timestamp', '1798761600', 'date in seconds since the epoch'],
    ['Event-Timestamp', 'Jan 1 2027 08:00:00 UTC', 'date in the FreeRADIUS format'],
    ['Class', '0x0102ff', 'octets in hexadecimal'],
    ['Class', 'staff', 'octets as text'],
    ['Filter-Id', 'anything = 1, "a"', 'string'],
);
for my $test (@valid) {
    my ($name, $value, $msg) = @$test;
    is(radius_attribute_error($name, $value), undef, "valid $msg: $name = $value");
}

my @invalid = (
    ['Session-Timeout', 'abc', qr/'abc' is not a valid integer for Session-Timeout/, 'integer'],
    ['Session-Timeout', '-1', qr/not a valid integer/, 'negative integer'],
    ['Session-Timeout', '4294967296', qr/not a valid integer/, 'integer too large'],
    ['Session-Timeout', '0x100000000', qr/not a valid integer/, 'integer in hexadecimal too large'],
    ['Tunnel-Type', 'Lab-VLAN', qr/'Lab-VLAN' is not a valid value of Tunnel-Type, a number or one of .*VLAN/, 'name not in the dictionary'],
    ['PKM-SAID', '65536', qr/not a valid short/, 'short too large'],
    ['ALU-AAA-Lawful-Intercept-Status', '256', qr/not a valid byte/, 'byte too large'],
    ['3GPP2-GMT-Time-Zone-Offset', '2147483648', qr/not a valid signed/, 'signed too large'],
    ['Framed-IP-Address', '10.0.0.256', qr/not a valid ipaddr/, 'ipaddr'],
    ['Framed-IP-Address', '2001:db8::1', qr/not a valid ipaddr/, 'ipaddr with an IPv6 address'],
    ['NAS-IPv6-Address', '2001:db8::g', qr/not a valid ipv6addr/, 'ipv6addr'],
    ['Framed-IPv6-Prefix', '2001:db8::/129', qr/not a valid ipv6prefix/, 'ipv6prefix'],
    ['Event-Timestamp', 'tomorrow', qr/not a valid date/, 'date'],
    ['Event-Timestamp', 'Foo 1 2027', qr/not a valid date/, 'date with an unknown month'],
    ['Class', '0x0g', qr/not a valid octets/, 'octets in hexadecimal'],
    ['Lab-Unknown-Attribute', '1', qr/Lab-Unknown-Attribute is not in the RADIUS dictionary/, 'unknown attribute'],
    ['Auth-Type', 'Accept', qr/Auth-Type is an internal attribute of FreeRADIUS, it is not sent to the switch/, 'internal attribute'],
    ['cleartext-password', 'secret', qr/Cleartext-Password is an internal attribute of FreeRADIUS/, 'internal attribute, whatever the case'],
    ['Fall-Through', '1', qr/internal attribute of FreeRADIUS/, 'internal attribute with a number below 1000'],
);
for my $test (@invalid) {
    my ($name, $value, $error, $msg) = @$test;
    like(radius_attribute_error($name, $value) // '', $error, "invalid $msg: $name = $value");
}

is_deeply([radius_attribute_lines("# comment\n\nFilter-Id = a\r\n  \nSession-Timeout = 60")], ['Filter-Id = a', 'Session-Timeout = 60'], 'lines without comments and empty lines');
is_deeply([radius_attribute_lines(undef)], [], 'no text');
is_deeply([radius_attribute_lines(['Filter-Id = a', 'Session-Timeout = 60'])], ['Filter-Id = a', 'Session-Timeout = 60'], 'lines of an array');

is_deeply(
    [map { $_->{line} } grep { defined $_->{error} }
        radius_attribute_entries("Filter-Id = a\nLab-Unknown-Attribute = 1\npermit ip any any\n# comment")],
    ['Lab-Unknown-Attribute = 1', 'permit ip any any'],
    'invalid lines'
);

is(radius_attribute_error('Cisco-AVPair', 'shell:priv-lvl=15'), undef, 'a vendor attribute is not an internal attribute');

is(radius_attribute_log_value('Session-Timeout', '60'), '60', 'the value is written in the logs');
is(radius_attribute_log_value('Tunnel-Password', 'secret'), '********', 'a password is hidden in the logs');
is(radius_attribute_log_value('MS-MPPE-Send-Key', '0x0102'), '********', 'a key is hidden in the logs');
is(radius_attribute_log_value('Aruba-Mdps-Device-Psk', 'secret'), '********', 'a PSK is hidden in the logs');

is_deeply(
    [radius_attribute_entries("Session-Timeout = 60\nSession-Timeout = abc\nTunnel-Type = \"VLAN\"\npermit ip any any")],
    [
        { line => 'Session-Timeout = 60', name => 'Session-Timeout', value => '60', error => undef },
        { line => 'Session-Timeout = abc', name => 'Session-Timeout', value => 'abc',
          error => "'abc' is not a valid integer for Session-Timeout" },
        { line => 'Tunnel-Type = "VLAN"', name => 'Tunnel-Type', value => 'VLAN', error => undef },
        { line => 'permit ip any any', name => undef, value => undef, error => "the format is 'Attribute-Name = value'" },
    ],
    'the lines parsed and checked'
);

is_deeply(
    [radius_attribute_line_errors("Filter-Id = a\nSession-Timeout = abc\npermit ip any any\nLab-Unknown-Attribute = 1")],
    [
        "Session-Timeout = abc: 'abc' is not a valid integer for Session-Timeout",
        "permit ip any any: the format is 'Attribute-Name = value'",
        "Lab-Unknown-Attribute = 1: Lab-Unknown-Attribute is not in the RADIUS dictionary",
    ],
    'the errors of the lines'
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
