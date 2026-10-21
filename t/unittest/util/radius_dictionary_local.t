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

use Test::More tests => 36;
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
ATTRIBUTE       Extreme-Dynamic-Config      252     string
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
is_deeply($dict->{vsattr}{1916}{'Extreme-Dynamic-Config'}, [252, 'string'], 'vendor block attribute added');
is($dict->{avendors}{'Extreme-Dynamic-Config'}, 'Extreme', 'vendor block attribute is known as a VSA of its vendor');
is_deeply($dict->{rvsattr}{1916}{252}, ['Extreme-Dynamic-Config', 'string'], 'reverse lookup of the vendor attribute');
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

# Lines that can't be used must not replace the shipped attributes
write_file("$dir/dictionary.bad", <<'EOT');
BEGIN-VENDOR    Extrme
ATTRIBUTE       Extreme-Dynamic-Config      252     string
VALUE           Extreme-Dynamic-Config      Bounce  1
END-VENDOR      Extrme
ATTRIBUTE       Lab-Typo-Attr   1   string  Typo-Vendor
ATTRIBUTE       Lab-Secret-Attr 3997    string  encrypt=1
VENDOR          Lab-Wide        65002   format=2,1
BEGIN-VENDOR    Lab-Wide
ATTRIBUTE       Lab-Wide-Attr   2   string
END-VENDOR      Lab-Wide
BEGIN-VENDOR    Extreme format=Extended-Vendor-Specific-1
ATTRIBUTE       Lab-Extended-Attr   3   string
END-VENDOR      Extreme
BEGIN-VENDOR    extreme
ATTRIBUTE       Lab-Lowercase-Vendor-Attr   250     string
END-VENDOR      extreme
ATTRIBUTE       Lab-Lowercase-Old-Style-Attr    249     string  extreme
EOT
my $bad = dclone($RADIUS_DICTIONARY);
my @bad_warnings = pf::util::radius_dictionary_local::merge($bad, "$dir/dictionary.bad");
is_deeply($bad->{rattr}{252}, $RADIUS_DICTIONARY->{rattr}{252}, 'an attribute in the block of an unknown vendor does not replace a standard one');
ok(!exists $bad->{attr}{'Extreme-Dynamic-Config'}, 'an attribute in the block of an unknown vendor is not added');
is(scalar(grep { /inside the block of vendor Extrme/ } @bad_warnings), 2, 'ATTRIBUTE and VALUE in the block of an unknown vendor are reported');
is_deeply($bad->{rattr}{1}, $RADIUS_DICTIONARY->{rattr}{1}, 'an old style attribute of an unknown vendor does not replace User-Name');
is(scalar(grep { /unknown vendor Typo-Vendor, ignored/ } @bad_warnings), 1, 'an old style unknown vendor is reported');
is_deeply($bad->{attr}{'Lab-Secret-Attr'}, [3997, 'string'], 'options in place of the vendor make a standard attribute');
ok(!exists $bad->{vendors}{'Lab-Wide'}, 'a vendor with another format is not added');
ok(!exists $bad->{attr}{'Lab-Wide-Attr'} && !exists $bad->{avendors}{'Lab-Wide-Attr'}, 'the attributes of a vendor with another format are ignored');
is(scalar(grep { /only format=1,1 is supported/ } @bad_warnings), 2, 'unsupported vendor formats are reported');
ok(!exists $bad->{attr}{'Lab-Extended-Attr'} && !exists $bad->{avendors}{'Lab-Extended-Attr'}, 'the attributes of an extended vendor block are ignored');
is($bad->{avendors}{'Lab-Lowercase-Vendor-Attr'}, 'Extreme', 'a vendor block name is matched without regard to case');
is($bad->{avendors}{'Lab-Lowercase-Old-Style-Attr'}, 'Extreme', 'an old style vendor name is matched without regard to case');

# a CoA-Request carrying the custom attribute is encoded and decoded back
# BEGIN-TLV / END-TLV: the sub-attributes are numbered from 1, they must not
# replace User-Name or the vendor's attribute 1
write_file("$dir/dictionary.tlv", <<'EOT');
ATTRIBUTE       Lab-Tlv             3996    tlv
BEGIN-TLV       Lab-Tlv
ATTRIBUTE       Lab-Tlv-Sub         1       string
VALUE           Lab-Tlv-Sub         One     1
BEGIN-TLV       Lab-Tlv-Nested
ATTRIBUTE       Lab-Tlv-Nested-Sub  2       integer
END-TLV         Lab-Tlv-Nested
END-TLV         Lab-Tlv
BEGIN-VENDOR    Extreme
BEGIN-TLV       Lab-Vendor-Tlv
ATTRIBUTE       Lab-Vendor-Tlv-Sub  1       string
END-TLV         Lab-Vendor-Tlv
ATTRIBUTE       Lab-After-Tlv-Attr  250     string
END-VENDOR      Extreme
EOT
my $tlv = dclone($RADIUS_DICTIONARY);
my @tlv_warnings = pf::util::radius_dictionary_local::merge($tlv, "$dir/dictionary.tlv");
is_deeply($tlv->{rattr}{1}, $RADIUS_DICTIONARY->{rattr}{1}, 'a TLV sub-attribute does not replace User-Name');
is_deeply($tlv->{rvsattr}{1916}{1}, $RADIUS_DICTIONARY->{rvsattr}{1916}{1}, "a TLV sub-attribute in a vendor block does not replace the vendor's attribute");
ok(!exists $tlv->{attr}{'Lab-Tlv-Sub'} && !exists $tlv->{avendors}{'Lab-Vendor-Tlv-Sub'} && !exists $tlv->{attr}{'Lab-Tlv-Nested-Sub'}, 'the TLV sub-attributes are not added');
is($tlv->{avendors}{'Lab-After-Tlv-Attr'}, 'Extreme', 'the attributes after END-TLV are read again');
is(scalar(grep { /inside TLV/ } @tlv_warnings), 4, 'the ATTRIBUTE and VALUE lines inside a TLV are reported');

my $packet = Net::Radius::Packet->new($dict);
$packet->set_code('CoA-Request');
$packet->set_identifier(1);
$packet->set_authenticator('0123456789abcdef');
$packet->set_attr('Calling-Station-Id', '02-00-00-00-00-01');
$packet->set_vsattr('Extreme', 'Extreme-Dynamic-Config', 'PORTBOUNCE');
my $raw = $packet->pack;
like($raw, qr/\x1a.\x00\x00\x07\x7c\xfc\x0cPORTBOUNCE/s, 'the VSA is on the wire (vendor 1916, type 252)');
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
