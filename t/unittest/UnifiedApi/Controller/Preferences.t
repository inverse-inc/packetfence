#!/usr/bin/perl

=head1 NAME

Iplogs

=cut

=head1 DESCRIPTION

unit test for Iplogs

=cut

use strict;
use warnings;
use DateTime;
use DateTime::Format::Strptime;
use lib '/usr/local/pf/lib';
use pf::dal::user_preference;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 28;
use Test::Mojo;
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

#pre-cleanup
pf::dal::user_preference->remove_items();

# run test without X-PacketFence-Username header
$t->get_ok('/api/v1/preferences' => json => { })
  ->status_is(404);

foreach my $user (qw(bob bobette)) {
    # Test empty preferences
    $t->get_ok('/api/v1/preferences' => { "X-PacketFence-Username" => $user } => json => { })
      ->json_is('/items',[])
      ->status_is(200);

    $t->put_ok('/api/v1/preference/pref1' => json => { value => "PF=awesome" })
      ->status_is(404);
      
    my $val1 = "PF=awesome for $user";
    $t->put_ok('/api/v1/preference/pref1'  => { "X-PacketFence-Username" => $user }=> json => { value => $val1 })
      ->status_is(200);
      
    $t->get_ok('/api/v1/preferences' => { "X-PacketFence-Username" => $user } => json => { })
      ->json_is('/items/0/value', $val1)
      ->status_is(200);

    $t->get_ok('/api/v1/preference/pref1' => { "X-PacketFence-Username" => $user } => json => { })
      ->json_is('/item/value',$val1)
      ->status_is(200);

    my $val2 = "PF=awesomest for $user";
    $t->put_ok('/api/v1/preference/pref1'  => { "X-PacketFence-Username" => $user }=> json => { value => $val2 })
      ->status_is(200);
      
    $t->get_ok('/api/v1/preference/pref1' => { "X-PacketFence-Username" => $user } => json => { })
      ->json_is('/item/value', $val2)
      ->status_is(200);
}

#post-cleanup
pf::dal::user_preference->remove_items();
  
  
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
