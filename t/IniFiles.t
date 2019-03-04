#!/usr/bin/perl

use strict;
use warnings;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 5;

use_ok('pf::IniFiles');

my $ini = new_ok('pf::IniFiles');

# print "SetSectionComment .................";
$ini->newval("Section1", "Parameter1", "Value1");

# CopySection
$ini->CopySection( 'Section1', 'Section2' );

ok( $ini->Parameters( 'Section2' ), "CopySection was successful." );

# DeleteSection
$ini->DeleteSection( 'Section1' );
# TEST
ok( ! $ini->Parameters( 'Section1' ), "DeleteSection was successful." );

# RenameSection
$ini->RenameSection( 'Section2', 'Section1' );

ok( ! $ini->Parameters( 'Section2' ) && $ini->Parameters( 'Section1' ) && $ini->val('Section1','Parameter1') eq 'Value1'  , "RenameSection was successful." );


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

