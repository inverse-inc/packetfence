package pfappserver::Model::Search::Node;

=head1 NAME

pfappserver::Model::Search::Node add documentation

=cut

=head1 DESCRIPTION

Node

=cut

use strict;
use warnings;
use Moose;
use pfappserver::Base::Model::Search;
use pf::SearchBuilder;
use pf::node qw(node_custom_search);
use HTTP::Status qw(:constants);
use POSIX qw(ceil);

extends 'pfappserver::Base::Model::Search';

=head2 search

=cut

sub search {
    my ($self, $params, $pageNum, $perPage) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $builder = $self->make_builder;
    $params->{page_num} = $pageNum;
    $params->{per_page} = $perPage;
    $self->setup_query($builder, $params);
    my $results = $self->do_query($builder, $params);
    return (HTTP_OK, $results);
}

sub setup_query {
    my ($self, $builder, $params) = @_;
    $self->add_joins($builder, $params);
    $self->add_searches($builder, $params);
    $self->add_date_range($builder, $params, @{$params}{qw(start end)});
    $self->add_limit($builder, $params);
    $self->add_order_by($builder, $params);
}

sub do_query {
    my ($self, $builder, $params) = @_;
    my %results = %$params;
    my $sql = $builder->sql;
    my ($per_page, $page_num) = @{$params}{qw(per_page page_num)};
    $per_page ||= 25;
    $page_num ||= 1;
    my $itemsKey = $self->itemsKey;
    $results{$itemsKey} = [node_custom_search($sql)];
    my $sql_count = $builder->sql_count;
    my ($count) = node_custom_search($sql_count);
    $count = $count->{count};
    $results{count} = $count;
    $results{pages_count} = ceil( $count / $per_page );
    $results{per_page} = $per_page;
    $results{page_num} = $page_num;
    return \%results;
}

sub add_searches {
    my ($self,$builder,$params) = @_;
    my @searches = map {$self->process_query($_)} @{$params->{searches}};
    my $all_or_any = $params->{all_or_any} || 'all';
    if ($all_or_any eq 'any' ) {
        $all_or_any = 'or';
    } else {
        $all_or_any = 'and';
    }
    if (@searches) {
        $builder->where('(');
        $builder->where($all_or_any)->where(@$_) for @searches;
        $builder->where(')');
    }
}

sub make_builder {
    my ($self) = @_;
    return pf::SearchBuilder->new
        ->select(qw(
            mac pid voip bypass_vlan status category_id bypass_role_id
            user_agent computername last_arp last_dhcp notes),
            L_("IF(lastskip = '0000-00-00 00:00:00', '', lastskip)", 'lastskip'),
            L_("IF(detect_date = '0000-00-00 00:00:00', '', detect_date)", 'detect_date'),
            L_("IF(regdate = '0000-00-00 00:00:00', '', regdate)", 'regdate'),
            L_("IF(unregdate = '0000-00-00 00:00:00', '', unregdate)", 'unregdate'),
            L_("IFNULL(node_category.name, '')", 'category'),
            L_("IFNULL(node_category_bypass_role.name, '')", 'bypass_role'),
            L_("IFNULL(device_class, ' ')", 'dhcp_fingerprint'),
            { table => 'iplog', name => 'ip', as => 'last_ip' }
        )->from('node',
                {
                    'table' => 'node_category',
                    'join' => 'LEFT',
                    'on' =>
                    [
                        [
                            {
                                'table'  => 'node_category',
                                'name'   => 'category_id',
                            },
                            '=',
                            {
                                'table'  => 'node',
                                'name'   => 'category_id',
                            }
                        ],
                    ],
                },
                {
                    'table' => 'node_category',
                    'as'  => 'node_category_bypass_role',
                    'join' => 'LEFT',
                    'on' =>
                    [
                        [
                            {
                                'table'  => 'node_category_bypass_role',
                                'name'   => 'category_id',
                            },
                            '=',
                            {
                                'table'  => 'node',
                                'name'   => 'bypass_role_id',
                            }
                        ],
                    ],
                },
                {
                    'table' => 'iplog',
                    'join'  => 'LEFT',
                    'on'    =>
                    [
                        [
                            {
                                'table' => 'iplog',
                                'name'  => 'ip',
                            },
                            '=',
                            \"( SELECT `ip` FROM `iplog` WHERE `mac` = `node`.`mac`
                                AND ( `iplog`.`end_time` = '0000-00-00 00:00:00' OR `iplog`.`end_time` > NOW() )
                                        ORDER BY `start_time` DESC LIMIT 1 )"
                        ]
                    ],
                },
        );
}

