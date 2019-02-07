#!/usr/bin/perl

=head1 NAME

fork

=head1 DESCRIPTION

unit test for fork

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

use Test::More tests => 1 + 20*7;

#This test will running last
#use Test::SharedFork;
use Test::NoWarnings;
use pf::db;

for my $iteration ( 1 .. 20 ) {
    db_set_max_statement_timeout(1);
    my $dbh = db_connect();
    my $one;
    ($one) = $dbh->selectrow_array('SELECT 1');
    my $sth = $dbh->prepare('SELECT 1');
    $sth->execute;
    ok( !$dbh->{InactiveDestroy}, 'dbh InactiveDestroy is off before fork' );
    my ($name, $current_timeout) = $dbh->selectrow_array("SHOW VARIABLES WHERE Variable_name in ('max_statement_time', 'max_execution_time')");
    ok($current_timeout, "Current timeout is set");
    my $pid = fork();
    if ( !defined $pid ) {
        die "Can't fork: $!\n";
    }

    if ($pid) {
        isa_ok( $dbh, 'DBI::db' );
        ($one) = $dbh->selectrow_array( 'SELECT 1' );
        is( $one, 1, 'parent can select 1 before child exits' );
        my $return_pid = wait();
        is($return_pid, $pid, 'waited for child');
        is($?, 0, "exited succesfully");

        ($one) = $dbh->selectrow_array( 'SELECT 1' );
        is( $one, 1, 'parent can select 1 after child exits' );
    } else {
        my $builder = Test::More->builder;
        $builder->reset();
        $builder->_indent($builder->_indent . '  ');
        local $Test::More::Level = $Test::More::Level + 1;
        my $child_dbh = db_connect();
        isa_ok( $child_dbh, 'DBI::db' );
        ($one) = $child_dbh->selectrow_array('SELECT 1');
        is( $one, 1, 'child can select 1' );
        my ( $name, $current_timeout ) = $child_dbh->selectrow_array(
"SHOW VARIABLES WHERE Variable_name in ('max_statement_time', 'max_execution_time')"
        );
        ok( $current_timeout, "Current timeout is set $current_timeout" );
        done_testing();
        exit;
    }
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

