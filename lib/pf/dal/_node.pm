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

BEGIN {
    @FIELD_NAMES = qw(
        autoreg
        device_version
        status
        bypass_vlan
        device_class
        bandwidth_balance
        regdate
        category_id
        device_type
        pid
        machine_account
        dhcp6_enterprise
        dhcp6_fingerprint
        mac
        device_score
        last_arp
        lastskip
        last_dhcp
        user_agent
        dhcp_fingerprint
        computername
        detect_date
        voip
        bypass_role_id
        notes
        time_balance
        sessionid
        dhcp_vendor
        unregdate
    );

    %DEFAULTS = (
        autoreg => 'no',
        device_version => undef,
        status => 'unreg',
        bypass_vlan => undef,
        device_class => undef,
        bandwidth_balance => undef,
        regdate => '0000-00-00 00:00:00',
        category_id => undef,
        device_type => undef,
        pid => 'default',
        machine_account => undef,
        dhcp6_enterprise => undef,
        dhcp6_fingerprint => undef,
        mac => '',
        device_score => undef,
        last_arp => '0000-00-00 00:00:00',
        lastskip => '0000-00-00 00:00:00',
        last_dhcp => '0000-00-00 00:00:00',
        user_agent => undef,
        dhcp_fingerprint => undef,
        computername => undef,
        detect_date => '0000-00-00 00:00:00',
        voip => 'no',
        bypass_role_id => undef,
        notes => undef,
        time_balance => undef,
        sessionid => undef,
        dhcp_vendor => undef,
        unregdate => '0000-00-00 00:00:00',
    );

    @INSERTABLE_FIELDS = qw(
        autoreg
        device_version
        status
        bypass_vlan
        device_class
        bandwidth_balance
        regdate
        category_id
        device_type
        pid
        machine_account
        dhcp6_enterprise
        dhcp6_fingerprint
        mac
        device_score
        last_arp
        lastskip
        last_dhcp
        user_agent
        dhcp_fingerprint
        computername
        detect_date
        voip
        bypass_role_id
        notes
        time_balance
        sessionid
        dhcp_vendor
        unregdate
    );

    %FIELDS_META = (
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
        device_version => {
            type => 'VARCHAR',
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
        bypass_vlan => {
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
        bandwidth_balance => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        regdate => {
            type => 'DATETIME',
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
        device_type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        pid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        machine_account => {
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
        dhcp6_fingerprint => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        mac => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        device_score => {
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
        lastskip => {
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
        user_agent => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        dhcp_fingerprint => {
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
        detect_date => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
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
        bypass_role_id => {
            type => 'INT',
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
        time_balance => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        sessionid => {
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
        unregdate => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
    );

    @PRIMARY_KEYS = qw(
        mac
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
