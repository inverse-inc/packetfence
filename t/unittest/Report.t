#!/usr/bin/perl

=head1 NAME

Report

=head1 DESCRIPTION

unit test for Report

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 14;
use pf::SQL::Abstract;
use pf::factory::report;

#This test will running last
use Test::NoWarnings;

{
    my $report = pf::factory::report->new('Node::Active::All');
    #This is the first test
    ok ($report, "report created");
    isa_ok($report, "pf::Report::sql");

    is_deeply(
        $report->create_bind(),
        [1, '00:00:00:00:00:00', 100]
    );
    my $results = [{}, {}, {mac => "22:33:22:33:33:33"}];
    is($report->nextCursor($results, limit => 2), "22:33:22:33:33:33", "pf::Report::sql->nextCursor");
    is_deeply($results, [{}, {}]);

    $results = [{}, {}, {mac => "22:33:22:33:33:33"}];
    is($report->nextCursor($results, limit => 3), undef, "pf::Report::sql->nextCursor");
    is_deeply($results, [{}, {}, {mac => "22:33:22:33:33:33"}]);
}

{
    my $report = pf::factory::report->new('User::Registration::Sponsor');
    #This is the first test
    ok ($report, "report created");
    isa_ok($report, "pf::Report::abstract");
    my $results = [{}, {}, {mac => "22:33:22:33:33:33"}];
    is($report->nextCursor($results, limit => 2, cursor => 2), 4, "pf::Report::abstract->nextCursor");
    is_deeply($results, [{}, {}]);

    $results = [{}, {}, {mac => "22:33:22:33:33:33"}];
    is($report->nextCursor($results, limit => 3, cursor => 3), undef, "pf::Report::sql->nextCursor");
    is_deeply($results, [{}, {}, {mac => "22:33:22:33:33:33"}]);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

