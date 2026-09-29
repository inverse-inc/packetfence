#!/usr/bin/perl

=head1 NAME

radius_dictionary_local

=head1 DESCRIPTION

Attributes defined in conf/radiusd/dictionary.local are merged into the
RADIUS dictionary used to build CoA and Disconnect requests (#8627).

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 19;
use Test::NoWarnings;
use File::Temp qw(tempdir);
use Storable qw(dclone);
use Net::Radius::Packet;
use pf::util::radius_dictionary qw($RADIUS_DICTIONARY);
use pf::util::radius_dictionary_local;

my $dir = tempdir(CLEANUP => 1);
sub write_file { my ($f, $c) = @_; open(my $fh, '>', $f) or die $!; print $fh $c; close $fh; }

write_file("$dir/dictionary.included", <<'EOT');
ATTRIBUTE   Lab-Included-Attr   3999   string
EOT

write_file("$dir/dictionary.local", <<'EOT');
# custom attributes of the lab
BEGIN-VENDOR    Extreme
ATTRIBUTE       Extreme-Dynamic-Config      250     string
ATTRIBUTE       Extreme-Port-Mode           251     integer
VALUE           Extreme-Port-Mode           Bounce  2
END-VENDOR      Extreme

VENDOR          Lab-Vendor      65001
ATTRIBUTE       Lab-Vendor-Attr 1   string  Lab-Vendor

ATTRIBUTE       Lab-Standard-Attr   3998    integer
VALUE           Lab-Standard-Attr   On      1

$INCLUDE dictionary.included
$INCLUDE- dictionary.missing
BEGIN-VENDOR    No-Such-Vendor
FLAGS           internal
EOT

my $dict = dclone($RADIUS_DICTIONARY);
ok(!exists $dict->{avendors}{'Extreme-Dynamic-Config'}, 'the attribute is not in the shipped dictionary');

my @warnings = pf::util::radius_dictionary_local::merge($dict, "$dir/dictionary.local");
is_deeply($dict->{vsattr}{1916}{'Extreme-Dynamic-Config'}, [250, 'string'], 'vendor block attribute added');
is($dict->{avendors}{'Extreme-Dynamic-Config'}, 'Extreme', 'vendor block attribute is known as a VSA of its vendor');
is_deeply($dict->{rvsattr}{1916}{250}, ['Extreme-Dynamic-Config', 'string'], 'reverse lookup of the vendor attribute');
is($dict->{vsaval}{1916}{251}{Bounce}, 2, 'value of a vendor attribute');
is($dict->{vendors}{'Lab-Vendor'}, 65001, 'new vendor added');
is_deeply($dict->{vsattr}{65001}{'Lab-Vendor-Attr'}, [1, 'string'], 'old style ATTRIBUTE with a vendor column');
is_deeply($dict->{attr}{'Lab-Standard-Attr'}, [3998, 'integer'], 'standard attribute added');
is($dict->{val}{3998}{On}, 1, 'value of a standard attribute');
is_deeply($dict->{attr}{'Lab-Included-Attr'}, [3999, 'string'], 'included file read');
is_deeply($dict->{vsattr}{2011}{'Huawei-Ext-Specific'}, $RADIUS_DICTIONARY->{vsattr}{2011}{'Huawei-Ext-Specific'}, 'shipped attributes kept');

is(scalar(grep { /unknown vendor No-Such-Vendor/ } @warnings), 1, 'unknown vendor reported');
is(scalar(grep { /unsupported keyword FLAGS/ } @warnings), 1, 'unsupported keyword reported');
is(scalar(grep { /dictionary.missing/ } @warnings), 0, 'a missing optional include is silent');

is_deeply([pf::util::radius_dictionary_local::merge(dclone($RADIUS_DICTIONARY), "$dir/none")], [], 'no local file, no warnings');

# a CoA-Request carrying the custom attribute is encoded and decoded back
my $packet = Net::Radius::Packet->new($dict);
$packet->set_code('CoA-Request');
$packet->set_identifier(1);
$packet->set_authenticator('0123456789abcdef');
$packet->set_attr('Calling-Station-Id', '02-00-00-00-00-01');
$packet->set_vsattr('Extreme', 'Extreme-Dynamic-Config', 'PORTBOUNCE');
my $raw = $packet->pack;
like($raw, qr/\x1a.\x00\x00\x07\x7c\xfa\x0cPORTBOUNCE/s, 'the VSA is on the wire (vendor 1916, type 250)');
my $decoded = Net::Radius::Packet->new($dict, $raw);
is_deeply([$decoded->vsattr(1916, 'Extreme-Dynamic-Config')], [['PORTBOUNCE']], 'the VSA decodes back');
is($decoded->attr('Calling-Station-Id'), '02-00-00-00-00-01', 'standard attribute still encoded');

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
