package pfappserver::Form::SavedSearch;

=head1 NAME

pfappserver::Form::SavedSearch

=cut

=head1 DESCRIPTION

Form for SavedSearch data

=cut

use HTML::FormHandler::Moose;

extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

=head1 Fields

=cut

=head2 name

=cut

has_field 'name'  => (
   type  => 'Text',
   label => 'Name',
   tags  => { after_element => \&help,
             help => 'Your saved search will appear in the menu on the left side of your screen.'
    },
);

=head2 query

=cut

has_field 'query' => (
   type => 'Hidden',
);

=head2 pid

=cut

has_field 'pid' => (
   type => 'Text',
   widget => 'NoRender',
);

=head2 namespace

=cut

has_field 'namespace' => (
   type => 'Text',
   widget => 'NoRender',
);

=head1 Blocks

=head2 search

=cut

has_block 'search' =>
  (
   render_list => [qw(name query)],
  );


=cut

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};



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

