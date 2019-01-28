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
use pf::dal::node;

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

=head2 search

=cut

sub search {
    my ($self, $params) = @_;
    my $logger = get_logger();
    $params = $self->set_params_defaults($params);
    my %args = $self->build_search_args($params);
    my ($status, $iter) = pf::dal::node->search(%args);
    my %results = %$params;
    my $items = $iter->all(undef);
    if (@$items > $params->{per_page}) {
        pop @$items;
        $results{has_next_page} = 1;
    }
    my $itemsKey = $self->itemsKey;
    $results{$itemsKey} = $items;
    return (HTTP_OK, \%results);
}

=head2 build_base_search_args

=cut

sub build_base_search_args {
    my ($self, $params) = @_;
    my $searches = $params->{searches};
    my %args = $self->default_query;
    push @{$args{'-from'}}, $self->make_additionial_joins($searches);
    push @{$args{'-columns'}}, $self->make_additionial_columns($searches);
    return %args;
}

=head2 build_search_args

=cut

sub build_search_args {
    my ($self, $params) = @_;
    return (
        $self->build_base_search_args($params),
        $self->build_additional_search_args($params),
    );
}

=head2 build_additional_search_args

=cut

sub build_additional_search_args {
    my ($self, $params) = @_;
    return (
        -where => $self->make_where($params),
        -order_by => $self->make_order_by($params),
        $self->make_limit_offset($params),
    );
}


=head2 set_params_defaults

=cut

sub set_params_defaults {
    my ($self, $params) = @_;
    $params->{per_page} //= 25;
    $params->{page_num} //= 1;
    $params->{by} //= 'mac';
    $params->{searches} //= [];
    return $params;
}

sub default_query {
    return (
        -columns => [
            (
                map { "node.$_|$_" } qw(
                    mac pid voip bypass_vlan
                    status category_id bypass_role_id
                    user_agent computername last_arp last_dhcp notes
                    tenant_id
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
                    device_manufacturer
                    device_class
                    device_type
                    device_version
                ),
            ),
            "IF(r1.acctstarttime IS NULL,'unknown',IF(r1.acctstoptime IS NULL, 'on', 'off'))|online",
            'ip4log.ip|last_ip',
            'locationlog.switch|switch_id',
            'locationlog.switch_ip|switch_ip',
            'locationlog.switch_mac|switch_mac',
            'locationlog.port|switch_port',
            'locationlog.ifDesc|switch_port_desc',
            'locationlog.ssid|last_ssid',
            'tenant.name|tenant_name',
        ],
        -from => [
            -join =>
                'node',
                '=>{node.category_id=node_category.category_id}', 'node_category',
                '=>{node.tenant_id=tenant.id}', 'tenant',
                '=>{node.bypass_role_id=node_category_bypass_role.category_id}', 'node_category|node_category_bypass_role',
                {
                    operator  => '=>',
                    condition => {
                        'ip4log.ip' => {
                            "=" => \"( SELECT `ip` FROM `ip4log` WHERE `mac` = `node`.`mac` AND `tenant_id` = `node`.`tenant_id`  ORDER BY `start_time` DESC LIMIT 1 )",
                        },
                        'ip4log.tenant_id' => {
                            -ident => 'node.tenant_id'
                        },
                    }
                },
                'ip4log',
                "=>{locationlog.mac=node.mac,node.tenant_id=locationlog.tenant_id,locationlog.end_time='$ZERO_DATE'}", 'locationlog',
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
                '=>{node.mac=r1.callingstationid,node.tenant_id=r1.tenant_id}', 'radacct|r1',
                {
                    operator  => '=>',
                    condition => {
                        'node.mac' => { '=' => { -ident => '%2$s.callingstationid' } },
                        'node.tenant_id' => { '=' => { -ident => '%2$s.tenant_id' } },
                        -or => [
                            '%1$s.acctstarttime' => { '<' => { -ident => '%2$s.acctstarttime' } },
                            -and => [
                                -or => [
                                    '%1$s.acctstarttime' => { '=' => { -ident => '%2$s.acctstarttime' } },
                                    -and => ['%1$s.acctstarttime' => undef, '%2$s.acctstarttime' => undef],
                                ],
                                '%1$s.radacctid' => { '<' => { -ident => '%2$s.radacctid' } },
                            ],
                        ],
                    },
                },
                'radacct|r2'
        ],
        -no_auto_tenant_id => 1,
    );
}

