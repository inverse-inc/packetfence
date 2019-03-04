package pfappserver::Base::Form::Role::MultiSource;

=head1 NAME

pfappserver::Base::Form::Role::MultiSource

=head1 DESCRIPTION

Role for MultiSource portal modules

=cut

use HTML::FormHandler::Moose::Role;
with 'pfappserver::Base::Form::Role::Help';

has_field 'multi_source_object_classes' =>
  (
   type => 'TextArea',
   label => 'Sources by Class',
   element_class => ['input-xxlarge'],
   required => 0,
   tags => { after_element => \&help,
             help => 'The sources inheriting from these classes and part of the connection profile will be added to the available sources' },
  );

has_field 'multi_source_types' => 
  (
   type => 'TextArea',
   element_class => ['input-xxlarge'],
   label => 'Sources by type',
   required => 0,
   tags => { after_element => \&help,
             help => 'The sources of these types and part of the connection profile will be added to the available sources' },
  );

has_field 'multi_source_auth_classes' => 
  (
   type => 'TextArea',
   label => 'Sources by Auth Class',
   element_class => ['input-xxlarge'],
   required => 0,
   tags => { after_element => \&help,
             help => 'The sources of these authentication classes and part of the connection profile will be added to the available sources' },
  );

has_block 'multi_source_definition' => (
    render_list => [qw(multi_source_object_classes multi_source_types multi_source_auth_classes)],
);


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

