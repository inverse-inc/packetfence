#!/usr/bin/perl

=head1 NAME

Locationlog

=cut

=head1 DESCRIPTION

unit test for Locationlog

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';
use pf::dal::locationlog;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

#truncate the locationlog table
pf::dal::locationlog->remove_items();

#insert known data
my %values = (
    mac                 => '00:01:02:03:04:05',
    switch              => '0.0.0.1',
    switch_ip           => '0.0.0.2',
    switch_mac          => '06:07:08:09:0a:0b',
    port                => '1234',
    vlan                => '99',
    role                => 'test role',
    connection_sub_type => 'test connection_sub_type',
    connection_type     => 'test connection_type',
    dot1x_username      => 'test dot1x_username',
    ssid                => 'test ssid',
    stripped_user_name  => 'test stripped_user_name',
    realm               => 'test realm',
    session_id          => 'test session_id',
    ifDesc              => 'test ifDesc',
    start_time          => '0000-00-00 00:00:01',
    end_time            => '0000-00-00 00:00:02',
    voip                => 'no',
);
my $status = pf::dal::locationlog->create(\%values);

#run tests
use Test::More tests => 76;
use Test::Mojo;
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');
$t->get_ok('/api/v1/locationlogs' => json => { })
  ->json_is('/items/0/mac','00:01:02:03:04:05')
  ->json_is('/items/0/switch','0.0.0.1')
  ->json_is('/items/0/switch_ip','0.0.0.2')
  ->json_is('/items/0/switch_mac','06:07:08:09:0a:0b')
  ->json_is('/items/0/port','1234')
  ->json_is('/items/0/vlan','99')
  ->json_is('/items/0/role','test role')
  ->json_is('/items/0/connection_sub_type','test connection_sub_type')
  ->json_is('/items/0/connection_type','test connection_type')
  ->json_is('/items/0/dot1x_username','test dot1x_username')
  ->json_is('/items/0/ssid','test ssid')
  ->json_is('/items/0/stripped_user_name','test stripped_user_name')
  ->json_is('/items/0/realm','test realm')
  ->json_is('/items/0/session_id','test session_id')
  ->json_is('/items/0/ifDesc','test ifDesc')
  ->json_is('/items/0/start_time','0000-00-00 00:00:01')
  ->json_is('/items/0/end_time','0000-00-00 00:00:02')  
#  ->json_has('/')
  ->status_is(200);