our @SECURITY_EVENT_JOINS_SPECS = (
    '=>{security_event_status.mac=node.mac}',
    'security_event|security_event_status',
    '=>{security_event_status.vid=security_event_status_class.vid}',
    'class|security_event_status_class',
);

our @SECURITY_EVENT_ADDITIONAL_COLUMNS = (
    'security_event_status.status|security_event_status',
    'security_event_status_class.description|security_event_name',
);

our %SEARCH_NAME_TO_TABLE_NAME = (
    'security_event' => {
        'full_name'  => 'security_event_status_class.description',
        'joins_id'   => 'security_event_joins',
        'joins'      => \@SECURITY_EVENT_JOINS_SPECS,
        'columns'    => \@SECURITY_EVENT_ADDITIONAL_COLUMNS,
        'columns_id' => 'security_event',
    },
    'security_event_status' => {
        'full_name'  => 'security_event_status.status',
        'joins_id'   => 'security_event_joins',
        'joins'      => \@SECURITY_EVENT_JOINS_SPECS,
        'columns'    => \@SECURITY_EVENT_ADDITIONAL_COLUMNS,
        'columns_id' => 'security_event',
    },
    'person_name' => {
        'full_name' => 'node.pid'
    },
    'online_offline' => {
        'full_name' => 'r1.acctstoptime'
    },
    'switch_id' => {
        'full_name' => 'locationlog.switch'
    },
    'switch_port' => {
        'full_name' => 'locationlog.port'
    },
    'bypass_role' => {
        'full_name' => 'node_category_bypass_role.name'
    },
    'switch_mac' => {
        'full_name' => 'locationlog.switch_mac'
    },
    'unknown' => {
        'full_name' => 'r1.acctstarttime'
    },
    'switch_ip' => {
        'full_name' => 'locationlog.switch_ip'
    },
    'category' => {
        'full_name' => 'node_category.name'
    },
    'connection_type' => {
        'full_name' => 'locationlog.connection_type'
    },
    'ssid' => {
        'full_name' => 'locationlog.ssid'
    },
    'last_ip' => {
        'full_name' => 'ip4log.ip'
    },
    'switch_port_desc' => {
        'full_name' => 'locationlog.ifDesc'
    }
);

sub make_logical_op {
    my ($self, $all_or_any) = @_;
    $all_or_any ||= 'all';
    return lc($all_or_any) eq 'any' ? '-or' : '-and';
}

