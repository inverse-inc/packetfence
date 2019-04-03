package pf::UnifiedApi::Search::Builder::Nodes;

=head1 NAME

pf::UnifiedApi::Search::Builder::Nodes -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Search::Builder::Nodes

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::UnifiedApi::Search::Builder);
use pf::dal::node;
use pf::dal::locationlog;
use pf::dal::radacct;
use pf::constants qw($ZERO_DATE);

our @LOCATION_LOG_JOIN = (
    "=>{locationlog.mac=node.mac,node.tenant_id=locationlog.tenant_id,locationlog.end_time='$ZERO_DATE'}",
    'locationlog',
    {
        operator  => '=>',
        condition => {
            'node.mac'       => { '=' => { -ident => '%2$s.mac' } },
            'node.tenant_id' => { '=' => { -ident => '%2$s.tenant_id' } },
            'locationlog2.end_time' => $ZERO_DATE,
            -or                     => [
                '%1$s.start_time' => { '<' => { -ident => '%2$s.start_time' } },
                '%1$s.start_time' => undef,
                -and              => [
                    '%1$s.start_time' =>
                      { '=' => { -ident => '%2$s.start_time' } },
                    '%1$s.id' => { '<' => { -ident => '%2$s.id' } },
                ],
            ],
        },
    },
    'locationlog|locationlog2',
);

our @IP4LOG_JOIN = (
    {
        operator  => '=>',
        condition => {
            'ip4log.ip' => {
                "=" => \
"( SELECT `ip` FROM `ip4log` WHERE `mac` = `node`.`mac` AND `tenant_id` = `node`.`tenant_id`  ORDER BY `start_time` DESC LIMIT 1 )",
            },
            'ip4log.tenant_id' => {
                -ident => 'node.tenant_id'
            },
        }
    },
    'ip4log',
);

our @IP6LOG_JOIN = (
    {
        operator  => '=>',
        condition => {
            'ip6log.ip' => {
                "=" => \
"( SELECT `ip` FROM `ip6log` WHERE `mac` = `node`.`mac` AND `tenant_id` = `node`.`tenant_id`  ORDER BY `start_time` DESC LIMIT 1 )",
            }
        }
    },
    'ip6log',
);

our @RADACCT_JOIN = (
    '=>{node.mac=radacct.callingstationid,node.tenant_id=radacct.tenant_id}',
    'radacct|radacct',
    {
        operator  => '=>',
        condition => {
            'node.mac' => { '=' => { -ident => '%2$s.callingstationid' } },
            'node.tenant_id' => { '=' => { -ident => '%2$s.tenant_id' } },
            -or              => [
                '%1$s.acctstarttime' =>
                  { '<' => { -ident => '%2$s.acctstarttime' } },
                -and => [
                    -or => [
                        '%1$s.acctstarttime' =>
                          { '=' => { -ident => '%2$s.acctstarttime' } },
                        -and => [
                            '%1$s.acctstarttime' => undef,
                            '%2$s.acctstarttime' => undef
                        ],
                    ],
                    '%1$s.radacctid' =>
                      { '<' => { -ident => '%2$s.radacctid' } },
                ],
            ],
        },
    },
    'radacct|r2'
);

our %RADACCT_WHERE = (
    'r2.radacctid' => undef,
);

our %LOCATION_LOG_WHERE = (
    'locationlog2.id' => undef,
);

our @NODE_CATEGORY_JOIN = (
    '=>{node.category_id=node_category.category_id}', 'node_category',
);

our @NODE_CATEGORY_ROLE_JOIN = (
    '=>{node.bypass_role_id=node_category_bypass_role.category_id}', 'node_category|node_category_bypass_role',
);

our @SECURITY_EVENT_OPEN_JOIN = (
    {
        operator  => '=>',
        condition => {
            'node.mac' => { '=' => { -ident => '%2$s.mac' } },
            'node.tenant_id' => { '=' => { -ident => '%2$s.tenant_id' } },
            'security_event_open.status' => { '=' => "open" },
        },
    },
    'security_event|security_event_open',
);

our @SECURITY_EVENT_CLOSED_JOIN = (
    {
        operator  => '=>',
        condition => {
            'node.mac' => { '=' => { -ident => '%2$s.mac' } },
            'node.tenant_id' => { '=' => { -ident => '%2$s.tenant_id' } },
            'security_event_close.status' => { '=' => "closed" },
        },
    },
    'security_event|security_event_close',
);

