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

my $config = check_config(pf::db::db_config());
my $dbh = smoke_tester_db_connections($config);
create_db($dbh, $config);
apply_schema($config);
load_standard_data();

sub check_config {
    my ($config) = @_;
    if ($config->{user} ne 'pf_smoke_tester') {
       die "Not using the standard testing user for db\n";
    }

    if ($config->{db} !~ /^pf_smoke_test/) {
       die "Not using the standard database for testing \n";
    }
    return $config;
}


sub apply_schema {
    my ($config) = @_;
    system("mysql -h$config->{host} -P$config->{port} -u$config->{user} -p$config->{pass} $config->{db} < /usr/local/pf/db/pf-schema.sql");
    if ($?) {
        die "Unable to apply schema\n";
    }
}

sub smoke_tester_db_connections {
    my ($config) = @_;
    my $dsn = dsn_from_config($config);
    my $dbh =
      DBI->connect( $dsn, $config->{user}, $config->{pass},
        { RaiseError => 0, PrintError => 0, mysql_auto_reconnect => 1 } )
      or die <<EOS;
Cannot connection to db with test user please run
mysql -uroot -p < /usr/local/pf/t/db/smoke_test.sql;
EOS
    return $dbh;
}

sub dsn_from_config {
    my ($config) = @_;
    return "dbi:mysql:;host=$config->{host};port=$config->{port};mysql_client_found_rows=0";
}

sub create_db {
    my ($dbh, $config) = @_;
    my $db = $config->{db};
    $dbh->do("DROP DATABASE IF EXISTS $db;") or die "Cannot drop database $db\n";;
    $dbh->do("CREATE DATABASE $db;") or die "Cannot create database $db\n";
}

sub load_standard_data {
    start_pfconfig_test();
    require pf::config;
    pf::config::load_configdata_into_db();
}

sub start_pfconfig_test {
    `/usr/local/pf/t/pfconfig-test`;
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