$t->post_ok('/api/v1/locationlogs/search', {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

$t->post_ok(
    '/api/v1/locationlogs/search' => json => {
        query => {
            op    => 'equals',
            field => 'bob',
            value => 'bob'
        }
    }
  )
  ->status_is(422, "Invalid field in query")
;

$t->post_ok(
    '/api/v1/locationlogs/search' => json => {
        fields => [qw(bob)],
        query => {
            op    => 'equals',
            field => 'mac',
            value => 'bob'
        }
    }
  )
  ->status_is(422, "Invalid field in fields array")
;

$t->post_ok(
    '/api/v1/locationlogs/search' => json => {
        query => {
            op    => 'equals',
            field => 'mac',
            value => 'bob'
        }
    }
  )
  ->status_is(200)
;

my $items = $t->tx->res->json->{items};
is_deeply($items, [], "Empty response");

simple_single_query(
    {
    },
    \%values,
    "Got back 00:01:02:03:04:05"
);

simple_single_query(
    {
        query => {
            op    => 'equals',
            field => 'mac',
            value => '00:01:02:03:04:05'
        },
    },
    \%values,
    "Got back 00:01:02:03:04:05"
);

simple_single_query(
    {
        query => {
            op    => 'not_equals',
            field => 'mac',
            value => '00:01:02:03:04:06'
        },
    },
    \%values,
    "Got back 00:01:02:03:04:05"
);

simple_single_query(
    {
        query => {
            op    => 'starts_with',
            field => 'mac',
            value => '00:01',
        },
    },
    \%values,
    "Got back 00:01:02:03:04:05"
);

simple_single_query(
    {
        query => {
            op    => 'ends_with',
            field => 'mac',
            value => '04:05',
        },
    },
    \%values,
    "Got back 00:01:02:03:04:05"
);

simple_single_query(
    {
        fields => [qw(mac)],
        query => {
            op    => 'equals',
            field => 'mac',
            value => '00:01:02:03:04:05'
        },
    },
    { mac => "00:01:02:03:04:05" },
    "Got back 00:01:02:03:04:05"
);

sub simple_single_query {
    my ($query, $value, $msg) = @_;
    $t->post_ok(
        '/api/v1/locationlogs/search' => json => $query
      )
      ->status_is(200)
    ;

    my $items = $t->tx->res->json->{items};
    my $item = $items->[0];
    delete $item->{id};
    is_deeply($item, $value, $msg)
}

#truncate the locationlog table
pf::dal::locationlog->remove_items();

for my $o (0 .. 255) {
    my $status = pf::dal::locationlog->create(
        {
            %values,
            mac        => sprintf("01:02:03:04:05:%02x", $o),
            switch_mac => sprintf('06:07:08:09:0a:%02x', $o),
            port       => $o + int(rand(85)),
            vlan       => $o,
        }
    );
}

simple_single_query(
    {
        'fields' => [qw(mac)],
        'limit' => 1,
        'sort' => ['mac DESC'],
    },
    {mac => '01:02:03:04:05:ff'},
    "Got back 00:01:02:03:04:ff"
);

$t->post_ok(
    '/api/v1/locationlogs/search' => json => {
        'fields' => [qw(mac)],
        'limit' => 1,
        'cursor' => 1,
        'sort' => ['mac'],
    }
  )
  ->status_is(200)
;

is_deeply($t->tx->res->json->{items}[0], { mac => '01:02:03:04:05:01'});

$t->post_ok(
    '/api/v1/locationlogs/search' => json => { }
  )
  ->status_is(200)
;
$items = $t->tx->res->json->{items};

is(@$items, 25, "Returns the defaults items count");

$t->post_ok(
    '/api/v1/locationlogs/search' => json => { limit => 100 }
  )
  ->status_is(200)
  ->json_is('/nextCursor', 100)
  ->json_is('/prevCursor', 0)
;
$items = $t->tx->res->json->{items};

is(@$items, 100, "Returns 100 items");

$t->post_ok(
    '/api/v1/locationlogs/search' => json => { limit => 256 }
  )
  ->status_is(200)
  ->json_hasnt('/nextCursor')
  ->json_is('/prevCursor', 0)
;
$items = $t->tx->res->json->{items};

is(@$items, 256, "Returns 256 items");

$t->post_ok(
    '/api/v1/locationlogs/search' => json => { limit => 267 }
  )
  ->status_is(200)
  ->json_hasnt('/nextCursor')
  ->json_is('/prevCursor', 0)
;
$items = $t->tx->res->json->{items};

is(@$items, 256, "Returns 256 items");

$t->post_ok(
    '/api/v1/locationlogs/search' => json => {
        'fields' => [qw(mac)],
        'sort' => ['mac'],
        'limit' => 256,
        'query' => {
            op => 'and',
            'values' => [
                {
                    op => 'not_equals',
                    field => 'mac' ,
                    value => '01:02:03:04:05:01',
                },
                {
                    op => 'not_equals',
                    field => 'mac' ,
                    value => '01:02:03:04:05:02',
                },
            ],
        },
    }
  )
  ->status_is(200)
;

is(scalar @{$t->tx->res->json->{items}}, 254, "Return a complex query");

$t->post_ok(
    '/api/v1/locationlogs/search' => json => {
        'fields' => [qw(mac)],
        'sort'   => ["${$}_bad_field"],
    }
  )
  ->status_is(422)
;

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
