#!/usr/bin/perl

=head1 NAME

lldpRemPortIdToMac

=head1 DESCRIPTION

LLDP phone detection reads the phone MAC from lldpRemPortId. Switches return
it as raw bytes (0x001122334455) or, like ArubaOS-CX, as text
(00:11:22:33:44:55).

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More;
use Test::NoWarnings;
use pf::Switch;
use pf::Switch::Aruba::ArubaOS_CX_10_x;

my @macs = (
    [ '0x64A0E7920201',      '64:a0:e7:92:02:01', 'raw bytes as rendered by Net::SNMP' ],
    [ '64a0e7920201',        '64:a0:e7:92:02:01', 'hex without separators' ],
    [ '64:a0:e7:92:02:01',   '64:a0:e7:92:02:01', 'colon separated, as sent by ArubaOS-CX' ],
    [ '64:A0:E7:92:02:01',   '64:a0:e7:92:02:01', 'colon separated uppercase' ],
    [ '64-a0-e7-92-02-01',   '64:a0:e7:92:02:01', 'dash separated' ],
    [ '0x64A0E7920201:P1',   '64:a0:e7:92:02:01', 'raw bytes with a port suffix' ],
    [ '64:a0:e7:92:02:01:P1','64:a0:e7:92:02:01', 'colon separated with a port suffix' ],
);

my @not_macs = (
    [ undef,                 'undef' ],
    [ '',                    'empty' ],
    [ 'Gi1/0/46',            'interface name' ],
    [ '1/1/1',               'port number' ],
    [ 'SEP64A0E7920201',     'Cisco phone name' ],
    [ '64:a0:e7-92:02:01',   'mixed separators' ],
    [ '64:a0:e7:92:02',      'five octets' ],
    [ '64:a0:e7:92:02:0g',   'non hex digit' ],
);

plan tests => @macs + @not_macs + 2;

my $switch = pf::Switch::Aruba::ArubaOS_CX_10_x->new({ id => '192.168.0.1', ip => '192.168.0.1' });
can_ok($switch, 'lldpRemPortIdToMac');

for my $t (@macs) {
    my ($in, $expected, $name) = @$t;
    is($switch->lldpRemPortIdToMac($in), $expected, $name);
}

for my $t (@not_macs) {
    my ($in, $name) = @$t;
    is($switch->lldpRemPortIdToMac($in), undef, "not a MAC: $name");
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
