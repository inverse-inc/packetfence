#!/usr/bin/perl

=head1 NAME

Scans

=cut

=head1 DESCRIPTION

unit test for Scans

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 12;
use Test::Mojo;
use IPC::Open3;
use IO::Handle;
use pf::defer;
use Symbol 'gensym';

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/scans';

my $base_url = '/api/v1/config/scan';

my $child_err = gensym;
my $pid = open3(my $chld_out, my $chld_in, $child_err, "/usr/local/pf/t/mock_servers/rapid7.pl", "daemon", "-l", "https://localhost:8834");
my $defer = pf::defer::defer(
    sub {
        kill( 'INT', $pid );
        waitpid( $pid, 0 );
    }
);

$t->options_ok("$base_url/rapid7")
  ->status_is(200)
  ->json_is("/meta/site_id/allowed/0/value", 5)
  ->json_is("/meta/engine_id/allowed/0/value", 6)
  ->json_is("/meta/template_id/allowed/0/value", 'full-audit-without-web-spider' );

$t->get_ok($collection_base_url)
  ->status_is(200);

$t->post_ok($collection_base_url => json => {})
  ->status_is(422);

$t->post_ok($collection_base_url, {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

#use Data::Dumper;print Dumper($t->tx->res->json);

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

