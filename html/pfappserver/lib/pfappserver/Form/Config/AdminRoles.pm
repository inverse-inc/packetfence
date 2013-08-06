package pfappserver::Form::Config::AdminRoles;

=head1 NAME

pfappserver::Form::Config::AdminRoles - Web form for a floating device

=head1 DESCRIPTION

Form definition to create or update a floating network device.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::admin_roles;

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Role Name',
   required => 1,
   messages => { required => 'Please specify the name of the admin role.' },
  );
has_field 'actions' =>
  (
   type => 'DynamicTable',
   label => 'Actions',
   'num_when_empty' => 2,
  );
has_field 'actions.contains' =>
  (
   type => 'Select',
   label => 'Actions',
   options_method => \&options_actions,
   widget_wrapper => 'DynamicTableRow',
  );
has_block definition =>
  (
   render_list => [ qw(actions)]
  );
sub build_do_form_wrapper{ 0 }


sub options_actions {
    return map { {label => $_, value => $_} } @ADMIN_ACTIONS;
};

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

__PACKAGE__->meta->make_immutable;
1;