sub make_order_by {
    my ($self, $params) = @_;
    my $direction = lc($params->{direction} // 'asc');
    if ($direction ne 'desc') {
        $direction = 'asc';
    }

    my $by = $params->{by} // 'mac';
    my @order_by = ({ "-$direction" => 'tenant_id' }, { "-$direction" => $by });
    return \@order_by;
}

sub make_condition {
    my ($self, $search) = @_;
    my ($value, $op, $name) = @{$search}{qw(value op name)};
    unless (exists $OP_MAP{$op}) {
        die "'$op' is not a supported search operation";
    }
    if (!is_null_op($op) && !defined ($value)) {
        return;
    }
    my $sql_op = $OP_MAP{$op};
    my $condition = { $name => {$sql_op => escape_value($value, $op)} };
    if ($name eq 'r1.acctstoptime') {
        return { -and => [{ 'r1.acctstarttime' => { "!=" => undef } }, $condition] };
    }
    return $condition;
}

sub remap_name {
    my ($name) = @_;
    return
      exists $SEARCH_NAME_TO_TABLE_NAME{$name}
      ? $SEARCH_NAME_TO_TABLE_NAME{$name}{full_name}
      : $name =~ /\./ ?
        $name : "node.$name";
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
    return exists $LIKE_FORMAT{$op} ? $LIKE_FORMAT{$op} : $DEFAULT_LIKE_FORMAT ;
}

sub escape_like {
    my ($value, $format) = @_;
    my $escaped = $value =~ s/([%_\\])/\\$1/g;
    $value = sprintf($format, $value);
    return $escaped ? \[q{? ESCAPE '\\\\'}, $value] : $value;
}

sub make_limit_offset {
    my ($self, $params) = @_;
    my $page_num = $params->{page_num} || 1;
    my $limit = $params->{per_page} || 25;
    my $offset = 
    return (
        -limit => $limit + 1,
        -offset => (( $page_num - 1 ) * $limit)
    );
}

sub make_date_range {
    my ($self, $column, $start, $end) = @_;
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
    my ($self, $params) = @_;
    my @all_conditions;
    my @top_level_conditions = $self->make_top_level_conditions($params);
    my @conditions = $self->make_conditions_from_searches( $params->{searches} // [] );
    my $logical_op = $self->make_logical_op( $params->{all_or_any} );
    if (@top_level_conditions) {
        @all_conditions = ( -and => \@top_level_conditions );
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
    my ($self, $params) = @_;
    my @conditions = (
        'r2.radacctid' => undef,
        'locationlog2.id' => undef,
        'node.tenant_id' => pf::dal::get_tenant(),
    );
    if ($params->{online_date} ) {
        push @conditions, $self->make_online_date($params->{online_date});
    }
    push @conditions, $self->make_date_range('detect_date', $params->{start}, $params->{end});
    return @conditions;
}

sub make_online_date {
    my ($self, $date) = @_;
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
    my ($self, $searches) = @_;
    return map {my $s = $_; $self->make_condition($s) } map { my $s = $_; rewrite_search($s) }  @{$searches // [] };
}

sub rewrite_search {
    my ($s) = @_;
    my $n = $s->{name};
    if ($n eq 'mac' || $n eq 'switch_mac') {
        $s = rewrite_mac_search($s);
    } elsif ($n eq 'online') {
        $s = rewrite_online_search($s);
    }
    $s->{name} = remap_name($s->{name});
    return $s;
}

sub rewrite_online_search {
    my ($s) = @_;
    my $value = $s->{value};
    if ( $s->{op} eq 'equal' ) {
        $s->{value} = undef;
        if ( $value eq 'unknown' ) {
            $s->{op}   = 'is_null';
            $s->{name} = 'unknown';
        }
        else {
            $s->{name} = 'online_offline';
            $s->{op} = $value eq 'on' ? 'is_null' : 'is_not_null';
        }
    }
    return $s;
}

sub rewrite_mac_search {
    my ($s) = @_;
    my %new = %$s;
    my $op = $new{op};
    if ($op eq 'equal' || $op eq 'not_equal' )  {
        my $mac = $new{value};
        if (valid_mac($mac) ) {
            $new{value} = clean_mac($mac);
        }
    }
    return \%new;
}

sub make_additionial_joins {
    my ($self, $searches) = @_;
    return find_additional_search_critera($searches, 'joins');
}

sub make_additionial_columns {
    my ($self, $searches) = @_;
    return find_additional_search_critera($searches, 'columns');
}

sub find_additional_search_critera {
    my ($searches, $namespace) = @_;
    my %found;
    my @joins;
    for my $s (@$searches) {
        my $n = $s->{name};
        next unless exists $SEARCH_NAME_TO_TABLE_NAME{$n};
        my $info = $SEARCH_NAME_TO_TABLE_NAME{$n};
        next unless exists $info->{$namespace};
        my $jid = $info->{"${namespace}_id"};
        next if exists $found{$jid};
        $found{$jid} = undef;
        push @joins, @{$info->{$namespace} // []};
    }
    return @joins;
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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
