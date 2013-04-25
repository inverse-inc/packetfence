package pfappserver::Form::SavedSearch;
=head1 NAME

pfappserver::Form::SavedSearch

=cut

=head1 DESCRIPTION

Form for SavedSearch data

=cut


use HTML::FormHandler::Moose;
use namespace::autoclean;

extends 'pfappserver::Base::Form';

=head2 Fields
=cut

=over
=cut

=item name
=cut
has_field 'name'  => (
   type  => 'Text',
   label => 'Name',
   tags  => { after_element => \&help,
             help => 'Your saved search will appear in the menu on the left side of your screen.'
    },
);

=item name
=cut
has_field 'in_dashboard' => (
   type  => 'Toggle',
   label => 'Show in dashboard',
);

=item query
=cut
has_field 'query' => (
   type => 'Hidden',
);

=item pid
=cut
has_field 'pid' => (
   type => 'Text',
   widget => 'NoRender',
);

=item namespace
=cut
has_field 'namespace' => (
   type => 'Text',
   widget => 'NoRender',
);


=back

=cut

__PACKAGE__->meta->make_immutable;



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

1;

