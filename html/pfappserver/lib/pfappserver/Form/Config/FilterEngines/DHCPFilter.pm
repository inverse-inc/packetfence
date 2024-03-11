package pfappserver::Form::Config::FilterEngines::DHCPFilter;

=head1 NAME

pfappserver::Form::Config::FilterEngines::DHCPFilter -

=head1 DESCRIPTION

pfappserver::Form::Config::FilterEngines::DHCPFilter

=cut

use strict;
use warnings;
use pfappserver::Form::Field::DynamicList;
use HTML::FormHandler::Moose;
use pf::constants::role qw(@ROLES);
extends 'pfappserver::Form::Config::FilterEngines';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Base::Form::Role::AllowedOptions
    pfappserver::Role::Form::RolesAttribute
);

sub scopes {
    return map { { value => $_, label => $_ } } qw(Discover Request);
}

has_field 'run_actions' => (
   type => 'Toggle',
   label => 'Run Actions',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default => 'enabled'
);

=head2 answers

The list of answers

=cut

has_field 'answers' => (
    'type' => 'DynamicList',
);

=head2 answers.contains

The definition for the list of actions

=cut

has_field 'answers.contains' => (
    type  => 'DHCPAnswer',
    label => 'Answer',
    pfappserver::Form::Field::DynamicList::child_options(),
);

=head2 actions

The list of action

=cut

has_field 'actions' => (
    'type' => 'DynamicList',
);

=head2 actions.contains

The definition for the list of actions

=cut

has_field 'actions.contains' => (
    type  => 'ApiAction',
    label => 'Action',
    pfappserver::Form::Field::DynamicList::child_options(),
);

my %ADDITIONAL_FIELD_OPTIONS = (
    %pfappserver::Form::Config::FilterEngines::ADDITIONAL_FIELD_OPTIONS,
    'options.optionDHCPMessageType' => {
        siblings => {
            value => {
                allowed_values => [
                    { text => 'Discover', value => '1' },
                    { text => 'Request',  value => '3' },
                    { text => 'Decline',  value => '4' },
                    { text => 'Release',  value => '7' },
                    { text => 'Inform',   value => '8' },
                ],
            }
        }
    }
);

sub _additional_field_options {
    return \%ADDITIONAL_FIELD_OPTIONS;
}

sub options_field_names {
    qw(
      options.optionVendorClassIdentifier
      options.optionDHCPMessageType
      options.optionClientIdentifier
      options.optionParameterRequestList
      options.optionMaximumDHCPMessageSize
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
      node_info.last_connection_type
      fingerbank_info.device_name
      fingerbank_info.device_fq
      fingerbank_info.device_hierarchy_names
      fingerbank_info.device_hierarchy_ids
      fingerbank_info.score
      fingerbank_info.version
      fingerbank_info.mobile
      mac
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

