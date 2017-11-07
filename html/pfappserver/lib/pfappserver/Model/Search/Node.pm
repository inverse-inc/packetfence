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
use pf::constants;
use pf::SearchBuilder::Node;
use pf::node qw(node_custom_search);
use HTTP::Status qw(:constants);
use pf::util qw(calc_page_count);

our $DEFAULT_LIKE_FORMAT = '%%%s%%';

our %LIKE_FORMAT = (
    not_like    => $DEFAULT_LIKE_FORMAT,
    like        => $DEFAULT_LIKE_FORMAT,
    ends_with   => '%%%s',
    starts_with => '%s%%',
);

our %OP_MAP = (
    equal       => '=',
    not_equal   => '!=',
    not_like    => '-not_like',
    like        => '-like',
    ends_with   => '-like',
    starts_with => '-like',
    in          => '-in',
    not_in      => '-not_in',
    is_null     => '=',
    is_not_null => '!=',
);

extends 'pfappserver::Base::Model::Search';

has 'added_joins' => (is => 'rw', default => sub { {} } );

=head2 search

=cut

sub search {
    my ($self, $params) = @_;
    my $logger = get_logger();
    delete $self->{online_date_search_clause};
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
        my $search = shift @searches;
        $builder->where(@$search);
        for $search (@searches) {
            $builder->where($all_or_any)->where(@$search);
        }
        $builder->where(')');
        $builder->where('AND');
    }
    $builder->where('(');
    $builder->where( { table => 'r2', name => 'radacctid' }, 'IS NULL')->where('AND')
    ->where( { table => 'locationlog2', name => 'id' }, 'IS NULL');
    if ($self->{online_date_search_clause}) {
        $builder->where('AND')->where(@{$self->{online_date_search_clause}});
    }
    $builder->where(')');
}

sub make_builder {
    my ($self) = @_;
    return pf::SearchBuilder::Node->new
        ->select(qw(
            mac pid voip bypass_vlan status category_id bypass_role_id
            user_agent computername last_arp last_dhcp notes),
            L_("IF(lastskip = '$ZERO_DATE', '', lastskip)", 'lastskip'),
            L_("IF(detect_date = '$ZERO_DATE', '', detect_date)", 'detect_date'),
            L_("IF(regdate = '$ZERO_DATE', '', regdate)", 'regdate'),
            L_("IF(unregdate = '$ZERO_DATE', '', unregdate)", 'unregdate'),
            L_("IF(last_seen = '$ZERO_DATE', '', last_seen)", 'last_seen'),
            L_("IFNULL(node_category.name, '')", 'category'),
            L_("IFNULL(node_category_bypass_role.name, '')", 'bypass_role'),
            L_("IFNULL(device_class, ' ')", 'device_class'),
            L_("IFNULL(device_type, ' ')", 'device_type'),
            L_("IFNULL(device_version, ' ')", 'device_version'),
            L_("IF(r1.acctstarttime IS NULL,'unknown',IF(r1.acctstoptime IS NULL, 'on', 'off'))", 'online'),
            { table => 'ip4log', name => 'ip', as => 'last_ip' },
            { table => 'locationlog', name => 'switch', as => 'switch_id' },
            { table => 'locationlog', name => 'switch_ip', as => 'switch_ip' },
            { table => 'locationlog', name => 'switch_mac', as => 'switch_mac' },
            { table => 'locationlog', name => 'port', as => 'switch_port' },
            { table => 'locationlog', name => 'ifDesc', as => 'switch_port_desc' },
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
                    'table' => 'ip4log',
                    'join'  => 'LEFT',
                    'on'    =>
                    [
                        [
                            {
                                'table' => 'ip4log',
                                'name'  => 'ip',
                            },
                            '=',
                            \"( SELECT `ip` FROM `ip4log` WHERE `mac` = `node`.`mac`
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
                           $ZERO_DATE
                        ],
                    ],
                },
                {
                    'table' => 'locationlog',
                    'as' => 'locationlog2',
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
                                'table' => 'locationlog2',
                                'name'  => 'mac',
                            },
                        ],
                        [ 'AND' ],
                        [
                           {
                               'table'  => 'locationlog2',
                               'name'   => 'end_time',
                           },
                           '=',
                           $ZERO_DATE
                        ],
                        [ 'AND' ],
                        ['('],
                        [
                            {
                                'table' => 'locationlog',
                                'name'  => 'start_time',
                            },
                            '<',
                            {
                                'table' => 'locationlog2',
                                'name'  => 'start_time',
                            },
                        ],
                        ['OR'],
                        ['('],
                        [
                            {
                                'table' => 'locationlog',
                                'name'  => 'start_time',
                            },
                            '=',
                            {
                                'table' => 'locationlog2',
                                'name'  => 'start_time',
                            },
                        ],
                        ['AND'],
                        [
                            {
                                'table' => 'locationlog',
                                'name'  => 'id',
                            },
                            '<',
                            {
                                'table' => 'locationlog2',
                                'name'  => 'id',
                            },
                        ],
                        [')'],
                        ['OR'],
                        [
                            {
                                'table' => 'locationlog',
                                'name'  => 'start_time',
                            },
                            'IS NULL',
                        ],
                        [')'],
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

