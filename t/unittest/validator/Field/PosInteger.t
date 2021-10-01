#!/usr/bin/perl

=head1 NAME

IPAddress

=head1 DESCRIPTION

unit test for IPAddress

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

{
    package validInt;
    use pf::validator::Moose;
    extends qw(pf::validator);
    has_field int => (
        type     => 'PosInteger',
    );
}

use Test::More tests => 6;

#This test will running last
use Test::NoWarnings;


{
    my $v = validInt->new();
    my $ctx = pf::validator::Ctx->new;
    $v->validate($ctx, { int => "1" });
    my $errors = $ctx->errors;
    is_deeply ($errors, [], "Valid Integer");

    $ctx->reset();
    $v->validate($ctx, { int => "-1" });
    $errors = $ctx->errors;
    is_deeply ($errors, [{ field => 'int' }], "Valid Integer");

    $ctx->reset();
    $v->validate($ctx, { int => "-10" });
    $errors = $ctx->errors;
    is_deeply ($errors, [{ field => 'int' }], "Valid Integer");

    $ctx->reset();
    $v->validate($ctx, { int => "+10" });
    $errors = $ctx->errors;
    is_deeply ($errors, [], "Valid Integer");

    $ctx->reset();
    $v->validate($ctx, { int => "asas" });
    $errors = $ctx->errors;
    is_deeply ($errors, [{ field => 'int', message => 'must be an Integer' }], "Has errors int");
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

