#!/usr/bin/perl

=head1 NAME

Password

=head1 DESCRIPTION

An admin can only change, remove, import or reset the password of users, or
change or delete users, whose access levels are within the access levels the
admin is allowed to give

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

use Test::More tests => 57;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $n = ($$ + int(rand(9999))) % 10000;
my $high_pid = "access_level_all_$n";
my $low_pid = "access_level_none_$n";
my $new_pid = "access_level_new_$n";
my $roles_header = 'X-PacketFence-Admin-Roles';
my $user_header = 'X-PacketFence-Username';
my %user_manager = ($roles_header => 'User Manager');

for my $user ([$high_pid, 'ALL'], [$low_pid, 'NONE']) {
    my ($pid, $access_level) = @$user;
    $t->post_ok("/api/v1/users" => json => { pid => $pid, email => "$pid\@example.com" })
      ->status_is(201);
    $t->post_ok("/api/v1/user/$pid/password" => json => { password => 'secret', access_level => $access_level })
      ->status_is(201);
}

$t->patch_ok("/api/v1/user/$high_pid/password" => \%user_manager => json => { password => 'changed' })
  ->status_is(403);

$t->put_ok("/api/v1/user/$high_pid/password" => \%user_manager => json => { password => 'changed', access_level => 'NONE' })
  ->status_is(403);

$t->delete_ok("/api/v1/user/$high_pid/password" => \%user_manager)
  ->status_is(403);

$t->post_ok("/api/v1/user/$high_pid/password_reset" => \%user_manager)
  ->status_is(403);

$t->post_ok("/api/v1/users/bulk_password_reset" => \%user_manager => json => { items => [$high_pid] })
  ->status_is(200)
  ->json_is('/items/0/status', 403);

$t->post_ok("/api/v1/users/bulk_import" => \%user_manager => json => { items => [ { pid => $high_pid, password => 'changed' } ] })
  ->status_is(200)
  ->json_is('/items/0/status', 422)
  ->json_is('/items/0/errors/0/field', 'pid');

$t->post_ok("/api/v1/users/bulk_import" => \%user_manager => json => {
    items => [ { pid => $new_pid, actions => [ { type => 'set_access_level', value => 'ALL' } ] } ]
  })
  ->status_is(200)
  ->json_is('/items/0/status', 422)
  ->json_is('/items/0/errors/0/field', 'access_level');

$t->post_ok("/api/v1/users/bulk_import" => \%user_manager => json => {
    items => [ { pid => $new_pid, actions => 'set_access_level' } ]
  })
  ->status_is(200)
  ->json_is('/items/0/status', 422)
  ->json_is('/items/0/errors/0/field', 'actions');

$t->post_ok("/api/v1/users/bulk_import" => \%user_manager => json => {
    items => [ { pid => $new_pid, actions => [ { type => 'set_access_level', value => 'User Manager' }, { type => 'set_access_level', value => 'ALL' } ] } ]
  })
  ->status_is(200)
  ->json_is('/items/0/status', 422)
  ->json_is('/items/0/errors/0/field', 'access_level');

$t->post_ok("/api/v1/users/bulk_import" => \%user_manager => json => {
    items => [ { pid => $new_pid, actions => [ { type => 'set_access_level', value => 'User Manager' } ] } ]
  })
  ->status_is(200)
  ->json_is('/items/0/status', 200);

$t->patch_ok("/api/v1/user/$high_pid" => \%user_manager => json => { email => 'changed@example.com' })
  ->status_is(403);

$t->delete_ok("/api/v1/user/$high_pid" => \%user_manager)
  ->status_is(403);

$t->post_ok("/api/v1/users/bulk_delete" => \%user_manager => json => { items => [$high_pid] })
  ->status_is(200)
  ->json_is('/items/0/status', 403);

$t->patch_ok("/api/v1/user/$low_pid" => \%user_manager => json => { email => 'changed@example.com' })
  ->status_is(200);

$t->patch_ok("/api/v1/user/$low_pid/password" => \%user_manager => json => { password => 'changed' })
  ->status_is(200);

$t->patch_ok("/api/v1/user/$high_pid/password" => { %user_manager, $user_header => $high_pid } => json => { password => 'changed' })
  ->status_is(200);

$t->patch_ok("/api/v1/user/$high_pid/password" => json => { password => 'changed again' })
  ->status_is(200);

$t->delete_ok("/api/v1/user/$_") for ($high_pid, $low_pid, $new_pid);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