sub default_query {
    return (
        -columns => [
            (
                map { "node.$_|$_" } qw(
                    mac pid voip bypass_vlan
                    status category_id bypass_role_id
                    user_agent computername last_arp last_dhcp notes
                )
            ),
            (
                map { "IF($_='$ZERO_DATE','',$_)|$_" } qw(
                    lastskip detect_date
                    regdate unregdate last_seen
                )
            ),
            "IFNULL(node_category.name, '')|category",
            "IFNULL(node_category_bypass_role.name, '')|bypass_role",
            (
                map { "IFNULL($_,' ')|$_" } qw(
                    device_class
                    device_type
                    device_version
                ),
            ),
            'ip4log.ip|last_ip',
            'locationlog.switch|switch_id',
            'locationlog.switch_ip|switch_ip',
            'locationlog.switch_mac|switch_mac',
            'locationlog.port|switch_port',
            'locationlog.ifDesc|switch_port_desc',
            'locationlog.ssid|last_ssid',
        ],
        -from => [
            -join =>
                'node',
                '=>{node.category_id=node_category.category_id}', 'node_category',
                '=>{node.bypass_role_id=node_category_bypass_role.category_id}', 'node_category|node_category_bypass_role',
                '=>{ip4log.mac=node.mac}', 'ip4log',
                "=>{locationlog.mac=node.mac,locationlog.tenant_id=node.tenant_id,locationlog.end_time='$ZERO_DATE'}", 'locationlog',
                {
                    operator  => '=>',
                    condition => {
                        'node.mac' => { '=' => { -ident => '%2$s.mac' } },
                        'node.tenant_id' => { '=' => { -ident => '%2$s.tenant_id' } },
                        'locationlog2.end_time' => $ZERO_DATE,
                        -or => [
                            '%1$s.start_time' => { '<' => { -ident => '%2$s.start_time' } },
                            '%1$s.start_time' => undef,
                            -and => [
                                '%1$s.start_time' => { '=' => { -ident => '%2$s.start_time' } },
                                '%1$s.id' => { '<' => { -ident => '%2$s.id' } },
                            ],
                        ],
                    },
                },
                'locationlog|locationlog2',
                '=>{node.mac=radacct.callingstationid}', 'radacct',
                {
                    operator  => '=>',
                    condition => {
                        'node.mac' => { '=' => { -ident => '%2$s.callingstationid' } },
                        -or => [
                            '%1$s.acctstarttime' => { '<' => { -ident => '%2$s.acctstarttime' } },
                            '%1$s.acctstarttime' => undef,
                            -and => [
                                '%1$s.acctstarttime' => { '=' => { -ident => '%2$s.acctstarttime' } },
                                '%1$s.radacctid' => { '<' => { -ident => '%2$s.radacctid' } },
                            ],
                        ],
                    },
                },
                'radacct|r2'
        ],
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

sub make_logical_op {
    my ($all_or_any) = @_;
    $all_or_any ||= 'all';
    return lc($all_or_any) eq 'any' ? '-or' : '-and';
}


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
        $self->{online_date_search_clause} = [\"node.mac", 'IN', \"select DISTINCT callingstationid from radacct where acctstarttime >= '$start 00:00:00' and acctstoptime <= '$end 23:59:59'"];
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

sub make_order_by {
    my ($params) = @_;
    my $direction = lc($params->{direction} // 'asc');
    if ($direction ne 'desc') {
        $direction = 'asc';
    }
    my $by = $params->{by};
    return { "-$direction" => $by };
}

sub make_condition {
    my ($search) = @_;
    my ($value, $op, $name) = @{$search}{qw(value op name)};
    unless (exists $OP_MAP{$op}) {
        die "'$op' is not a supported search operation";
    }
    if (!is_null_op($op) && !defined ($value)) {
        return;
    }
    my $sql_op = $OP_MAP{$op};
    return { $name => {$sql_op => escape_value($value, $op)} };
}

sub escape_value {
    my ($value, $op) = @_;
    if (is_like_op($op)) {
        return escape_like($value, find_like_format($op));
    }
    if (is_null_op($op)) {
        return undef;
    }
    return $value;
}

sub is_null_op {
    my ($op) = @_;
    return $op eq 'is_null' || $op eq 'is_not_null';
}

sub is_like_op {
    my ($op) = @_;
    return exists $LIKE_FORMAT{$op};
}

sub find_like_format {
    my ($op) = @_;
    return  exists $LIKE_FORMAT{$op} ? $LIKE_FORMAT{$op} : $DEFAULT_LIKE_FORMAT ;
}

sub escape_like {
    my ($value, $format) = @_;
    my $escaped = $value =~ s/([%_])/\\$1/g;
    $value = sprintf($format, $value);
    return $escaped ? \[q{? ESCAPE '\'}, $value] : $value;
}

sub make_limit_offset {
    my ($params) = @_;
    my $page_num = $params->{page_num} || 1;
    my $limit = $params->{per_page} || 25;
    my $offset = 
    return {
        -limit => $limit,
        -offset => (( $page_num - 1 ) * $limit)
    };
}

sub make_date_range {
    my ($column, $start, $end) = @_;
    my @condtions; 
    if ($start) {
        push @condtions, {">=" => "$start 00:00:00"};
    }
    if ($end) {
        push @condtions, {"<=" => "$end 23:59:59"};
    }
    if (@condtions) {
        return {$column => [-and => @condtions]};
    }
    return;
}

sub make_where {
    my ($params) = @_;
    my @all_conditions;
    my @top_level_conditions = make_top_level_conditions($params);
    my @conditions = make_conditions_from_searches($params->{searches} // []);
    my $logical_op = make_logical_op($params->{all_or_any});
    if (@top_level_conditions) {
        @all_conditions = (-and => \@top_level_conditions );
        if (@conditions) {
            push @top_level_conditions, $logical_op => \@conditions;
        }
    }
    elsif (@conditions) {
        push @all_conditions, $logical_op => \@conditions;
    }
    return \@all_conditions;
}

sub make_top_level_conditions {
    my ($params) = @_;
    my @conditions = (
        'r2.radacctid' => undef,
        'locationlog2.id' => undef
    );
    if ($params->{online_date} ) {
        push @conditions, make_online_date($params->{online_date});
    }
    push @conditions, make_date_range('detect_date', $params->{start}, $params->{end});
    return @conditions;
}

sub make_online_date {
    my ($date) = @_;
    my $start = $date->{start};
    my $end = $date->{end};
    return {
        "node.mac" => {
            '-in',
            \[
"select DISTINCT callingstationid from radacct where acctstarttime >= ? AND acctstoptime <= ?",
                "$start 00:00:00",
                "$end 23:59:59"
            ]
        }
    };
}

sub make_conditions_from_searches {
    my ($searches) = @_;
    return map { make_condition($_) } @{$searches // [] };
}

sub build_search {
    my ($params) = @_;
    my $order_by = make_order_by($params);
    my $limit = make_limit_offset($params);
    my $where = make_where($params);
    return {
        -where => $where,
        -order_by => $order_by,
        %$limit
    };
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};


=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
