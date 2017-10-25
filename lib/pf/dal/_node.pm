package pf::dal::_node;

=head1 NAME

pf::dal::_node - pf::dal implementation for the table node

=cut

=head1 DESCRIPTION

pf::dal::_node

pf::dal implementation for the table node

=cut

use strict;
use warnings;

###
### pf::dal::_node is auto generated any change to this file will be lost
### Instead change in the pf::dal::node module
###
use base qw(pf::dal);

our @FIELD_NAMES;
our @INSERTABLE_FIELDS;
our @PRIMARY_KEYS;
our %DEFAULTS;
our %FIELDS_META;
our @COLUMN_NAMES;

BEGIN {
    @FIELD_NAMES = qw(
        tenant_id
        mac
        pid
        category_id
        detect_date
        regdate
        unregdate
        lastskip
        time_balance
        bandwidth_balance
        status
        user_agent
        computername
        notes
        last_arp
        last_dhcp
        dhcp_fingerprint
        dhcp6_fingerprint
        dhcp_vendor
        dhcp6_enterprise
        device_type
        device_class
        device_version
        device_score
        bypass_vlan
        voip
        autoreg
        sessionid
        machine_account
        bypass_role_id
        last_seen
    );

    %DEFAULTS = (
        tenant_id => '1',
        mac => '',
        pid => 'default',
        category_id => undef,
        detect_date => '0000-00-00 00:00:00',
        regdate => '0000-00-00 00:00:00',
        unregdate => '0000-00-00 00:00:00',
        lastskip => '0000-00-00 00:00:00',
        time_balance => undef,
        bandwidth_balance => undef,
        status => 'unreg',
        user_agent => undef,
        computername => undef,
        notes => undef,
        last_arp => '0000-00-00 00:00:00',
        last_dhcp => '0000-00-00 00:00:00',
        dhcp_fingerprint => undef,
        dhcp6_fingerprint => undef,
        dhcp_vendor => undef,
        dhcp6_enterprise => undef,
        device_type => undef,
        device_class => undef,
        device_version => undef,
        device_score => undef,
        bypass_vlan => undef,
        voip => 'no',
        autoreg => 'no',
        sessionid => undef,
        machine_account => undef,
        bypass_role_id => undef,
        last_seen => '0000-00-00 00:00:00',
    );

    @INSERTABLE_FIELDS = qw(
        tenant_id
        mac
        pid
        category_id
        detect_date
        regdate
        unregdate
        lastskip
        time_balance
        bandwidth_balance
        status
        user_agent
        computername
        notes
        last_arp
        last_dhcp
        dhcp_fingerprint
        dhcp6_fingerprint
        dhcp_vendor
        dhcp6_enterprise
        device_type
        device_class
        device_version
        device_score
        bypass_vlan
        voip
        autoreg
        sessionid
        machine_account
        bypass_role_id
        last_seen
    );

    %FIELDS_META = (
        tenant_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        mac => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        pid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        category_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        detect_date => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        regdate => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        unregdate => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        lastskip => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        time_balance => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        bandwidth_balance => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        status => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        user_agent => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        computername => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        notes => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        last_arp => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        last_dhcp => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        dhcp_fingerprint => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        dhcp6_fingerprint => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        dhcp_vendor => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        dhcp6_enterprise => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        device_type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        device_class => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        device_version => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        device_score => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        bypass_vlan => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        voip => {
            type => 'ENUM',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
            enums_values => {
                'no' => 1,
                'yes' => 1,
            },
        },
        autoreg => {
            type => 'ENUM',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
            enums_values => {
                'no' => 1,
                'yes' => 1,
            },
        },
        sessionid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        machine_account => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        bypass_role_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        last_seen => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
    );

    @PRIMARY_KEYS = qw(
        mac
    );

    @COLUMN_NAMES = qw(
        node.tenant_id
        node.mac
        node.pid
        node.category_id
        node.detect_date
        node.regdate
        node.unregdate
        node.lastskip
        node.time_balance
        node.bandwidth_balance
        node.status
        node.user_agent
        node.computername
        node.notes
        node.last_arp
        node.last_dhcp
        node.dhcp_fingerprint
        node.dhcp6_fingerprint
        node.dhcp_vendor
        node.dhcp6_enterprise
        node.device_type
        node.device_class
        node.device_version
        node.device_score
        node.bypass_vlan
        node.voip
        node.autoreg
        node.sessionid
        node.machine_account
        node.bypass_role_id
        node.last_seen
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of node

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of node

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of node

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "node" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `node` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row node

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for node

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for node

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for node

=cut

sub get_meta {
    return \%FIELDS_META;
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
