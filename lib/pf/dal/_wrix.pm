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
our @COLUMN_NAMES;

BEGIN {
    @FIELD_NAMES = qw(
        id
        Provider_Identifier
        Location_Identifier
        Service_Provider_Brand
        Location_Type
        Sub_Location_Type
        English_Location_Name
        Location_Address1
        Location_Address2
        English_Location_City
        Location_Zip_Postal_Code
        Location_State_Province_Name
        Location_Country_Name
        Location_Phone_Number
        SSID_Open_Auth
        SSID_Broadcasted
        WEP_Key
        WEP_Key_Entry_Method
        WEP_Key_Size
        SSID_1X
        SSID_1X_Broadcasted
        Security_Protocol_1X
        Client_Support
        Restricted_Access
        Location_URL
        Coverage_Area
        Open_Monday
        Open_Tuesday
        Open_Wednesday
        Open_Thursday
        Open_Friday
        Open_Saturday
        Open_Sunday
        Longitude
        Latitude
        UTC_Timezone
        MAC_Address
    );

    %DEFAULTS = (
        id => '',
        Provider_Identifier => undef,
        Location_Identifier => undef,
        Service_Provider_Brand => undef,
        Location_Type => undef,
        Sub_Location_Type => undef,
        English_Location_Name => undef,
        Location_Address1 => undef,
        Location_Address2 => undef,
        English_Location_City => undef,
        Location_Zip_Postal_Code => undef,
        Location_State_Province_Name => undef,
        Location_Country_Name => undef,
        Location_Phone_Number => undef,
        SSID_Open_Auth => undef,
        SSID_Broadcasted => undef,
        WEP_Key => undef,
        WEP_Key_Entry_Method => undef,
        WEP_Key_Size => undef,
        SSID_1X => undef,
        SSID_1X_Broadcasted => undef,
        Security_Protocol_1X => undef,
        Client_Support => undef,
        Restricted_Access => undef,
        Location_URL => undef,
        Coverage_Area => undef,
        Open_Monday => undef,
        Open_Tuesday => undef,
        Open_Wednesday => undef,
        Open_Thursday => undef,
        Open_Friday => undef,
        Open_Saturday => undef,
        Open_Sunday => undef,
        Longitude => undef,
        Latitude => undef,
        UTC_Timezone => undef,
        MAC_Address => undef,
    );

    @INSERTABLE_FIELDS = qw(
        id
        Provider_Identifier
        Location_Identifier
        Service_Provider_Brand
        Location_Type
        Sub_Location_Type
        English_Location_Name
        Location_Address1
        Location_Address2
        English_Location_City
        Location_Zip_Postal_Code
        Location_State_Province_Name
        Location_Country_Name
        Location_Phone_Number
        SSID_Open_Auth
        SSID_Broadcasted
        WEP_Key
        WEP_Key_Entry_Method
        WEP_Key_Size
        SSID_1X
        SSID_1X_Broadcasted
        Security_Protocol_1X
        Client_Support
        Restricted_Access
        Location_URL
        Coverage_Area
        Open_Monday
        Open_Tuesday
        Open_Wednesday
        Open_Thursday
        Open_Friday
        Open_Saturday
        Open_Sunday
        Longitude
        Latitude
        UTC_Timezone
        MAC_Address
    );

    %FIELDS_META = (
        id => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        Provider_Identifier => {
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
        Service_Provider_Brand => {
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
        Sub_Location_Type => {
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
        Location_Address1 => {
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
        English_Location_City => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Location_Zip_Postal_Code => {
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
        Location_Country_Name => {
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
        SSID_Open_Auth => {
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
        WEP_Key => {
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
        WEP_Key_Size => {
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
        SSID_1X_Broadcasted => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        Security_Protocol_1X => {
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
        Restricted_Access => {
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
        Coverage_Area => {
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
        Open_Tuesday => {
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
        Open_Thursday => {
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
        Open_Saturday => {
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
        Longitude => {
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
        UTC_Timezone => {
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
    );

    @PRIMARY_KEYS = qw(
        id
    );

    @COLUMN_NAMES = qw(
        wrix.id
        wrix.Provider_Identifier
        wrix.Location_Identifier
        wrix.Service_Provider_Brand
        wrix.Location_Type
        wrix.Sub_Location_Type
        wrix.English_Location_Name
        wrix.Location_Address1
        wrix.Location_Address2
        wrix.English_Location_City
        wrix.Location_Zip_Postal_Code
        wrix.Location_State_Province_Name
        wrix.Location_Country_Name
        wrix.Location_Phone_Number
        wrix.SSID_Open_Auth
        wrix.SSID_Broadcasted
        wrix.WEP_Key
        wrix.WEP_Key_Entry_Method
        wrix.WEP_Key_Size
        wrix.SSID_1X
        wrix.SSID_1X_Broadcasted
        wrix.Security_Protocol_1X
        wrix.Client_Support
        wrix.Restricted_Access
        wrix.Location_URL
        wrix.Coverage_Area
        wrix.Open_Monday
        wrix.Open_Tuesday
        wrix.Open_Wednesday
        wrix.Open_Thursday
        wrix.Open_Friday
        wrix.Open_Saturday
        wrix.Open_Sunday
        wrix.Longitude
        wrix.Latitude
        wrix.UTC_Timezone
        wrix.MAC_Address
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

=head2 table_field_names

Field names of wrix

=cut

sub table_field_names {
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

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

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

=head2 _insertable_fields

The insertable fields for wrix

=cut

sub _insertable_fields {
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
