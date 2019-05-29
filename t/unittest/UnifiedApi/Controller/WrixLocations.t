#!/usr/bin/perl

=head1 NAME

WritxLocations

=cut

=head1 DESCRIPTION

unit test for WritxLocations

=cut

use strict;
use warnings;
use DateTime::Format::Strptime;
use lib '/usr/local/pf/lib';
use pf::dal::wrix;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}
#run tests
use Test::More tests => 92;
use Test::Mojo;
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

#truncate the wrix_location table
pf::dal::wrix->remove_items();

#unittest (empty)
$t->get_ok('/api/v1/wrix_locations' => json => { })
  ->json_is('/items', []) 
  ->status_is(200);

my $mac = "00:01:02:03:04:05";

#insert known data
my %values = (
    "id"                           => "id_$$",
    "Provider_Identifier"          => "Provider_Identifier",
    "Location_Identifier"          => "Location_Identifier",
    "Service_Provider_Brand"       => "Service_Provider_Brand",
    "Location_Type"                => "Location_Type",
    "Sub_Location_Type"            => "Sub_Location_Type",
    "English_Location_Name"        => "English_Location_Name",
    "Location_Address1"            => "Location_Address1",
    "Location_Address2"            => "Location_Address2",
    "English_Location_City"        => "English_Location_City",
    "Location_Zip_Postal_Code"     => "Location_Zip_Postal_Code",
    "Location_State_Province_Name" => "Location_State_Province_Name",
    "Location_Country_Name"        => "Location_Country_Name",
    "Location_Phone_Number"        => "Location_Phone_Number",
    "SSID_Open_Auth"               => "SSID_Open_Auth",
    "SSID_Broadcasted"             => "SSID_Broadcasted",
    "WEP_Key"                      => "WEP_Key",
    "WEP_Key_Entry_Method"         => "WEP_Key_Entry_Method",
    "WEP_Key_Size"                 => "WEP_Key_Size",
    "SSID_1X"                      => "SSID_1X",
    "SSID_1X_Broadcasted"          => "SSID_1X_Broadcasted",
    "Security_Protocol_1X"         => "Security_Protocol_1X",
    "Client_Support"               => "Client_Support",
    "Restricted_Access"            => "Restricted_Access",
    "Location_URL"                 => "Location_URL",
    "Coverage_Area"                => "Coverage_Area",
    "Open_Monday"                  => "Open_Monday",
    "Open_Tuesday"                 => "Open_Tuesday",
    "Open_Wednesday"               => "Open_Wednesday",
    "Open_Thursday"                => "Open_Thursday",
    "Open_Friday"                  => "Open_Friday",
    "Open_Saturday"                => "Open_Saturday",
    "Open_Sunday"                  => "Open_Sunday",
    "Longitude"                    => "Longitude",
    "Latitude"                     => "Latitude",
    "UTC_Timezone"                 => "UTC_Timezone",
    "MAC_Address"                  => "MAC_Address",
);

my $true = bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' );
my $false = bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' );

$t->options_ok('/api/v1/wrix_locations')
  ->status_is(200)
  ->json_is(
    {
        meta => {
            (
                map {
                    $_ => {
                        default     => undef,
                        placeholder => undef,
                        required    => $_ eq 'id' ? $true : $false,
                        type        => 'string',
                      }
                } keys %values
            )
        },
        status => 200,
    }
);

exit;

$t->post_ok('/api/v1/wrix_locations' => json => \%values)
  ->status_is(201);

my $location = $t->tx->res->headers->location();

$t->get_ok('/api/v1/wrix_locations' => json => { })
  ->status_is(200);

while (my ($k, $v) = each %values) {
    $t->json_is("/items/0/$k", $v);
}

#run unittest, use $mac
$t->get_ok($location)
  ->status_is(200);

while (my ($k, $v) = each %values) {
    $t->json_is("/item/$k", $v);
}

#truncate the wrix_location table
#pf::dal::wrix_location->remove_items();
$t->delete_ok($location)
  ->status_is(200);
  
#unittest (empty)
$t->get_ok('/api/v1/wrix_locations' => json => { })
  ->json_is('/items', []) 
  ->status_is(200);

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
