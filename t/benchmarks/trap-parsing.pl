#!/usr/bin/perl
=head1 NAME

trap-parsing.pl

=head1 DESCRIPTION

Some performance benchmarks on some regexp

=cut

use strict;
use warnings;
use diagnostics;

use Benchmark qw(cmpthese timethese);

use lib '/usr/local/pf/lib';

use pf::util;
use pf::Switch::constants;

=head1 new vs old trap parsing techniques (fix for #1098)

=cut

my $trap_hex = '2011-03-17|21:48:07|UDP: [10.0.0.51]:1024|10.0.0.51|BEGIN TYPE 6 END TYPE BEGIN SUBTYPE .5 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.4.1.45.1.6.5.3.12.1.1.1.1 = INTEGER: 1|.1.3.6.1.4.1.45.1.6.5.3.12.1.2.1.1 = INTEGER: 1|.1.3.6.1.4.1.45.1.6.5.3.12.1.3.1.1 = Hex-STRING: F0 4D A2 EB D2 5C  END VARIABLEBINDINGS';
my $trap_string = '2011-05-19|19:36:21|UDP: [10.0.0.51]:1025|10.0.0.51|BEGIN TYPE 6 END TYPE BEGIN SUBTYPE .5 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.4.1.45.1.6.5.3.12.1.1.1.24 = INTEGER: 1|.1.3.6.1.4.1.45.1.6.5.3.12.1.2.1.24 = INTEGER: 24|.1.3.6.1.4.1.45.1.6.5.3.12.1.3.1.24 = STRING: "\\\\&
8xG" END VARIABLEBINDINGS';
my $trap_unknown = '2011-03-17|21:24:43|UDP: [10.0.0.51]:1024|10.0.0.51|BEGIN TYPE 3 END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.2.1.2.2.1.1.1 = INTEGER: 1|.1.3.6.1.2.1.2.2.1.7.1 = INTEGER: up(1)|.1.3.6.1.2.1.2.2.1.8.1 = INTEGER: up(1)|.1.3.6.1.4.1.45.1.6.15.1.1.1.2.1 = INTEGER: 0|.1.3.6.1.4.1.45.1.6.15.1.1.1.3.1 = INTEGER: 1 END VARIABLEBINDINGS';

sub old_parser {
    my ($trapString) = @_;

    my $trapHashRef = {};
    if ( $trapString =~ /\|\.1\.3\.6\.1\.4\.1\.45\.1\.6\.5\.3\.12\.1\.3\.(\d+)\.(\d+) = Hex-STRING: ([0-9A-F]{2} [0-9A-F]{2} [0-9A-F]{2} [0-9A-F]{2} [0-9A-F]{2} [0-9A-F]{2})/) {   

        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1 * 64 + $2;
        $trapHashRef->{'trapMac'} = lc($3);
        $trapHashRef->{'trapMac'} =~ s/ /:/g;

    } elsif ( $trapString =~ /\|\.1\.3\.6\.1\.4\.1\.45\.1\.6\.5\.3\.12\.1\.3\.(\d+)\.(\d+) = STRING:\ "(.+)"/s) {
        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1 * 64 + $2;
        my $mac = $3;
        $mac =~ s/\\\\/\\/g; # replaces \\ with \
        $mac = unpack("H*", $mac);
        $mac =~ s/([a-f0-9]{2})(?!$)/$1:/g; # builds groups of two separ ated by :
        $trapHashRef->{'trapMac'} = $mac;
    } else {
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub new_parser {
    my ($trapString) = @_;

    my $trapHashRef = {};
    if ( $trapString =~ /\|\.1\.3\.6\.1\.4\.1\.45\.1\.6\.5\.3\.12\.1\.3\.(\d+)\.(\d+) = $SNMP::MAC_ADDRESS_FORMAT/) {
        $trapHashRef->{'trapType'}    = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1 * 64 + $2;
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($3);
    } else {
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

my $result = timethese(100000, {
    old_parser => sub { 
        old_parser($trap_hex);
        old_parser($trap_string);
        old_parser($trap_unknown); 
    },
    new_parser => sub { 
        new_parser($trap_hex);
        new_parser($trap_string);
        new_parser($trap_unknown);
    }
});
cmpthese($result);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
