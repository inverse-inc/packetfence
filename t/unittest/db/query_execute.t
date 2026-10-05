#!/usr/bin/perl

=head1 NAME

query_execute

=head1 DESCRIPTION

db_query_execute runs the prepared statements of a module (#9298)

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 6;
use pf::db;

#This test will running last
use Test::NoWarnings;

# A module with prepared statements, as the ones using db_data/db_query_execute
my %statements;
{
    no warnings 'once';
    *pf::test9298::test9298_db_prepare = sub {
        $statements{answer} = pf::db::get_db_handle()->prepare("SELECT 42");
        $statements{sql} = "SELECT 43";
        $pf::test9298::test9298_db_prepared = 1;
        return 1;
    };
}
pf::test9298::test9298_db_prepare();

like(ref($statements{answer}), qr/::st$/, "the handles are of the DBI RootClass");
ok(pf::db::_is_statement_handle($statements{answer}), "a prepared statement is a statement handle");
ok(!pf::db::_is_statement_handle($statements{sql}), "SQL is not a statement handle");

my $sth = db_query_execute('test9298', \%statements, 'answer');
is($sth ? ($sth->fetchrow_array)[0] : undef, 42, "a prepared statement is executed");
$sth->finish if $sth;

$sth = db_query_execute('test9298', \%statements, 'sql');
is($sth ? ($sth->fetchrow_array)[0] : undef, 43, "an SQL statement is prepared and executed");
$sth->finish if $sth;

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
