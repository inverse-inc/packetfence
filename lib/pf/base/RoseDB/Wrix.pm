package pf::base::RoseDB::Wrix;

=head1 NAME

pf::base::RoseDB::Wrix add documentation

=cut

=head1 DESCRIPTION

pf::base::RoseDB::Wrix

=cut


use strict;

use base qw(pf::base::RoseDB::Object);

__PACKAGE__->meta->setup(
    table   => 'wrix',

    columns => [
        id                           => { type => 'varchar', length => 255, not_null => 1 },
        Provider_Identifier          => { type => 'varchar', length => 255 },
        Location_Identifier          => { type => 'varchar', length => 255 },
        Service_Provider_Brand       => { type => 'varchar', length => 255 },
        Location_Type                => { type => 'varchar', length => 255 },
        Sub_Location_Type            => { type => 'varchar', length => 255 },
        English_Location_Name        => { type => 'varchar', length => 255 },
        Location_Address1            => { type => 'varchar', length => 255 },
        Location_Address2            => { type => 'varchar', length => 255 },
        English_Location_City        => { type => 'varchar', length => 255 },
        Location_Zip_Postal_Code     => { type => 'varchar', length => 255 },
        Location_State_Province_Name => { type => 'varchar', length => 255 },
        Location_Country_Name        => { type => 'varchar', length => 255 },
        Location_Phone_Number        => { type => 'varchar', length => 255 },
        SSID_Open_Auth               => { type => 'varchar', length => 255 },
        SSID_Broadcasted             => { type => 'varchar', length => 255 },
        WEP_Key                      => { type => 'varchar', length => 255 },
        WEP_Key_Entry_Method         => { type => 'varchar', length => 255 },
        WEP_Key_Size                 => { type => 'varchar', length => 255 },
        SSID_1X                      => { type => 'varchar', length => 255 },
        SSID_1X_Broadcasted          => { type => 'varchar', length => 255 },
        Security_Protocol_1X         => { type => 'varchar', length => 255 },
        Client_Support               => { type => 'varchar', length => 255 },
        Restricted_Access            => { type => 'varchar', length => 255 },
        Location_URL                 => { type => 'varchar', length => 255 },
        Coverage_Area                => { type => 'varchar', length => 255 },
        Open_Monday                  => { type => 'varchar', length => 255 },
        Open_Tuesday                 => { type => 'varchar', length => 255 },
        Open_Wednesday               => { type => 'varchar', length => 255 },
        Open_Thursday                => { type => 'varchar', length => 255 },
        Open_Friday                  => { type => 'varchar', length => 255 },
        Open_Saturday                => { type => 'varchar', length => 255 },
        Open_Sunday                  => { type => 'varchar', length => 255 },
        Longitude                    => { type => 'varchar', length => 255 },
        Latitude                     => { type => 'varchar', length => 255 },
        UTC_Timezone                 => { type => 'varchar', length => 255 },
        MAC_Address                  => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'id' ],
);

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
