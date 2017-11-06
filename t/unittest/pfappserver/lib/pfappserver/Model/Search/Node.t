#!/usr/bin/perl

=head1 NAME

Node

=cut

=head1 DESCRIPTION

unit test for Node

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';
use lib '/usr/local/pf/html/pfappserver/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 24;

#This test will running last
use Test::NoWarnings;
use pfappserver::Model::Search::Node;

my $DEFAULT_LIKE_FORMAT = '%%%s%%';

my @VIOLATION_JOINS = (
    '=>{violation_status.mac=node.mac}',
    'violation|violation_status',
    '=>{violation_status.vid=violation_status_class.vid}',
    'class|violation_status_class',
);

my %COLUMN_MAP = (
    person_name => 'pid',
    unknown => {
        'table' => 'r1',
        'name'  => 'acctstarttime',
    },
    online_offline => {
        'table' => 'r1',
        'name'  => 'acctstoptime',
    },
    category => {
        table => 'node_category',
        name  => 'name',
    },
    bypass_role => {
        table => 'node_category_bypass_role',
        name  => 'name',
    },
    switch_id   => {
       table => 'locationlog',
       name  => 'switch',
    },
    switch_ip   => {
       table => 'locationlog',
       name  => 'switch_ip',
    },
    switch_mac   => {
       table => 'locationlog',
       name  => 'switch_mac',
    },
    switch_port   => {
       table => 'locationlog',
       name  => 'port',
    },
    switch_port_desc   => {
       table => 'locationlog',
       name  => 'ifDesc',
    },
    ssid   => {
       table => 'locationlog',
       name  => 'ssid',
    },
    connection_type   => {
       table => 'locationlog',
       name  => 'connection_type',
    },
    last_ip   => {
       table => 'ip4log',
       name  => 'ip',
    }, # BUG : retrieves the last IP address, no mather if a period range is defined
    violation   => {
        table => 'violation_status_class',
        name  => 'description',
        joins_id => 'violation_joins',
        joins => \@VIOLATION_JOINS
    },
    violation_status   => {
        table => 'violation_status',
        name  => 'status',
        joins_id => 'violation_joins',
        joins => \@VIOLATION_JOINS
    },
);

my $params = {
    'direction'  => 'asc',
    'all_or_any' => undef,
    'per_page'   => '25',
    'by'         => 'mac',
    'searches'   => [
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name'  => 'mac',
            'op'    => 'equal'
        }
    ]
};

is_deeply( pfappserver::Model::Search::Node::make_order_by($params), { -asc => 'mac' }, "MAC ASC");

is_deeply( pfappserver::Model::Search::Node::make_order_by({by => 'mac'}), { -asc => 'mac' }, "MAC ASC default order");

is_deeply( pfappserver::Model::Search::Node::make_order_by({direction => 'desc', by => 'mac'}), { -desc => 'mac' }, "MAC DESC");

is_deeply( pfappserver::Model::Search::Node::make_order_by({direction => 'DESC', by => 'mac'}), { -desc => 'mac' }, "MAC DESC upper");

is_deeply( pfappserver::Model::Search::Node::make_order_by({direction => 'ASC', by => 'mac'}), { -asc => 'mac' }, "MAC ASC upper");

is_deeply( pfappserver::Model::Search::Node::make_order_by({direction => 'BAD', by => 'mac'}), { -asc => 'mac' }, "MAC ASC bad");

is_deeply(
    pfappserver::Model::Search::Node::make_condition(
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name' => 'mac',
            'op' => 'equal'
        }
    ),
    { 'mac' => { '=' => 'ff:ff:ff:ff:ff:ff' } },
    "mac = 'ff:ff:ff:ff:ff:ff'"
);

is_deeply(
    pfappserver::Model::Search::Node::make_condition(
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name' => 'mac',
            'op' => 'not_equal'
        }
    ),
    { 'mac' => { '!=' => 'ff:ff:ff:ff:ff:ff' } },
    "mac != 'ff:ff:ff:ff:ff:ff'"
);

