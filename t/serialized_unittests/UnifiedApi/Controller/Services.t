#!/usr/bin/perl

=head1 NAME

Services

=cut

=head1 DESCRIPTION

unit test for Services

=cut

use strict;
use warnings;
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;

}

#run tests
use Test::More;
use Test::Mojo;
my $t = Test::Mojo->new('pf::UnifiedApi');

$t->get_ok("/api/v1/services" => json => { }) 
    ->json_has('/items')
    ->status_is(200);

my $services = $t->tx->res->json->{items};
foreach my $service (@$services) {
    
  $t->get_ok("/api/v1/service/$service/status" => json => { }) 
    ->json_has('/alive')
    ->json_has('/enabled')
    ->json_has('/managed')
    ->json_has('/pid')
    ->status_is(200);

  my $alive = $t->tx->res->json->{alive};
  my $enabled = $t->tx->res->json->{enabled};
  my $managed = $t->tx->res->json->{managed};
  my $pid = $t->tx->res->json->{pid};
  
  if( $managed ) {
    if( $alive and $pid > 0 ) {
        #stop then start, restart
        $t->post_ok("/api/v1/service/$service/stop" => json => { })
        ->json_is('/stop', 1)
        ->status_is(200);
        $t->post_ok("/api/v1/service/$service/start" => json => { })
        ->json_is('/start', 1)
        ->json_unlike('/pid', qr/$pid/)
        ->json_has('/pid')
        ->status_is(200);
        $t->post_ok("/api/v1/service/$service/restart" => json => { })
        ->json_is('/restart', 1)
        ->json_has('/pid')
        ->json_unlike('/pid', qr/$pid/)
        ->status_is(200);
    }
    if( $enabled ) {
      #disable then enable
      $t->post_ok("/api/v1/service/$service/disable" => json => { })
        ->json_is('/disable', 1)
        ->status_is(200);
      $t->post_ok("/api/v1/service/$service/enable" => json => { })
        ->json_is('/enable', 1)
        ->status_is(200);
    } else {
      #enable then disable
      $t->post_ok("/api/v1/service/$service/enable" => json => { })
        ->json_is('/enable', 1, "Check $service is enable")
        ->status_is(200);
      $t->post_ok("/api/v1/service/$service/disable" => json => { })
        ->json_is('/disable', 1, "Check $service is disabled")
        ->status_is(200);
    }
    $t->get_ok("/api/v1/service/$service/status" => json => { })    
      ->json_is('/alive', $alive)
      ->json_is('/enabled', $enabled)
      ->json_is('/managed', $managed)
      ->json_has('/pid')
      ->status_is(200);
  }
}

done_testing();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
