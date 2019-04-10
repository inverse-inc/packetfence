package pfappserver::Base::Form::Role::WithCustomFields;

=head1 NAME

pfappserver::Base::Form::Role::WithCustomFields

=head1 DESCRIPTION

Role for portal modules with custom fields

=cut

use HTML::FormHandler::Moose::Role;
with 'pfappserver::Base::Form::Role::Help';

use pf::person;

## Definition
has_field 'custom_fields' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Mandatory fields',
   value_when_empty => undef,
   options_method => \&options_custom_fields,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a required field'},
   tags => { after_element => \&help,
             help => 'The additionnal fields that should be required for registration' },
  );

has_field 'fields_to_save' =>
  (
   type => 'Select',
   multiple => 1,
   value_when_empty => undef,
   label => 'Fields to save',
   options_method => \&options_custom_fields,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a field'},
   tags => { after_element => \&help,
             help => 'These fields will be saved through the registration process' },
  );

sub options_custom_fields {
    return map { {value => $_ , label => $_ }} @pf::person::PROMPTABLE_FIELDS;
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