my %COLUMN_MAP = (
    person_name => 'pid',
    category => {
        table => 'node_category',
        name  => 'name',
    },
    bypass_role => {
        table => 'node_category_bypass_role',
        name  => 'name',
    },
    dhcp_fingerprint   => {
       table => 'node',
       name  => 'device_class',
    },
    switch_ip   => {
       table => 'locationlog_distinct',
       name  => 'switch',
       joins => [
           {
               'table'  => \"( select DISTINCT mac, switch from locationlog )",
               'as'  => 'locationlog_distinct',
               'join' => 'LEFT',
               'on' =>
               [
                   [
                       {
                           'table' => 'locationlog_distinct',
                           'name'  => 'mac',
                       },
                       '=',
                       {
                           'table' => 'node',
                           'name'  => 'mac',
                       }
                   ],
               ],
           },
       ]
    },
    last_ip   => {
       table => 'iplog',
       name  => 'ip',
    }, # BUG : retrieves the last IP address, no mather if a period range is defined
    violation   => {
        table => 'class',
        name  => 'description',
        joins => [
            {
                'table'  => 'violation',
                'join' => 'LEFT',
                'on' =>
                [
                    [
                        {
                            'table' => 'violation',
                            'name'  => 'mac',
                        },
                        '=',
                        {
                            'table' => 'node',
                            'name'  => 'mac',
                        }
                    ],
                    [ 'AND' ],
                    [
                        {
                            'table' => 'violation',
                            'name'  => 'status',
                        },
                        '=',
                        'open',
                     ],
                ],
            },
            {
                'table'  => 'class',
                'join' => 'LEFT',
                'on' =>
                [
                    [
                        {
                            'table' => 'violation',
                            'name'  => 'vid',
                        },
                        '=',
                        {
                            'table' => 'class',
                            'name'  => 'vid',
                        }
                    ]
                ],
            }
        ]
    },
);

sub add_order_by {
    my ($self, $builder, $params) = @_;
    my ($by, $direction) = @$params{qw(by direction)};
    if ($by && $direction) {
        $by = $COLUMN_MAP{$by} if (exists $COLUMN_MAP{$by});
        $builder->order_by($by, $direction);
    }
}

sub add_date_range {
    my ($self, $builder, $params, $start, $end) = @_;
    if ($start) {
        $builder->where('detect_date', '>=', "$start 00:00");
    }
    if ($end) {
        $builder->where('detect_date', '<=', "$end 23:59");
    }
}

sub process_query {
    my ($self,$query) = @_;
    my $new_query = $self->SUPER::process_query($query);
    my $old_column = $new_query->[0];
    $new_query->[0] = exists $COLUMN_MAP{$old_column} ? $COLUMN_MAP{$old_column}  : $old_column;
    return $new_query;
}

sub add_joins {
    my ($self,$builder,$params) = @_;
    foreach my $name (map { $_->{name} } @{$params->{searches}}) {
        $builder->from(@{$COLUMN_MAP{$name}{'joins'}})
            if (exists $COLUMN_MAP{$name} && ref($COLUMN_MAP{$name}) eq 'HASH' && $COLUMN_MAP{$name}{'joins'});
    }
}

__PACKAGE__->meta->make_immutable;


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

