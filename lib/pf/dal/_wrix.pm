package pf::dal::_wrix;

=head1 NAME

pf::dal::_wrix -

=cut

=head1 DESCRIPTION

pf::dal::_wrix -

=cut

use strict;
use warnings;

use base qw(pf::dal);

our @FIELD_NAMES;
our @PRIMARY_KEYS;

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

    @PRIMARY_KEYS = qw(
        id
    );
}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,

    true => [qw(has_primary_key)],

};

sub field_names {
    return [@FIELD_NAMES];
}

sub table { "wrix" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM wrix WHERE $where;";
};

sub _find_one_sql {
    return $FIND_SQL;
}

our $UPDATE_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    my $set = join(", ", map { "$_ = ?" } @FIELD_NAMES);
    "UPDATE wrix SET $set WHERE $where;";
};

sub _update_sql {
    return $UPDATE_SQL;
}

sub _update_data {
    my ($self) = @_;
    my %data;
    @data{@FIELD_NAMES} = @{$self}{@FIELD_NAMES};
    return \%data;
}

sub _update_fields {
    return [@FIELD_NAMES, @PRIMARY_KEYS];
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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