our %ALLOWED_JOIN_FIELDS = (
    'ip4log.ip' => {
        join_spec     => \@IP4LOG_JOIN,
        column_spec   => make_join_column_spec( 'ip4log', 'ip' ),
        namespace     => 'ip4log',
    },
    'ip6log.ip' => {
        join_spec     => \@IP6LOG_JOIN,
        column_spec   => make_join_column_spec( 'ip6log', 'ip' ),
        namespace     => 'ip6log',
    },
    'online' => {
        join_spec     => \@RADACCT_JOIN,
        where_spec    => \%RADACCT_WHERE,
        namespace     => 'radacct',
        rewrite_query => \&rewrite_online_query,
        column_spec   => "IF(radacct.acctstarttime IS NULL,'unknown',IF(radacct.acctstoptime IS NULL, 'on', 'off'))|online",
    },
    'node_category.name' => {
        join_spec   => \@NODE_CATEGORY_JOIN,
        namespace   => 'node_category',
        column_spec => \"IFNULL(node_category.name, '') as `node_category.name`",
    },
    'node_category_bypass_role.name' => {
        join_spec   => \@NODE_CATEGORY_ROLE_JOIN,
        namespace   => 'node_category_bypass_role',
        column_spec => \"IFNULL(node_category_bypass_role.name, '') as `node_category_bypass_role.name`",
    },
    map_dal_fields_to_join_spec("pf::dal::radacct", \@RADACCT_JOIN, \%RADACCT_WHERE),
    map_dal_fields_to_join_spec("pf::dal::locationlog", \@LOCATION_LOG_JOIN, \%LOCATION_LOG_WHERE),
    'security_event.open_count' => {
        namespace => 'security_event_open',
        join_spec => \@SECURITY_EVENT_OPEN_JOIN,
        rewrite_query => \&rewrite_security_event_open_count,
        group_by => 1,
        column_spec => \"COUNT(security_event_open.id) AS `security_event.open_count`",
    },
    'security_event.open_security_event_id' => {
        namespace => 'security_event_open',
        join_spec => \@SECURITY_EVENT_OPEN_JOIN,
        rewrite_query => \&rewrite_security_event_open_security_event_id,
        group_by => 1,
        column_spec => \"GROUP_CONCAT(security_event_open.security_event_id) AS `security_event.open_security_event_id`"
    },
    'security_event.close_count' => {
        namespace => 'security_event_close',
        join_spec => \@SECURITY_EVENT_CLOSED_JOIN,
        rewrite_query => \&rewrite_security_event_close_count,
        group_by => 1,
        column_spec => \"COUNT(security_event_close.id) AS `security_event.close_count`",
    },
    'security_event.close_security_event_id' => {
        namespace => 'security_event_close',
        join_spec => \@SECURITY_EVENT_CLOSED_JOIN,
        rewrite_query => \&rewrite_security_event_close_security_event_id,
        group_by => 1,
        column_spec => \"GROUP_CONCAT(security_event_close.security_event_id) AS `security_event.close_security_event_id`"
    },
);


sub non_searchable {
    my ($self, $s, $q) = @_;
    return (422, { message => "$q->{field} is not searchable" });
}

sub rewrite_security_event_open_security_event_id {
    my ($self, $s, $q) = @_;
    $q->{field} = 'security_event_open.security_event_id';
    return (200, $q);
}

sub rewrite_security_event_open_count {
    my ($self, $s, $q) = @_;
    $q->{field} = 'COUNT(security_event_open.id)';
    return (200, $q);
}

sub rewrite_security_event_close_security_event_id {
    my ($self, $s, $q) = @_;
    $q->{field} = 'security_event_close.security_event_id';
    return (200, $q);
}

sub rewrite_security_event_close_count {
    my ($self, $s, $q) = @_;
    $q->{field} = 'COUNT(security_event_close.id)';
    return (200, $q);
}

sub rewrite_online_query {
    my ($self, $s, $q) = @_;
    my $op =$q->{op};
    if ($op ne 'equals' && $op ne 'not_equals') {
        return (422, { message => "$op is not valid for the online field" });
    }

    my $value = $q->{value};
    if (!defined $value || ($value ne 'on' && $value ne 'off' && $value ne 'unknown')) {
        return (422, { message => "value of " . ($value // "(null)"). " is not valid for the online field" });
    }

    if ($op eq 'equals') {
        $q->{value} = undef;
        if ($value eq 'unknown') {
            $q->{field} = 'radacct.acctstarttime';
        } else {
            if ($value eq 'on') {
                delete @{$q}{'field' ,'value'};
                $q->{op} = 'and';
                $q->{'values'} = [
                    { op => 'not_equals', value => undef, field => 'radacct.acctstarttime' },
                    { op => 'equals', value => undef, field => 'radacct.acctstoptime' },
                ];
            } else {
                $q->{field} = 'radacct.acctstoptime';
                $q->{op} = 'not_equals';
            }
        }
    } elsif ($op eq 'not_equals') {
        $q->{value} = undef;
        if ($value eq 'unknown') {
            $q->{field} = 'radacct.acctstarttime';
        } else {
            delete @{$q}{'field' ,'value'};
            $q->{op} = 'or';
            $q->{'values'} = [
                { op => 'equals', value => undef, field => 'radacct.acctstarttime' },
                { op => 'equals', value => undef, field => 'radacct.acctstoptime' },
            ];
            if ($value eq 'on') {
                $q->{'values'}[-1]{op} = 'not_equals';
            }
        }
    }
    return (200, $q);
}

sub map_dal_fields_to_join_spec {
    my ($dal, $join_spec, $where_spec, $exclude) = @_;
    $exclude //= {};
    my $table = $dal->table;
    return map { map_dal_field_to_join_spec($table, $_,$join_spec, $where_spec) } grep {!exists $exclude->{$_}} @{$dal->table_field_names}; 
}

sub map_dal_field_to_join_spec {
    my ($table, $field, $join_spec, $where_spec) = @_;
    return "${table}.${field}" => {
        join_spec => $join_spec,
        namespace => $table,
        (defined $where_spec ? (where_spec => $where_spec) : () ),
        column_spec => make_join_column_spec($table, $field),
   } 
}

sub make_join_column_spec {
    my ($t, $f) = @_;
    return \"`${t}`.`${f}` AS `${t}.${f}`";
}

sub allowed_join_fields {
    \%ALLOWED_JOIN_FIELDS
}

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

