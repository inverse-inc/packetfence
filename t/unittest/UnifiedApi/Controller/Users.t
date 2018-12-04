#!/usr/bin/perl

=head1 NAME

Users

=head1 DESCRIPTION

unit test for Users

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

use Test::More;
use Utils;
use Test::Mojo;
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');
#This test will running last
use Test::NoWarnings;
my $batch = 5;
plan tests => $batch * (2 + 2 * $batch) + 13;
my @persons;

for ( 1 .. 5 ) {
    my $pid = Utils::test_pid();
    $t->post_ok( "/api/v1/users" => json => { pid => $pid } )->status_is(201);
    my @macs;
    for ( 1 .. 5 ) {
        my $mac = Utils::test_mac();
        push @macs, $mac;
        $t->post_ok( '/api/v1/nodes' => json => { mac => $mac, pid => $pid, category_id => 1, unregdate => "2018-12-31 23:59:59" } )
          ->status_is(201);
    }

    push @persons, { pid => $pid, macs => \@macs };
}

my @pids = map { $_->{pid} } @persons;

$t->post_ok( "/api/v1/users/bulk_register" => json => { items => \@pids } )
 ->status_is(200);

$t->post_ok( "/api/v1/users/bulk_deregister" => json => { items => \@pids } )
 ->status_is(200);

$t->post_ok( "/api/v1/users/bulk_apply_violation" => json => { items => \@pids, vid => 1100013 } )
 ->status_is(200);

$t->post_ok( "/api/v1/users/bulk_close_violations" => json => { items => \@pids } )
 ->status_is(200);

$t->post_ok( "/api/v1/users/bulk_reevaluate_access" => json => { items => \@pids } )
 ->status_is(200);

$t->post_ok( "/api/v1/users/bulk_fingerbank_refresh" => json => { items => \@pids } )
 ->status_is(200);

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
