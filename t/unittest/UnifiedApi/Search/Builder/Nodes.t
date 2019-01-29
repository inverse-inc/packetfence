#!/usr/bin/perl

=head1 NAME

Nodes

=cut

=head1 DESCRIPTION

unit test for Nodes

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

use Test::More tests => 27;

#This test will running last
use Test::NoWarnings;
use pf::UnifiedApi::Search::Builder::Nodes;
use pf::error qw(is_error);
use pf::constants qw($ZERO_DATE);
use pf::dal::node;
my $dal = "pf::dal::node";

my $sb = pf::UnifiedApi::Search::Builder::Nodes->new();

{
    my ($status, $col) = $sb->make_columns({ dal => $dal,  fields => [qw(mac $garbage ip4log.ip)] });
    ok(is_error($status), "Do no accept invalid columns");
}

{
    my @f = qw(mac ip4log.ip locationlog.ssid locationlog.port);

    my %search_info = (
        dal => $dal,
        fields => \@f,
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [ 200, [ 'node.mac', \'`ip4log`.`ip` AS `ip4log.ip`', \'`locationlog`.`ssid` AS `locationlog.ssid`', \'`locationlog`.`port` AS `locationlog.port`'] ],
        'Return the columns'
    );

    is_deeply(
        [
            $sb->make_from(\%search_info)
        ],
        [
            200,
            [
                -join => 'node',
                @pf::UnifiedApi::Search::Builder::Nodes::IP4LOG_JOIN,
                @pf::UnifiedApi::Search::Builder::Nodes::LOCATION_LOG_JOIN,
            ]
        ],
        'Return the joined tables'
    );
}

{
    my @f = qw(mac locationlog.ssid locationlog.port radacct.acctsessionid online);

    my %search_info = (
        dal => $dal,
        fields => \@f,
        query => {
            op => 'equals',
            field => 'ip4log.ip',
            value => "1.1.1.1"
        },
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
                \'`locationlog`.`ssid` AS `locationlog.ssid`',
                \'`locationlog`.`port` AS `locationlog.port`',
                \'`radacct`.`acctsessionid` AS `radacct.acctsessionid`',
                "IF(radacct.acctstarttime IS NULL,'unknown',IF(radacct.acctstoptime IS NULL, 'on', 'off'))|online"
            ],
        ],
        'Return the columns'
    );
    is_deeply(
        [
            $sb->make_where(\%search_info)
        ],
        [
            200,
            {
                'ip4log.ip' => { "=" => "1.1.1.1"},
                'locationlog2.id' => undef,
                'r2.radacctid' => undef,
            },
        ],
        'Return the joined tables'
    );

    $sb->make_where(\%search_info);

    my @a = $sb->make_from(\%search_info);
    is_deeply(
        \@a,
        [
            200,
            [
                -join => 'node',
                @pf::UnifiedApi::Search::Builder::Nodes::LOCATION_LOG_JOIN,
                @pf::UnifiedApi::Search::Builder::Nodes::RADACCT_JOIN,
                @pf::UnifiedApi::Search::Builder::Nodes::IP4LOG_JOIN,
            ]
        ],
        'Return the joined tables'
    );
}

{
    my @f = qw(mac online radacct.acctsessionid);

    my %search_info = (
        dal    => $dal,
        fields => \@f,
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
                "IF(radacct.acctstarttime IS NULL,'unknown',IF(radacct.acctstoptime IS NULL, 'on', 'off'))|online",
                \'`radacct`.`acctsessionid` AS `radacct.acctsessionid`'
            ]
        ],
        'Return the columns with column spec'
    );

}

{
    my @f = qw(mac online);
    my %search_info = (
        dal    => $dal,
        fields => \@f,
        sort => ['online'],
    );
    my ($status, $results) = $sb->search(\%search_info);
    is($status, 200, "Including online");
}

