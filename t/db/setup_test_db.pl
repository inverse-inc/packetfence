#!/usr/bin/perl

=head1 NAME

setup_test_db -

=cut

=head1 DESCRIPTION

setup_test_db

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
BEGIN {
    use lib '/usr/local/pf/t';
    use setup_test_config;
}

use pf::db;
use DBI;

my $config = pf::db::db_config();

if ($config->{user} ne 'pf_smoke_tester') {
   die "Not using the standard testing user for db\n"; 
}

my $dbh = test_db_connection($config) or die "Cannot connection to db with test user please run\nmysql -uroot -p < t/smoke_test.sql\n";
my $db = $config->{db};

$dbh->do("DROP DATABASE IF EXISTS $db;") or die "Cannot drop database $db\n";;
$dbh->do("CREATE DATABASE $db;") or die "Cannot create database $db\n";
system("mysql -u$config->{user} -p$config->{pass} $db < db/pf-schema-X.Y.Z.sql");

sub test_db_connection {
    my ($config) = @_;
    my $dsn = "dbi:mysql:;host=$config->{host};port=$config->{port};mysql_client_found_rows=0";
    return  DBI->connect($dsn, $config->{user}, $config->{pass}, { RaiseError => 0, PrintError => 0, mysql_auto_reconnect => 1 }); 
}



=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

