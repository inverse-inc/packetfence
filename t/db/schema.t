#!/usr/bin/perl

=head1 NAME

schema

=cut

=head1 DESCRIPTION

test the latest schema of PacketFence
Requires the root db password to be set in the environmentally variable PF_TEST_DB_PASS

Example:

  PF_TEST_DB_PASS=passwd perl t/db/schema.t

=cut

use strict;
use warnings;
use lib '/usr/local/pf/lib';
use DBI;
use FindBin qw($Bin);
use File::Slurp qw(read_file);
use pf::file_paths qw($install_dir);

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}


use Test::More tests => 2;                      # last test to print

use Test::NoWarnings;

my $DB_NAME = 'PF_SCHEMA_TEST';
my $test_schema = "$install_dir/db/pf-schema-X.Y.Z.sql";
my $upgrade_schema = "$install_dir/db/upgrade-X.X.X-X.Y.Z.sql";

SKIP: {
    skip ('No db pass set',1) unless exists $ENV{PF_TEST_DB_PASS};
    skip ('There is no pf-schema',1) unless -e $test_schema;
    my $dbpass = $ENV{PF_TEST_DB_PASS};
    my $dbh = DBI->connect("DBI:mysql:", 'root', $dbpass) or BAIL_OUT("cannot connect to the local test database");
    $dbh->do("DROP DATABASE IF EXISTS $DB_NAME;") or BAIL_OUT("cannot drop the database $DB_NAME");
    $dbh->do("CREATE DATABASE $DB_NAME;") or BAIL_OUT("cannot create the database $DB_NAME");
    $dbh->do("USE $DB_NAME") or BAIL_OUT("cannot use the database $DB_NAME");
    my $out = qx{mysql -uroot -p$dbpass $DB_NAME < $test_schema};
    ok($? == 0 ,"Creating a the schema");
}



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

1;
