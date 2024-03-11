#!/usr/bin/perl

=head1 NAME

Mojo

=cut

=head1 DESCRIPTION

unit test for Mojo

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

use Test::More tests => 25;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
use pf::dal;

my $t = Test::Mojo->new('pf::UnifiedApi::custom');

$t->get_ok('/api/v1/user/admin')
  ->status_is(200)
  ->json_is('/item/pid' => 'admin') ;

$t->get_ok('/api/v1/user/NoSuchUser')
  ->status_is(404);

$t->get_ok('/api/v1/user/admin')
  ->status_is(200)
  ->json_is('/item/pid' => 'admin') ;

my $test_pid = "test_pid_$$";

$t->post_ok('/api/v1/users' => json => { pid => $test_pid })
  ->status_is(201);

$t->post_ok('/api/v1/users' => {} => '{')
  ->status_is(400);

my $notes = "notes for $test_pid";

$t->put_ok("/api/v1/user/$test_pid" => json => { notes => "$notes" })
  ->status_is(200);

$t->get_ok("/api/v1/user/$test_pid")
  ->status_is(200)
  ->json_is('/item/pid' => $test_pid)
  ->json_is('/item/notes' => $notes);

$t->patch_ok("/api/v1/user/$test_pid" => json => { notes => $notes })
  ->status_is(200);

$t->delete_ok("/api/v1/user/$test_pid")
  ->status_is(200);

$t->delete_ok("/api/v1/user/$test_pid")
  ->status_is(404);

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
