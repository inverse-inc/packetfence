#!/usr/bin/perl

=head1 NAME

Interfaces

=head1 DESCRIPTION

unit test for Interfaces

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

my $interface = "dummy$$";

system("ip link del $interface type dummy");
system("ip link add $interface type dummy");

END {
    local $?;
    system("ip link del $interface type dummy");
}
#This test will running last
use Test::Mojo;
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');
$t->get_ok("/api/v1/config/interface/$interface")
  ->json_is('/item/is_running', 0)
  ->status_is(200);

{
    my $data = $t->tx->res->json;
    use Data::Dumper; print Dumper($data);
}

$t->post_ok("/api/v1/config/interface/$interface/up")
  ->status_is(200);

$t->get_ok("/api/v1/config/interface/$interface")
  ->json_is('/item/is_running', 1)
  ->status_is(200);

$t->post_ok("/api/v1/config/interface/$interface/down")
  ->status_is(200);

$t->get_ok("/api/v1/config/interface/$interface")
  ->json_is('/item/is_running', 0)
  ->status_is(200);


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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

