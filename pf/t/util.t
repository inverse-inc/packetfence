#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
use Test::More tests => 13;
use Test::NoWarnings;

BEGIN { use_ok('pf::util') }

# valid_mac
ok(valid_mac("aa:bb:cc:dd:ee:ff"), "validate MAC address of the form xx:xx:xx:xx:xx:xx");
ok(valid_mac("aa-bb-cc-dd-ee-ff"), "validate MAC address of the form xx-xx-xx-xx-xx-xx");
ok(valid_mac("aabb-ccdd-eeff"), "validate MAC address of the form xxxx-xxxx-xxxx");
ok(valid_mac("aabb.ccdd.eeff"), "validate MAC address of the form xxxx.xxxx.xxxx");
ok(valid_mac("aabbccddeeff"), "validate MAC address of the form xxxxxxxxxxxx");

# clean_mac
is(clean_mac("aa:bb:cc:dd:ee:ff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xx:xx:xx:xx:xx:xx");
is(clean_mac("aa-bb-cc-dd-ee-ff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xx-xx-xx-xx-xx-xx");
is(clean_mac("aabb-ccdd-eeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxx-xxxx-xxxx");
is(clean_mac("aabb.ccdd.eeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxx.xxxx.xxxx");
is(clean_mac("aabbccddeeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxxxxxxxxxx");

# regression test for get_translatable_time
is_deeply(
    [ get_translatable_time("3D") ], 
    ["day", "days", 3],
    "able to translate new format with capital date modifiers"
);

# TODO add more tests, we should test:
#  - all methods ;)

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2010-2011 Inverse inc.

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

