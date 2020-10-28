#!/usr/bin/perl

=head1 NAME

no_timestamp

=head1 DESCRIPTION

unit test for no_timestamp

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More;
use Test::NoWarnings;
use DBI;
use pf::config qw(%Config);
my $PF_DIR = '/usr/local/pf';
my $schema = "$PF_DIR/db/pf-schema-X.Y.Z.sql";
my $db_name = "pf_smoke_test__no_timestamp_$$";
my ($dbuser, $dbpass) = @{$Config{database}}{qw(user pass)};
my $dbh     = DBI->connect( "DBI:mysql:host=localhost", $dbuser, $dbpass, { RaiseError => 1 } );
$dbh->do("DROP DATABASE IF EXISTS $db_name;") or die $dbh->errstr;
$dbh->do("CREATE DATABASE $db_name;")         or die $dbh->errstr;
system("mysql -u\"$dbuser\" -p\"$dbpass\" $db_name < $schema");
$dbh->do("USE $db_name;") or $dbh->errstr;
use Data::Dumper;
my $sql =
"SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA = '$db_name' and lower(COLUMN_TYPE) LIKE 'timestamp%' ORDER BY TABLE_NAME, ORDINAL_POSITION";

my $columns = $dbh->selectall_arrayref($sql, { Slice => {} });
for my $c (@$columns) {
    fail("$c->{TABLE_NAME}.$c->{COLUMN_NAME} is a timestamp type '$c->{COLUMN_TYPE}'");
}

done_testing( scalar @$columns + 1 );


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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

