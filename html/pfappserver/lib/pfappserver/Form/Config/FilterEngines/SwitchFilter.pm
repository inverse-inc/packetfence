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
use pf::config qw(%Config);
use pf::constants::filters qw(@BASE_FIELDS @NODE_INFO_FIELDS @FINGERBANK_FIELDS @SWITCH_FIELDS @OWNER_FIELDS @SECURITY_EVENT_FIELDS);
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
    (
        @BASE_FIELDS,
        @NODE_INFO_FIELDS,
        @FINGERBANK_FIELDS,
        @SWITCH_FIELDS,
        @OWNER_FIELDS,
        @SECURITY_EVENT_FIELDS,
        (
           map { "radius_request.$_" } (
               @{$Config{radius_configuration}{radius_attributes} // []}
           )
        )
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
