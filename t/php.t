#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More;
use Test::NoWarnings;

use TestUtils qw(get_all_php);

my @php_files = TestUtils::get_all_php();

# all files + no warnings
plan tests => scalar @php_files + 1;


foreach my $currentPHPFile (@php_files) {
    ok( system("/usr/bin/php -l $currentPHPFile 2>&1") == 0,
        "$currentPHPFile compiles" );
}

# TODO test for @license, @copyright and @author presence

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

