#!/usr/bin/perl

=head1 NAME

init_command

=head1 DESCRIPTION

unit test for the statements run on a new database connection

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 5;

#This test will running last
use Test::NoWarnings;
use pf::db;

sub session_settings {
    my $dbh = pf::db::db_connect();
    my ($name) = $dbh->selectrow_array("SHOW VARIABLES WHERE Variable_name in ('max_statement_time', 'max_execution_time')");
    my ($timeout) = $dbh->selectrow_array("SELECT \@\@SESSION.$name");
    my ($collation) = $dbh->selectrow_array("SELECT \@\@SESSION.collation_connection");
    return ($timeout + 0, $collation);
}

pf::db::db_set_max_statement_timeout(0);
my ($default_timeout, $collation) = session_settings();
is($collation, 'utf8mb4_general_ci', "The collation is set without a statement timeout");

pf::db::db_set_max_statement_timeout(600);
my ($timeout);
($timeout, $collation) = session_settings();
isnt($timeout, $default_timeout, "The statement timeout is set");
ok($timeout == 600 || $timeout == 600000, "The statement timeout is 600 seconds");
is($collation, 'utf8mb4_general_ci', "The collation is set with a statement timeout");

pf::db::db_set_max_statement_timeout(0);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
