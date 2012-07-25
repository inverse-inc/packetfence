#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
use Test::More tests => 18;
use Test::NoWarnings;

BEGIN { use_ok('pf::util') }

# valid_mac
ok(valid_mac("aa:bb:cc:dd:ee:ff"), "validate MAC address of the form xx:xx:xx:xx:xx:xx");
ok(valid_mac("aa-bb-cc-dd-ee-ff"), "validate MAC address of the form xx-xx-xx-xx-xx-xx");
ok(valid_mac("aabb-ccdd-eeff"), "validate MAC address of the form xxxx-xxxx-xxxx");
ok(valid_mac("aabb.ccdd.eeff"), "validate MAC address of the form xxxx.xxxx.xxxx");
ok(valid_mac("aabbccddeeff"), "validate MAC address of the form xxxxxxxxxxxx");

# clean_mac
is(clean_mac("aabbccddeeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxxxxxxxxxx");
is(clean_mac("aa:bb:cc:dd:ee:ff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xx:xx:xx:xx:xx:xx");
is(clean_mac("aa-bb-cc-dd-ee-ff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xx-xx-xx-xx-xx-xx");
is(clean_mac("aabb-ccdd-eeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxx-xxxx-xxxx");
is(clean_mac("aabb.ccdd.eeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxx.xxxx.xxxx");
is(clean_mac("aabbccddeeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxxxxxxxxxx");

# oid2mac / mac2oid
is( oid2mac('240.77.162.203.217.197'), 'f0:4d:a2:cb:d9:c5', "oid2mac legit conversion" );
# this throws warnings
# is( oid2mac(), undef, "oid2mac return undef on failure" );
is( mac2oid('f0:4d:a2:cb:d9:c5'), '240.77.162.203.217.197', "mac2oid legit conversion" );
# this throws warnings
# is( mac2oid(), undef, "mac2oid return undef on failure" );

# regression test for get_translatable_time
is_deeply(
    [ get_translatable_time("3D") ], 
    ["day", "days", 3],
    "able to translate new format with capital date modifiers"
);

is( format_mac_as_cisco('f0:4d:a2:cb:d9:c5'), 'f04d.a2cb.d9c5', 'format_mac_as_cisco legit conversion');
is( format_mac_as_cisco(), undef, 'format_mac_as_cisco return undef on failure');

# TODO add more tests, we should test:
#  - all methods ;)

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2010-2012 Inverse inc.

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

