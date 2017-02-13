package pf::dal::_wrix;

=head1 NAME

pf::dal::_wrix - pf::dal implementation for the table wrix

=cut

=head1 DESCRIPTION

pf::dal::_wrix

pf::dal implementation for the table wrix

=cut

use strict;
use warnings;

###
### pf::dal::_wrix is auto generated any change to this file will be lost
### Instead change in the pf::dal::wrix module
###
use base qw(pf::dal);

our @FIELD_NAMES;
our @INSERTABLE_FIELDS;
our @PRIMARY_KEYS;
our %DEFAULTS;
our %FIELDS_META;

BEGIN {
    @FIELD_NAMES = qw(
        Location_Zip_Postal_Code
        SSID_1X
        Open_Sunday
        Client_Support
        Coverage_Area
        Location_Identifier
        Open_Tuesday
        Open_Monday
        English_Location_City
        id
        Security_Protocol_1X
        WEP_Key_Entry_Method
        Location_Type
        Location_Phone_Number
        Restricted_Access
        Open_Thursday
        Latitude
        Open_Friday
        Service_Provider_Brand
        Provider_Identifier
        Location_URL
        Sub_Location_Type
        Longitude
        MAC_Address
        Location_Address2
        SSID_1X_Broadcasted
        English_Location_Name
        Location_State_Province_Name
        UTC_Timezone
        Location_Address1
        SSID_Broadcasted
        Open_Saturday
        Open_Wednesday
        WEP_Key_Size
        SSID_Open_Auth
        Location_Country_Name
        WEP_Key
    );

    %DEFAULTS = (
        Location_Zip_Postal_Code => undef,
        SSID_1X => undef,
        Open_Sunday => undef,
        Client_Support => undef,
        Coverage_Area => undef,
        Location_Identifier => undef,
        Open_Tuesday => undef,
        Open_Monday => undef,
        English_Location_City => undef,
        id => '',
        Security_Protocol_1X => undef,
        WEP_Key_Entry_Method => undef,
        Location_Type => undef,
        Location_Phone_Number => undef,
        Restricted_Access => undef,
        Open_Thursday => undef,
        Latitude => undef,
        Open_Friday => undef,
        Service_Provider_Brand => undef,
        Provider_Identifier => undef,
        Location_URL => undef,
        Sub_Location_Type => undef,
        Longitude => undef,
        MAC_Address => undef,
        Location_Address2 => undef,
        SSID_1X_Broadcasted => undef,
        English_Location_Name => undef,
        Location_State_Province_Name => undef,
        UTC_Timezone => undef,
        Location_Address1 => undef,
        SSID_Broadcasted => undef,
        Open_Saturday => undef,
        Open_Wednesday => undef,
        WEP_Key_Size => undef,
        SSID_Open_Auth => undef,
        Location_Country_Name => undef,
        WEP_Key => undef,
    );

    @INSERTABLE_FIELDS = qw(
        Location_Zip_Postal_Code
        SSID_1X
        Open_Sunday
        Client_Support
        Coverage_Area
        Location_Identifier
        Open_Tuesday
        Open_Monday
        English_Location_City
        id
        Security_Protocol_1X
        WEP_Key_Entry_Method
        Location_Type
        Location_Phone_Number
        Restricted_Access
        Open_Thursday
        Latitude
        Open_Friday
        Service_Provider_Brand
        Provider_Identifier
        Location_URL
        Sub_Location_Type
        Longitude
        MAC_Address
        Location_Address2
        SSID_1X_Broadcasted
        English_Location_Name
        Location_State_Province_Name
        UTC_Timezone
        Location_Address1
        SSID_Broadcasted
        Open_Saturday
        Open_Wednesday
        WEP_Key_Size
        SSID_Open_Auth
        Location_Country_Name
        WEP_Key
    );

    %FIELDS_META = (
        Location_Zip_Postal_Code => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        SSID_1X => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Open_Sunday => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Client_Support => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Coverage_Area => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Location_Identifier => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Open_Tuesday => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Open_Monday => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        English_Location_City => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        id => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        Security_Protocol_1X => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        WEP_Key_Entry_Method => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Location_Type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Location_Phone_Number => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Restricted_Access => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Open_Thursday => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Latitude => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Open_Friday => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Service_Provider_Brand => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Provider_Identifier => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Location_URL => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Sub_Location_Type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Longitude => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        MAC_Address => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Location_Address2 => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        SSID_1X_Broadcasted => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        English_Location_Name => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Location_State_Province_Name => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        UTC_Timezone => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Location_Address1 => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        SSID_Broadcasted => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Open_Saturday => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Open_Wednesday => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        WEP_Key_Size => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        SSID_Open_Auth => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Location_Country_Name => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        WEP_Key => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        id
    );
}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of wrix

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of wrix

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of wrix

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "wrix" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `wrix` WHERE $where;";
};

=head2 _find_one_sql

The precalculated sql to find a single row wrix

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for wrix

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _inserteable_fields

The inserteable fields for wrix

=cut

sub _inserteable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for wrix

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
