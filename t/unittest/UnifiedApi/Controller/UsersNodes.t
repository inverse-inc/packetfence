#!/usr/bin/perl

=head1 NAME

UsersNodes

=cut

=head1 DESCRIPTION

unit test for UsersNodes

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

use Test::More tests => 4;
use Test::Mojo;
use pf::node;

#This test will running last
use Test::NoWarnings;

my $t = Test::Mojo->new('pf::UnifiedApi');
node_add("ff:ff:ff:ff:ff:fe");

$t->get_ok('/api/v1/users/default/nodes' => json => {  })
  ->status_is(200)
  ->json_is('/items/0/pid' => 'default') ;

my $items = $t->tx->res->json->{items};

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

