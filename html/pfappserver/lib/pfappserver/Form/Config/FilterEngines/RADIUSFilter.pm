package pfappserver::Form::Config::FilterEngines::RADIUSFilter;

=head1 NAME

pfappserver::Form::Config::FilterEngines::RADIUSFilter -

=head1 DESCRIPTION

pfappserver::Form::Config::FilterEngines::RADIUSFilter

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
    return map { { value => $_, label => $_ } } qw(
      returnRadiusAccessAccept returnAuthorizeRead returnAuthorizeWrite returnAuthorizeVoip
      packetfence.authorize packetfence.authenticate packetfence.pre-proxy packetfence.post-proxy
      packetfence-tunnel.authorize packetfence.preacct packetfence.accounting
    );
}

has_field radius_status => (
    type    => 'Select',
    options => [
        map { { label => $_, values => $_ } }
          qw(
          RLM_MODULE_REJECT
          RLM_MODULE_FAIL
          RLM_MODULE_OK
          RLM_MODULE_HANDLED
          RLM_MODULE_INVALID
          RLM_MODULE_USERLOCK
          RLM_MODULE_NOTFOUND
          RLM_MODULE_NOOP
          RLM_MODULE_UPDATED
          RLM_MODULE_NUMCODES
          )
    ],
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
    type  => 'RadiusAttribute',
    label => 'Answer',
    pfappserver::Form::Field::DynamicList::child_options(),
);

has_field merge_answer => (
    type            => 'Toggle',
    checkbox_value  => 'yes',
    unchecked_value => 'no',
);

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
