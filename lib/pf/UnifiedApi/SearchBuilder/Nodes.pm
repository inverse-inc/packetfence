package pf::UnifiedApi::SearchBuilder::Nodes;

=head1 NAME

pf::UnifiedApi::SearchBuilder::Nodes -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::SearchBuilder::Nodes

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::UnifiedApi::SearchBuilder);
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
            }
        }
    },
    'ip4log',
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

our %ALLOWED_JOIN_FIELDS = (
    'ip4log.ip' => {
        join_spec => \@IP4LOG_JOIN,
        'column_spec' => 'ip4log.ip|ip4log_ip',
        namespace => 'ip4log',
    },
    'radacct.online' => {
        join_spec  => \@RADACCT_JOIN,
        where_spec => \%RADACCT_WHERE,
        namespace => 'radacct',
        column_spec => "IF(radacct.acctstarttime IS NULL,'unknown',IF(radacct.acctstoptime IS NULL, 'on', 'off'))|radacct_online",
    },
    (
        map {
            (
                "radacct.$_" => {
                    join_spec  => \@RADACCT_JOIN,
                    where_spec => \%RADACCT_WHERE,
                    namespace => 'radacct',
                    column_spec => "radacct.$_|radacct_$_"
                }
            )
          } 
          @{pf::dal::radacct->table_field_names}
    ),
    (
        map {
            (
                "locationlog.$_" => {
                    join_spec  => \@LOCATION_LOG_JOIN,
                    where_spec => \%LOCATION_LOG_WHERE,
                    column_spec => "locationlog.$_|locationlog_$_"
                }
            )
          } @{pf::dal::locationlog->table_field_names}
    ),

);

sub allowed_join_fields {
    \%ALLOWED_JOIN_FIELDS
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

