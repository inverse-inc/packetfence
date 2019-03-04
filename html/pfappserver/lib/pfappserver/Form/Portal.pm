package pfappserver::Form::Portal;

=head1 NAME

pfappserver::Form::Portal - connection profiles

=head1 DESCRIPTION

Sortable list of connection profiles.

=cut

use HTML::FormHandler::Moose;

extends 'pfappserver::Base::Form';


=head2 Form fields

=over

=item items

=cut

has_field 'items' =>
  (
   type => 'Repeatable',
   num_when_empty => 0,
  );

=item items.id

=cut

has_field 'items.id' =>
  (
   type => 'Hidden',
   do_label => 0,
  );

=item items.description

=cut

has_field 'items.description' =>
  (
   type => 'Text',
   do_label => 0,
  );

=item items.status

=cut

has_field 'items.status' =>
  (
   type => 'Text',
   do_label => 0,
  );

=back

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
