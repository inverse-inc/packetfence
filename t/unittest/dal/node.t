#!/usr/bin/perl

=head1 NAME

node

=head1 DESCRIPTION

unit test for node

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 6;
use Utils;
use pf::dal::node;

#This test will running last
use Test::NoWarnings;

my $test_mac = Utils::test_mac();
{

    my ( $status, $node ) = pf::dal::node->find_or_create( { mac => $test_mac } );
    is( $status, 201, "created" );
    ok( exists $node->{bypass_role}, "bypass role exists" );
}

{
    my ( $status, $node ) = pf::dal::node->find_or_create( { mac => $test_mac } );
    is( $status, 200, "got" );
    ok( exists $node->{bypass_role}, "bypass role exists" );
    is( $node->bypass_role, undef, "bypass role undef" );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

