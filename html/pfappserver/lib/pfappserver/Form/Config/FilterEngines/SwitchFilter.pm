package pfappserver::Form::Config::FilterEngines::SwitchFilter;

=head1 NAME

pfappserver::Form::Config::FilterEngines::SwitchFilter -

=head1 DESCRIPTION

pfappserver::Form::Config::FilterEngines::SwitchFilter

=cut

use strict;
use warnings;
use pfappserver::Form::Field::DynamicList;
use HTML::FormHandler::Moose;
use pf::constants::role qw(@ROLES);
use pf::SwitchFactory;
extends 'pfappserver::Form::Config::FilterEngines';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Base::Form::Role::AllowedOptions
    pfappserver::Role::Form::RolesAttribute
);

sub scopes {
    return map { { value => $_, label => $_ } } qw(radius_request locationlog instantiate_module radius_authorize reevaluate external_portal);
}

has_field switch => (
    type => 'Select',
    options_method => \&options_switch,
);

sub options_switch {
    return pf::SwitchFactory::form_options();
}

has_field log => (
    type => 'Text',
);

=head2 params

The list of params

=cut

has_field 'params' => (
    'type' => 'DynamicList',
);

=head2 actions.contains

The definition for the list of actions

=cut

has_field 'params.contains' => (
    type  => 'SwitchParam',
    label => 'Param',
    pfappserver::Form::Field::DynamicList::child_options(),
);

my %ADDITIONAL_FIELD_OPTIONS = (
    %pfappserver::Form::Config::FilterEngines::ADDITIONAL_FIELD_OPTIONS
);

sub _additional_field_options {
    return \%ADDITIONAL_FIELD_OPTIONS;
}

sub options_field_names {
    qw(
      node_info.autoreg
      node_info.status
      node_info.bypass_vlan
      node_info.bandwidth_balance
      node_info.regdate
      node_info.bypass_role
      node_info.device_class
      node_info.device_type
      node_info.device_version
      node_info.device_score
      node_info.pid
      node_info.machine_account
      node_info.category
      node_info.mac
      node_info.last_arp
      node_info.lastskip
      node_info.last_dhcp
      node_info.user_agent
      node_info.computername
      node_info.dhcp_fingerprint
      node_info.detect_date
      node_info.voip
      node_info.notes
      node_info.time_balance
      node_info.sessionid
      node_info.dhcp_vendor
      node_info.unregdate
      fingerbank_info.device_fq
      fingerbank_info.device_hierarchy_names
      fingerbank_info.device_hierarchy_ids
      fingerbank_info.score
      fingerbank_info.version
      fingerbank_info.mobile
      switch._switchIp
      switch._ip
      switch._portalURL
      switch._switchMac
      switch._ip
      ifIndex
      mac
      connection_type
      user_name
      ssid
      time
      owner.pid
      owner.firstname
      owner.lastname
      owner.email
      owner.telephone
      owner.company
      owner.address
      owner.notes
      owner.sponsor
      owner.anniversary
      owner.birthday
      owner.gender
      owner.lang
      owner.nickname
      owner.cell_phone
      owner.work_phone
      owner.title
      owner.building_number
      owner.apartment_number
      owner.room_number
      owner.custom_field_1
      owner.custom_field_2
      owner.custom_field_3
      owner.custom_field_4
      owner.custom_field_5
      owner.custom_field_6
      owner.custom_field_7
      owner.custom_field_8
      owner.custom_field_9
      owner.portal
      owner.source
      owner.nodes
      owner.password
      owner.valid_from
      owner.expiration
      owner.access_duration
      owner.access_level
      owner.can_sponsor
      owner.unregdate
      owner.category
      radius_request
    );
}
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
