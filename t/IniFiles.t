#!/usr/bin/perl

use strict;
use warnings;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 15;

use_ok('pf::IniFiles');

my $ini = new_ok('pf::IniFiles');

# print "SetSectionComment .................";
$ini->newval("Section1", "Parameter1", "Value1");
$ini->newval("Section1", "Parameter2", "Value2");

# CopySection
$ini->CopySection( 'Section1', 'Section2' );

for my $n (3 .. 6) {
    $ini->newval("Section2", "Parameter$n", "Value$n");
}

is_deeply(
    [$ini->Parameters( 'Section2' )],
    [qw(Parameter1 Parameter2 Parameter3 Parameter4 Parameter5 Parameter6)],
    "CopySection was successful."
);

$ini->CopySection( 'Section1', 'Section3' );
$ini->CopySection( 'Section1', 'Section4' );

ok($ini->ResortSections('Section2'), "Resorting");

is_deeply( [$ini->Sections], [qw(Section1 Section2 Section3 Section4)], 'Resort no affect');

ok($ini->ResortSections('Section3', 'Section2'), "Resorting");
is_deeply( [$ini->Sections], [qw(Section1 Section3 Section2 Section4)], 'Resort in the middle');

ok($ini->ResortSections('Section4', 'Section3', 'Section2', 'Section1'), "Resorting");
is_deeply( [$ini->Sections], [qw(Section4 Section3 Section2 Section1)], 'Resort all' );

ok(!$ini->ResortSections('Section7', 'Section2', 'Section3'), "Resorting failed");
is_deeply( [$ini->Sections], [qw(Section4 Section3 Section2 Section1)], 'Order is the same' );

# DeleteSection
$ini->DeleteSection( 'Section1' );
# TEST
ok( ! $ini->Parameters( 'Section1' ), "DeleteSection was successful." );

# RenameSection
$ini->RenameSection( 'Section2', 'Section1' );

ok( ! $ini->Parameters( 'Section2' ) && $ini->Parameters( 'Section1' ) && $ini->val('Section1','Parameter1') eq 'Value1'  , "RenameSection was successful." );

my $with_imported = pf::IniFiles->new(-import => $ini);

$with_imported->newval('Section1', 'Parameter9', 'Value9');

ok($with_imported->is_imported('Section1', 'Parameter1'), "Section1 => Parameter1 is imported");

use Data::Dumper;
ok(!$with_imported->is_imported('Section1', 'Parameter9'), "Section1.Parameter9 is not imported");

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

