package pfappserver::Form::Portal::Profile::Default;

=head1 NAME

pfappserver::Form::Portal::Profile

=head1 DESCRIPTION

Portal profile.

=cut

use pf::authentication;

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Form::Portal::Common';

# Form fields
has_field 'id' =>
  (
   type => 'Text',
   label => 'Profile Name',
   required => 1,
   readonly => 1,
   apply => [ { check => qr/^[a-zA-Z0-9][a-zA-Z0-9\._-]*$/ } ],
  );
has_field 'description' =>
  (
   type => 'Text',
   label => 'Profile Description',
   required => 1,
   readonly => 1,
  );
has_field 'logo' =>
  (
   type => 'Text',
   label => 'Logo',
   required => 1,
  );
has_field 'billing_engine' =>
  (
   type => 'Toggle',
   label => 'Enable Billing Engine',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
  );
has_block 'definition' =>
  (
   render_list => [ qw(id description logo billing_engine) ],
  );
has_field 'sources' =>
  (
    'type' => 'DynamicTable',
    'sortable' => 1,
    'do_label' => 0,
  );
has_field 'sources.contains' =>
  (
    type => 'Select',
    options_method => \&options_sources,
    widget_wrapper => 'DynamicTableRow',
  );


=head1 METHODS


=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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
