#!/usr/bin/perl

use strict;
use warnings;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use PfFilePaths;
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

