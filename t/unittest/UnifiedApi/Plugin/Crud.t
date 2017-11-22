#!/usr/bin/perl

=head1 NAME

Crud

=cut

=head1 DESCRIPTION

unit test for Crud

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
use pf::UnifiedApi::Plugin::RestCrud;
use Mojolicious;

use Test::More tests => 10;

#This test will running last
use Test::NoWarnings;

my $crud = pf::UnifiedApi::Plugin::RestCrud->new;

my $app = Mojolicious->new;

$app->plugin('pf::UnifiedApi::Plugin::RestCrud');#, {controller => "users", id_key => 'user_id'});

my $routes = $app->routes;

$routes->rest_routes({controller => 'users', id_key => "user_id" , resource_verbs => [qw(run walk)]});

ok($routes->find("Users"), "The top level Route Users created");
foreach my $name (qw(list create get remove update replace run walk)) {
    ok($routes->find("Users.$name"), "Route Users.$name create");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

