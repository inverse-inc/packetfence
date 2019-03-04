package pfappserver::Form::Config::Wrix;

=head1 NAME

pfappserver::Form::Config::Wrix - Web form for a switch

=head1 DESCRIPTION

Form definition to create or update a network switch.

=cut

use HTML::FormHandler::Moose;
use DateTime::TimeZone;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

## Definition
has_field 'id' =>
  (
   type => 'Text',
   required => 1,
   messages => { required => 'The ID of the Switch'}
  );
has_field 'Provider_Identifier' =>
  (
   type => 'Text',
   required => 1,
  );
has_field 'Location_Identifier' =>
  (
   type => 'Text',
   required => 1,
  );
has_field 'Service_Provider_Brand' =>
  (
   type => 'Text',
   required => 1,
  );
has_block 'identification' =>
  (
    render_list => [qw(Provider_Identifier Location_Identifier Service_Provider_Brand)]
  );
has_field 'Location_Type' =>
  (
   type => 'Text',
   required => 1,
  );
has_field 'Sub_Location_Type' =>
  (
   type => 'Text',
   required => 1,
  );
has_field 'English_Location_Name' =>
  (
   type => 'Text',
   required => 1,
  );
has_field 'Location_Address1' =>
  (
   type => 'Text',
   required => 1,
   label => 'Location Address 1'
  );

has_field 'Location_Address2' =>
  (
   type => 'Text',
   label => 'Location Address 2'
  );
has_field 'English_Location_City' =>
  (
   type => 'Text',
   required => 1,
  );
has_field 'Location_Zip_Postal_Code' =>
  (
   type => 'Text',
   required => 1,
  );
has_field 'Location_State_Province_Name' =>
  (
   type => 'Text',
   required => 1,
  );
has_field 'Location_Country_Name' =>
  (
   type => 'Text',
   required => 1,
  );
has_field 'Location_Phone_Number' =>
  (
   type => 'Text',
   required => 1,
  );
has_block 'location'  =>
  (
    render_list => [qw(
        Location_Type Sub_Location_Type English_Location_Name Location_Address1
        Location_Address2 English_Location_City Location_Zip_Postal_Code
        Location_State_Province_Name Location_Country_Name Location_Phone_Number  Location_URL Coverage_Area
    )]
  );

has_field 'SSID_Open_Auth' =>
  (
   type => 'Text',
  );
has_field 'SSID_Broadcasted' =>
  (
   type => 'Toggle',
  );
has_field 'WEP_Key' =>
  (
   type => 'Text',
  );
has_field 'WEP_Key_Entry_Method' =>
  (
   type => 'Text',
  );
has_field 'WEP_Key_Size' =>
  (
   type => 'Text',
  );
has_field 'SSID_1X' =>
  (
   type => 'Text',
  );
has_field 'SSID_1X_Broadcasted' =>
  (
   type => 'Toggle',
  );
has_field 'Security_Protocol_1X' =>
  (
    type => 'Select',
    default => 'NONE',
    options => [
      { value => 'NONE', label => 'None' },
      { value => 'WPA-Enterprise', label => 'WPA Enterprise' },
      { value => 'WPA2', label => 'WPA2' },
      { value => 'EAP-PEAP', label => 'EAP PEAP' },
      { value => 'EAP-TTLS', label => 'EAP TTLS' },
      { value => 'EAP_SIM', label => 'EAP SIM' },
      { value => 'EAP-AKA', label => 'EAP AKA' },
    ],
  );
 has_field 'Client_Support' =>
  (
    type => 'Text',
  );
 has_field 'Restricted_Access' =>
  (
    type => 'Toggle',
  );

 has_block 'ssid' =>
  (
    render_list => [qw(
      SSID_Open_Auth SSID_Broadcasted WEP_Key WEP_Key_Entry_Method
      WEP_Key_Size SSID_1X SSID_1X_Broadcasted Security_Protocol_1X
      Restricted_Access Client_Support MAC_Address
    )],
  );

 has_field 'Location_URL' =>
  (
    type => 'Text',
  );
 has_field 'Coverage_Area' =>
  (
    type => 'Text',
  );
 our @HOURS = qw(Open_Monday Open_Tuesday Open_Wednesday Open_Thursday Open_Friday Open_Saturday Open_Sunday);
 has_field \@HOURS =>
  (
    type => 'Text',
    maxlength => 13,
  );
  has_block hours =>
  (
    render_list => ['UTC_Timezone', @HOURS]
  );
 has_field 'Longitude' =>
  (
    type => 'Float',
    size   => 11,
    precision   => 9,
    range_start => -180,
    range_end   => 180,
  );
 has_field 'Latitude' =>
  (
    type => 'Float',
    size   => 11,
    precision   => 9,
    range_start => -90,
    range_end   => 90,
  );
  has_block lat_long =>
  (
    render_list => [qw( Longitude Latitude  )]
  );
 has_field 'UTC_Timezone' =>
  (
    type => 'Select',
    options_method => \&options_UTC_Timezone,
  );
 has_field 'MAC_Address' =>
  (
    type => 'Text',
  );

sub options_UTC_Timezone {
    my ($self) =  @_;
    local $_;
    my @options = map {
        {   group   => $self->_localize($_),
            options => options_UTC_Timezone_group($self, $_),
            value => '',
        }
    } DateTime::TimeZone->categories;
    unshift @options, { value => '', label => ''  };
    return \@options;
}

sub options_UTC_Timezone_group {
    my ($self,$category) = @_;
    local $_;
    return [ (map { { value => "$category/$_", label => $_ } } DateTime::TimeZone->names_in_category($category)) ];
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