{
    my $q = {
        op    => 'equals',
        field => 'online',
        value => "unknown",
    };

    my $s = {
        dal    => $dal,
        fields => [qw(mac online)],
        query  => $q,
    };

    ok(
        $sb->is_field_rewritable($s, 'online'),
        "Is online rewriteable"
    );

    is_deeply(
        [ $sb->rewrite_query( $s, $q ) ],
        [
            200,
            {
                op    => 'equals',
                value => undef,
                field => 'radacct.acctstarttime'
            }
        ],
        "Rewrite online='unknown'",
    );

    is_deeply(
        [
            $sb->rewrite_query(
                $s, { op => 'equals', value => 'on', field => 'online' }
            )
        ],
        [
            200,
            {
                'op'     => 'and',
                'values' => [
                    {
                        op    => 'not_equals',
                        value => undef,
                        field => 'radacct.acctstarttime'
                    },
                    {
                        op    => 'equals',
                        value => undef,
                        field => 'radacct.acctstoptime'
                    },
                ],
            },
        ],
        "Rewrite online='on'",
    );

    is_deeply(
        [
            $sb->rewrite_query(
                $s, { op => 'equals', value => 'off', field => 'online' }
            )
        ],
        [
            200,
            {
                op    => 'not_equals',
                value => undef,
                field => 'radacct.acctstoptime'
            },
        ],
        "Rewrite online='off'",
    );

    is_deeply(
        [
            $sb->rewrite_query(
                $s, { op => 'not_equals', value => 'off', field => 'online' }
            ),
        ],
        [
            200,
            {
                op => 'or',
                values => [
                    { op => 'equals', value => undef, field => 'radacct.acctstarttime' },
                    { op => 'equals', value => undef, field => 'radacct.acctstoptime' },
                ],
            },
        ],
        "Rewrite online!='off'",
    );

    is_deeply(
        [
            $sb->rewrite_query(
                $s, { op => 'not_equals', value => 'on', field => 'online' }
            ),
        ],
        [
            200,
            {
                op     => 'or',
                values => [
                    {
                        op    => 'equals',
                        value => undef,
                        field => 'radacct.acctstarttime'
                    },
                    {
                        op    => 'not_equals',
                        value => undef,
                        field => 'radacct.acctstoptime'
                    },
                ],
            },
        ],
        "Rewrite online!='on'",
    );

    is_deeply(
        [
            $sb->rewrite_query(
                $s,
                { op => 'not_equals', value => 'unknown', field => 'online' }
            )
        ],
        [
            200,
            {
                op    => 'not_equals',
                value => undef,
                field => 'radacct.acctstarttime',
            },
        ],
        "Rewrite online!='unknown'",
    );

    is_deeply(
        [
            $sb->rewrite_query(
                $s,
                { op => 'contains', value => 'unknown', field => 'online' }
            )
        ],
        [
            422,
            { msg => "contains is not valid for the online field" },
        ],
        "Invalid op for online",
    );
}

{
    my @f = qw(mac online);
    my %search_info = (
        dal    => $dal,
        fields => \@f,
        query => {
            op => 'equals',
            field => 'online',
            value => "unknown",
        },
    );
    my ($status, $results) = $sb->search(\%search_info);
    is($status, 200, "Query remap for online");
}

{
    my @f = qw(status online mac pid ip4log.ip bypass_role_id);

    my %search_info = (
        dal => $dal,
        fields => \@f,
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.status',
                "IF(radacct.acctstarttime IS NULL,'unknown',IF(radacct.acctstoptime IS NULL, 'on', 'off'))|online",
                'node.mac',
                'node.pid',
                \'`ip4log`.`ip` AS `ip4log.ip`',
                'node.bypass_role_id',
            ],
        ],
        'Return the columns'
    );
    is_deeply(
        [
            $sb->make_where(\%search_info)
        ],
        [
            200,
            {
                'r2.radacctid' => undef,
            },
        ],
        'Return the joined tables'
    );

    my @a = $sb->make_from(\%search_info);
    is_deeply(
        \@a,
        [
            200,
            [
                -join => 'node',
                @pf::UnifiedApi::Search::Builder::Nodes::RADACCT_JOIN,
                @pf::UnifiedApi::Search::Builder::Nodes::IP4LOG_JOIN,
            ]
        ],
        'Return the joined tables'
    );
}

{
    my @f = qw(mac security_event.open_count security_event.close_count);

    my %search_info = (
        dal => $dal,
        fields => \@f,
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
                \"COUNT(security_event_open.id) AS `security_event.open_count`",
                \"COUNT(security_event_close.id) AS `security_event.close_count`",
            ],
        ],
        'Return the columns'
    );

    is_deeply(
        [ $sb->make_where(\%search_info) ],
        [
            200,
            {
            },
        ],
        'Return the joined tables'
    );

    is_deeply(
        [ $sb->make_from(\%search_info) ],
        [
            200,
            [
                -join => 'node',
                @pf::UnifiedApi::Search::Builder::Nodes::SECURITY_EVENT_OPEN_JOIN,
                @pf::UnifiedApi::Search::Builder::Nodes::SECURITY_EVENT_CLOSED_JOIN,
            ]
        ],
        'Return the joined tables'
    );

    is_deeply(
        [
            $sb->make_group_by(\%search_info)
        ],
        [
            200,
            [qw(node.tenant_id node.mac)],
        ],
        "security_event.open_count Group by",
    )
}

{
    my @f = qw(mac mac);

    my %search_info = (
        dal => $dal,
        fields => \@f,
    );
    my ($status, $error) = $sb->make_columns( \%search_info );
    is($status, 422, "Duplicated fields error");
}

{
    my @f = qw(mac );

    my %search_info = (
        dal => $dal,
        fields => \@f,
        with_total_count => 1,
    );
    is_deeply(
        [
            $sb->make_columns(\%search_info)
        ],
        [
            200,
            [qw(-SQL_CALC_FOUND_ROWS node.mac)],
        ],
        "with count",
    )
}

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