is_deeply(
    pfappserver::Model::Search::Node::make_condition(
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name' => 'mac',
            'op' => 'starts_with'
        }
    ),
    { 'mac' => { '-like' => 'ff:ff:ff:ff:ff:ff%' } },
    "mac LIKE 'ff:ff:ff:ff:ff:ff%'"
);

is_deeply(
    pfappserver::Model::Search::Node::make_condition(
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name' => 'mac',
            'op' => 'ends_with'
        }
    ),
    { 'mac' => { '-like' => '%ff:ff:ff:ff:ff:ff' } },
    "mac LIKE '%ff:ff:ff:ff:ff:ff'"
);

is_deeply(
    pfappserver::Model::Search::Node::make_condition(
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name' => 'mac',
            'op' => 'like'
        }
    ),
    { 'mac' => { '-like' => '%ff:ff:ff:ff:ff:ff%' } },
    "mac LIKE '%ff:ff:ff:ff:ff:ff%'"
);

is_deeply(
    pfappserver::Model::Search::Node::make_condition(
        {
            'value' => 'bob%bob',
            'name' => 'mac',
            'op' => 'like'
        }
    ),
    { 'mac' => { '-like' => \[q{? ESCAPE '\'}, '%bob\\%bob%'] } },
    "mac LIKE '%bob\\%bob%' ESCAPE '\\'"
);

$params = {
    'direction'  => 'asc',
    'all_or_any' => undef,
    'per_page'   => '25',
    'by'         => 'mac',
    'searches'   => [
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name'  => 'mac',
            'op'    => 'equal'
        }
    ]
};

is_deeply(
    [
        {
            'regdate' => [
                -all => { ">=" => '2017-12-12 00:00' },
                { "<=" => '2017-12-12 23:59' }
            ]
        }
    ],
    [ pfappserver::Model::Search::Node::make_date_range( 'regdate', '2017-12-12', '2017-12-12' ) ],
    "regdate between 2017-12-12 2017-12-12"
);

is_deeply(
    [
        {
            'regdate' => [
                -all =>
                { "<=" => '2017-12-12 23:59' }
            ]
        }
    ],
    [ pfappserver::Model::Search::Node::make_date_range( 'regdate', undef, '2017-12-12' ) ],
    "regdate less than 2017-12-12"
);

is_deeply(
    [
        {
            'regdate' => [
                -all =>
                { ">=" => '2017-12-12 00:00' }
            ]
        }
    ],
    [ pfappserver::Model::Search::Node::make_date_range( 'regdate', '2017-12-12', undef ) ],
    "regdate greater than 2017-12-12"
);

is_deeply(
    [ ],
    [ pfappserver::Model::Search::Node::make_date_range( 'regdate', undef, undef ) ],
    "regdate none"
);


is_deeply(
    {
        -offset => 0,
        -limit => 25,
    },
    pfappserver::Model::Search::Node::make_limit({
        page_num => 1,
        per_page => 25,
    }),
    "Make offset 0, limit 25"
);

is_deeply(
    {
        -offset => 25,
        -limit => 25,
    },
    pfappserver::Model::Search::Node::make_limit({
        page_num => 2,
        per_page => 25,
    }),
    "Make offset 25, limit 25"
);

is('-and', pfappserver::Model::Search::Node::make_logical_op(undef), "undef to -and");

is('-or', pfappserver::Model::Search::Node::make_logical_op('any'), "any to -or");

is('-or', pfappserver::Model::Search::Node::make_logical_op('Any'), "any to -or");

is('-and', pfappserver::Model::Search::Node::make_logical_op('all'), "all to -and");

is('-and', pfappserver::Model::Search::Node::make_logical_op('garabase'), "invalid defaults to -and");

=head2 make_limit

make_limit

=cut

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
