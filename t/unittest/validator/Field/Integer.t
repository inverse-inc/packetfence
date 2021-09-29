#!/usr/bin/perl

=head1 NAME

IPAddress

=head1 DESCRIPTION

unit test for IPAddress

=cut

use strict;
use warnings;

our @RangeTests;
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    @RangeTests = (
        {
            new => [range_start => 3, range_end => 6, name => 'int'],
            in => 1,
            out => [{ field => 'int', message => 'out of range' }],
            msg => 'out of range 1 not between 3, 6',
        },
        {
            new => [range_start => 3, range_end => 6, name => 'int'],
            in => 3,
            out => [],
            msg => 'in range 3 is between 3, 6',
        },
        {
            new => [range_start => 3, range_end => 6, name => 'int'],
            in => 4,
            out => [],
            msg => 'in range 4 is between 3, 6',
        },
        {
            new => [range_start => 3, range_end => 6, name => 'int'],
            in => 6,
            out => [],
            msg => 'in range 6 is between 3, 6',
        },
        {
            new => [range_start => 3, name => 'int'],
            in => 1,
            out => [{ field => 'int', message => 'value too low' }],
            msg => '1 is not lower than 3',
        },
        {
            new => [range_end => 6, name => 'int'],
            in => 7,
            out => [{ field => 'int', message => 'value too high' }],
            msg => '7 is not higher than 6',
        },
    );
}

{
    package validInt;
    use pf::validator::Moose;
    extends qw(pf::validator);
    has_field int => (
        type     => 'Integer',
    );
}

use Test::More tests => 6 + scalar @RangeTests;

#This test will running last
use Test::NoWarnings;


{
    my $v = validInt->new();
    my $ctx = pf::validator::Ctx->new;
    $v->validate($ctx, { int => "1" });
    my $errors = $ctx->errors;
    is_deeply ($ctx->errors, [], "Valid Integer");

    $ctx->reset();
    $v->validate($ctx, { int => "-1" });
    is_deeply ($ctx->errors, [], "Valid Integer");

    $ctx->reset();
    $v->validate($ctx, { int => "-10" });
    is_deeply ($ctx->errors, [], "Valid Integer");

    $ctx->reset();
    $v->validate($ctx, { int => "+10" });
    is_deeply ($ctx->errors, [], "Valid Integer");

    $ctx->reset();
    $v->validate($ctx, { int => "asas" });
    is_deeply ($ctx->errors, [{ field => 'int', message => 'must be an Integer' }], "Has errors int");
}

#Range test
{
    my $ctx = pf::validator::Ctx->new;
    for my $t ( @RangeTests ) {
        $ctx->reset;
        my $f = pf::validator::Field::Integer->new(@{$t->{new}});
        $f->test_ranges($ctx, $t->{in});
        is_deeply ($ctx->errors, $t->{out}, $t->{msg});
    }
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

