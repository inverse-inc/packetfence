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
    package validIp;
    use pf::validator::Moose;
    extends qw(pf::validator);
    has_field ip => (
        type     => 'IPAddress',
    );
}

use Test::More tests => 3;

#This test will running last
use Test::NoWarnings;


{
    my $v = validIp->new();
    my $ctx = pf::validator::Ctx->new;
    $v->validate($ctx, { ip => "1.2.3.4" });
    my $errors = $ctx->errors;
    is_deeply ($errors, [], "Valid IP address");

    $ctx = pf::validator::Ctx->new;
    $v->validate($ctx, { ip => 1 });
    $errors = $ctx->errors;
    is_deeply ($errors, [{ field => 'ip', message => 'must be an IP Address' }], "Has errors ip");
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

