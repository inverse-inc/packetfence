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
use pf::log;
use pf::util qw(calc_page_count clean_mac);
use pf::SearchBuilder;
use pf::SearchBuilder::Node;
use pf::node qw(node_custom_search);
use HTTP::Status qw(:constants);
use pf::util qw(calc_page_count);

extends 'pfappserver::Base::Model::Search';

=head2 search

=cut

sub search {
    my ($self, $params) = @_;
    my $logger = get_logger();
    my $builder = $self->make_builder;
    $self->setup_query($builder, $params);
    my $results = $self->do_query($builder, $params);
    return (HTTP_OK, $results);
}

sub setup_query {
    my ($self, $builder, $params) = @_;
    $self->add_joins($builder, $params);
    $self->add_searches($builder, $params);
    $self->add_date_range($builder, $params, 'detect_date', @{$params}{qw(start end)});
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
    return pf::SearchBuilder::Node->new
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
            L_("IF(radacct.acctstarttime IS NULL,'unknown',IF(radacct.acctstoptime IS NULL, 'on', 'off'))", 'online'),
            { table => 'iplog', name => 'ip', as => 'last_ip' },
            { table => 'locationlog', name => 'switch', as => 'switch_id' },
            { table => 'locationlog', name => 'switch_ip', as => 'switch_ip_address' },
            { table => 'locationlog', name => 'switch_mac', as => 'switch_mac' },
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
                                        ORDER BY `start_time` DESC LIMIT 1 )"
                        ]
                    ],
                },
                {
                    'table' => 'locationlog',
                    'join'  => 'LEFT',
                    'on'    =>
                    [
                        [
                            {
                                'table' => 'node',
                                'name'  => 'mac',
                            },
                            '=',
                            {
                                'table' => 'locationlog',
                                'name'  => 'mac',
                            },
                        ],
                        [ 'AND' ],
                        [
                           {
                               'table'  => 'locationlog',
                               'name'   => 'end_time',
                           },
                           '=',
                           '0000-00-00 00:00:00'
                        ],
                    ],
                },
                {
                    'table' => 'radacct',
                    'join'  => 'LEFT',
                    'on'    =>
                    [
                        [
                            {
                                'table' => 'radacct',
                                'name'  => 'radacctid',
                            },
                            '=',
                            \"(select radacctid from radacct where callingstationid = node.mac ORDER BY acctstarttime DESC LIMIT 1)"
                        ],
                    ],
                },
        );
}

my %COLUMN_MAP = (
    person_name => 'pid',
    unknown => {
        'table' => 'radacct',
        'name'  => 'acctstarttime',
    },
    online_offline => {
        'table' => 'radacct',
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
    dhcp_fingerprint   => {
       table => 'node',
       name  => 'device_class',
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
    violation_status   => {
        table => 'violation_status',
        name  => 'status',
        joins => [
            {
                'table'  => 'violation',
                'join' => 'LEFT',
                'as' => 'violation_status',
                'on' =>
                [
                    [
                        {
                            'table' => 'violation_status',
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
            {
                'table'  => 'class',
                'join' => 'LEFT',
                'as' => 'violation_status_class',
                'on' =>
                [
                    [
                        {
                            'table' => 'violation_status',
                            'name'  => 'vid',
                        },
                        '=',
                        {
                            'table' => 'violation_status_class',
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
    my ($self, $builder, $column, $params, $start, $end) = @_;
    if ($start) {
        $builder->where($column, '>=', "$start 00:00");
    }
    if ($end) {
        $builder->where($column, '<=', "$end 23:59");
    }
}

sub process_query {
    my ($self, $query) = @_;
    my $new_query = $self->SUPER::process_query($query);
    return unless defined $new_query;
    my $old_column = $new_query->[0];
    $new_query->[0] = exists $COLUMN_MAP{$old_column} ? $COLUMN_MAP{$old_column} : $old_column;
    return $new_query;
}

sub add_joins {
    my ($self,$builder,$params) = @_;
    foreach my $search ( @{$params->{searches}}) {
        my $name = $search->{name};
        if (exists $COLUMN_MAP{$name} && ref($COLUMN_MAP{$name}) eq 'HASH' && $COLUMN_MAP{$name}{'joins'}) {
            $builder->from(@{$COLUMN_MAP{$name}{'joins'}});
            if ($name eq 'violation_status') {
                $builder->select(
                    {table => 'violation_status', name => 'status', as => 'violation_status'},
                    {table => 'violation_status_class', name => 'description', as => 'violation_name'}
                );
            }
        }
    }
    if ($params->{online_date}) {
        my $online_date = $params->{online_date};
        my $start = $online_date->{start};
        my $end = $online_date->{end};
        $builder->where(\"node.mac", 'IN', \"select DISTINCT callingstationid from radacct where acctstarttime >= '$start 00:00:00' and acctstoptime <= '$end 23:59:59'");
    }
}

sub _pre_process_query {
    my ($self, $query) = @_;
    #Change the query for the online
    my $name = $query->{name};
    if ($name eq 'online') {
        my $value = $query->{value};
        if($query->{op} eq 'equal') {
            $query->{value} = undef;
            if ($value eq 'unknown' ) {
                $query->{op} = 'is_null';
                $query->{name} = 'unknown';
            } else {
                $query->{name} = 'online_offline';
                $query->{op} = $value eq 'on' ? 'is_null' : 'is_not_null';
            }
        }
    }
    elsif ( $name eq 'mac' || $name eq 'switch_mac' )  {
        my $op = $query->{op};
        if ($op eq 'equal' || $op eq 'not_equal' )  {
            $query->{value} = clean_mac ($query->{value});
        }
    }
}

__PACKAGE__->meta->make_immutable;


=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
