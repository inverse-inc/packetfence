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
use pf::dal::security_event;
use pf::dal::radacct;
use pf::util qw(clean_mac ip2int valid_ip);
use pf::constants qw($ZERO_DATE);
use pf::UnifiedApi::Search;

our @LOCATION_LOG_JOIN = (
    "=>{locationlog.mac=node.mac,locationlog.end_time='$ZERO_DATE'}",
    "locationlog",
);

our @IP4LOG_JOIN = (
    {
        operator  => '=>',
        condition => {
            'ip4log.ip' => {
                "=" => \
"( SELECT `ip` FROM `ip4log` WHERE `mac` = `node`.`mac` ORDER BY `start_time` DESC LIMIT 1 )",
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
"( SELECT `ip` FROM `ip6log` WHERE `mac` = `node`.`mac` ORDER BY `start_time` DESC LIMIT 1 )",
            }
        }
    },
    'ip6log',
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
            'security_event_close.status' => { '=' => "closed" },
        },
    },
    'security_event|security_event_close',
);

our @SECURITY_EVENT_DELAYED_JOIN = (
    {
        operator  => '=>',
        condition => {
            'node.mac' => { '=' => { -ident => '%2$s.mac' } },
            'security_event_delay.status' => { '=' => "delayed" },
        },
    },
    'security_event|security_event_delay',
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
        namespace     => 'online',
        rewrite_query => \&rewrite_online_query,
        column_spec   => "CASE IFNULL( (SELECT is_online from node_current_session as ncs WHERE ncs.mac = node.mac), 'unknown') WHEN 'unknown' THEN 'unknown' WHEN 0 THEN 'off' ELSE 'on' END|online"
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
    map_dal_fields_to_join_spec("pf::dal::locationlog", \@LOCATION_LOG_JOIN, undef, {switch_ip => 1}),
    'locationlog.switch_ip' => {
        join_spec     => \@LOCATION_LOG_JOIN,
        namespace     => 'locationlog',
        rewrite_query => \&rewrite_switch_ip,
        column_spec   => make_join_column_spec( 'locationlog', 'switch_ip' ),
    },
    security_events_count('open'),
    security_events_count('closed'),
    security_events_count('delayed'),
    'mac' => {
        rewrite_query => \&rewrite_mac_query,
    }
);

sub security_events_count {
    my ($status) = @_;
    return (
        "security_event.${status}_count" => {
            namespace => "security_event_${status}",
            rewrite_query => sub {
                my ($self, $s, $q) = @_;
                $self->rewrite_security_event_status_count($s, $q, $status);
            },
            column_spec => \"(SELECT COUNT(*) as count FROM security_event WHERE node.mac = security_event.mac AND status = '${status}' ) AS `security_event.${status}_count`",
        },
        "security_event.${status}_security_event_id" => {
            namespace => "security_event.${status}_security_event_id",
            rewrite_query => sub {
                my ($self, $s, $q) = @_;
                return $self->rewrite_security_event_security_event_id_status($s, $q, $status);
            },
            column_spec => \"(SELECT GROUP_CONCAT(security_event_id) FROM security_event WHERE node.mac = security_event.mac AND status = '${status}' ) AS `security_event.${status}_security_event_id`",
        },
    )
}

sub rewrite_mac_query {
    my ( $self, $s, $q ) = @_;
    my $value       = $q->{value};
    my $cleaned_mac = clean_mac($value);
    if ( $cleaned_mac ne "0" ) {
        $q->{value} = $cleaned_mac;
    }

    return ( 200, $q );
}

sub non_searchable {
    my ($self, $s, $q) = @_;
    return (422, { message => "$q->{field} is not searchable" });
}

sub rewrite_security_event_security_event_id_status {
    my ($self, $s, $q, $status) = @_;
    my $op = $q->{op};
    my $value = $q->{value};
    if (!defined $value) {
        return (422, { message => "value cannot be null for $q->{field} field" });
    }

    if ($op ne 'equals' && $op ne 'not_equals') {
        return (422, { message => "$op is not valid for $q->{field} field" });
    }

    my ($sql, @bind) = pf::dal::security_event->select(
        -from => 'security_event',
        -columns => [\1],
        -where => {
            'security_event.mac' => { '=' => {-ident => 'node.mac'} },
            'security_event.status' => $status,
            'security_event.security_event_id' => {
                 $pf::UnifiedApi::Search::OP_TO_SQL_OP{$op} => $value,
            },
        },
    );

    return (200, \["EXISTS ($sql)", @bind]);
}

our %SECURITY_EVENT_COUNTS_ALLOWED_OPS = (
    equals              => 1,
    not_equals          => 1,
    greater_than        => 1,
    less_than           => 1,
    greater_than_equals => 1,
    less_than_equals    => 1,
);

sub rewrite_security_event_status_count {
    my ($self, $s, $q, $status) = @_;
    my $op = $q->{op};
    my $value = $q->{value};
    if (!defined $value) {
        return (422, { message => "value cannot be null for $q->{field} field" });
    }

    if (!exists $SECURITY_EVENT_COUNTS_ALLOWED_OPS{$op}) {
        return (422, { message => "$op is not valid for $q->{field} field" });
    }

    my ($sql, @bind) = pf::dal::security_event->select(
        -from => 'security_event',
        -columns => [\1],
        -where => {
            'security_event.mac' => { '=' => {-ident => 'node.mac'} },
            'security_event.status' => $status,
        },
        -group_by => ['id'],
        -having => [
            \["COUNT(*) $pf::UnifiedApi::Search::OP_TO_SQL_OP{$op} ?", $value]
        ],
    );
    $sql =~ s/GROUP BY.*?HAVING/HAVING/;
    return (200, \["EXISTS ($sql)", @bind]);
}

our $ON_QUERY = "EXISTS (SELECT 1 from node_current_session as ncs WHERE ncs.mac = node.mac AND is_online)";
our $OFF_QUERY = "EXISTS (SELECT 1 from node_current_session as ncs WHERE ncs.mac = node.mac AND NOT is_online)";
our $NOT_UNKNOWN_QUERY = "EXISTS (SELECT 1 from node_current_session as ncs WHERE ncs.mac = node.mac)";
our $UNKNOWN_QUERY = "NOT $NOT_UNKNOWN_QUERY";

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

    if ($value eq 'unknown') {
        if ($op eq 'equals') {
            return (200, \[$UNKNOWN_QUERY]);
        }

        return (200, \[$NOT_UNKNOWN_QUERY]);
    }

    if ($op eq 'equals') {
        if ($value eq 'on') {
            return (200, \[$ON_QUERY]);
        }

        return (200, \[$OFF_QUERY]);
    }

    if ($value eq 'on') {
        return (200, \["( ($UNKNOWN_QUERY) OR ($OFF_QUERY) )"]);
    }

    return (200, \["( ($UNKNOWN_QUERY) OR ($ON_QUERY) )"]);
}

sub map_dal_fields_to_join_spec {
    my ($dal, $join_spec, $where_spec, $exclude) = @_;
    $exclude //= {};
    my $table = $dal->table;
    return map { map_dal_field_to_join_spec($table, $_, $join_spec, $where_spec) } grep {!exists $exclude->{$_}} @{$dal->table_field_names};
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

sub rewrite_switch_ip {
    my ($self, $s, $q) = @_;
    if (valid_ip($q->{value})) {
        $q->{value} = ip2int($q->{value});
        $q->{field} = 'locationlog.switch_ip_int';
    }

    return (200, $q);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

