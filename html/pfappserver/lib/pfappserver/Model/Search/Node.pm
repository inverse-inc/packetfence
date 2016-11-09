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
use pf::util qw(calc_page_count clean_mac valid_mac);
use pf::SearchBuilder;
use pf::SearchBuilder::Node;
use pf::node qw(node_custom_search);
use HTTP::Status qw(:constants);
use pf::util qw(calc_page_count);

extends 'pfappserver::Base::Model::Search';

has 'added_joins' => (is => 'rw', default => sub { {} } );

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
    $self->add_date_range($builder, 'detect_date', $params, @{$params}{qw(start end)});
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
    my $items = [node_custom_search($sql)];
    my $has_next_page;
    if (@$items > $per_page) {
        pop @$items;
        $has_next_page = 1;
    }
    $results{$itemsKey} = $items;
    $results{per_page} = $per_page;
    $results{page_num} = $page_num;
    $results{has_next_page} = $has_next_page;
    return \%results;
}

sub add_searches {
    my ( $self, $builder, $params ) = @_;
    my (@searches) = map { $self->process_query($_) } @{ $params->{searches} };
    my $all_or_any = $params->{all_or_any} || 'all';
    if ( $all_or_any eq 'any' ) {
        $all_or_any = 'or';
    }
    else {
        $all_or_any = 'and';
    }
    if (@searches) {
        $builder->where('(');
        $builder->where($all_or_any)->where(@$_) for @searches;
        $builder->where(')');
        $builder->where('AND');
    }
    $builder->where( { table => 'r2', name => 'radacctid' }, 'IS NULL' );
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
            L_("IFNULL(device_class, ' ')", 'device_class'),
            L_("IFNULL(device_type, ' ')", 'device_type'),
            L_("IFNULL(device_version, ' ')", 'device_version'),
            L_("IF(r1.acctstarttime IS NULL,'unknown',IF(r1.acctstoptime IS NULL, 'on', 'off'))", 'online'),
            { table => 'iplog', name => 'ip', as => 'last_ip' },
            { table => 'locationlog', name => 'switch', as => 'switch_id' },
            { table => 'locationlog', name => 'switch_ip', as => 'switch_ip' },
            { table => 'locationlog', name => 'switch_mac', as => 'switch_mac' },
            { table => 'locationlog', name => 'port', as => 'switch_port' },
            { table => 'locationlog', name => 'ssid', as => 'last_ssid' },
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
                    'as'    => 'r1',
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
                                'table' => 'r1',
                                'name'  => 'callingstationid',
                            },
                        ],
                    ],
                },
                {
                    'table' => 'radacct',
                    'as'    => 'r2',
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
                                'table' => 'r2',
                                'name'  => 'callingstationid',
                            },
                        ],
                        ['AND'],
                        ['('],
                        [
                            {
                                'table' => 'r1',
                                'name'  => 'acctstarttime',
                            },
                            '<',
                            {
                                'table' => 'r2',
                                'name'  => 'acctstarttime',
                            },
                        ],
                        ['OR'],
                        ['('],
                        [
                            {
                                'table' => 'r1',
                                'name'  => 'acctstarttime',
                            },
                            '=',
                            {
                                'table' => 'r2',
                                'name'  => 'acctstarttime',
                            },
                        ],
                        ['AND'],
                        [
                            {
                                'table' => 'r1',
                                'name'  => 'radacctid',
                            },
                            '<',
                            {
                                'table' => 'r2',
                                'name'  => 'radacctid',
                            },
                        ],
                        [')'],
                        ['OR'],
                        [
                            {
                                'table' => 'r1',
                                'name'  => 'acctstarttime',
                            },
                            'IS NULL',
                        ],
                        [')'],
                    ],
                },
        );
}

my @VIOLATION_JOINS = (
    {
        'table' => 'violation',
        'join'  => 'LEFT',
        'as'    => 'violation_status',
        'on'    => [
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
        'table' => 'class',
        'join'  => 'LEFT',
        'as'    => 'violation_status_class',
        'on'    => [
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
    ssid   => {
       table => 'locationlog',
       name  => 'ssid',
    },
    connection_type   => {
       table => 'locationlog',
       name  => 'connection_type',
    },
    last_ip   => {
       table => 'iplog',
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

sub add_order_by {
    my ($self, $builder, $params) = @_;
    my ($by, $direction) = @$params{qw(by direction)};
    if ($by && $direction) {
        if ($by eq 'online') {
            my $temp = $by;
            $by = \$temp;
        } else {
            $by = $COLUMN_MAP{$by} if (exists $COLUMN_MAP{$by});
        }
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
    if ($old_column eq 'online_offline') {
        my $fragment = "(r1.acctstarttime IS NOT NULL AND $new_query->[0]->{table}.$new_query->[0]->{name} $new_query->[1])";
        return [\$fragment];
    }
    return $new_query;
}

sub add_joins {
    my ($self,$builder,$params) = @_;
    foreach my $search ( @{$params->{searches}}) {
        my $name = $search->{name};
        if (exists $COLUMN_MAP{$name} && ref($COLUMN_MAP{$name}) eq 'HASH' && $COLUMN_MAP{$name}{'joins'}) {
            my $joins_id = $COLUMN_MAP{$name}{joins_id};
            unless ( exists $self->added_joins->{$joins_id} ) {
                $builder->from(@{$COLUMN_MAP{$name}{'joins'}});
                $self->added_joins->{$joins_id} = 1;
                if ($name eq 'violation_status') {
                    $builder->select(
                        {table => 'violation_status', name => 'status', as => 'violation_status'},
                        {table => 'violation_status_class', name => 'description', as => 'violation_name'}
                    );
                }
            }
        }
    }
    if ($params->{online_date}) {
        my $online_date = $params->{online_date};
        my $start = $online_date->{start};
        my $end = $online_date->{end};
        $builder->where(\"UPPER(REPLACE(node.mac,':',''))", 'IN', \"select DISTINCT callingstationid from radacct where acctstarttime >= '$start 00:00:00' and acctstoptime <= '$end 23:59:59'");
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
            my $mac = $query->{value};
            if (valid_mac ($mac) ) {
                $query->{value} = clean_mac ($mac);
            }
        }
    }
}

=head2 add_limit

add limits to the sql builder

=cut

sub add_limit {
    my ($self, $builder, $params) = @_;
    my $page_num = $params->{page_num} || 1;
    my $limit  = $params->{per_page} || 25;
    my $offset = (( $page_num - 1 ) * $limit);
    $builder->limit($limit + 1, $offset);
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
