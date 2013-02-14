package pfappserver::Form::Search::Node;

=head1 NAME

pfappserver::Form::Node - Web form for a node
pfappserver::Form::Search::Node - Web form for searching Nodes

=head1 DESCRIPTION

Form definition to create or update a node.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form::Base';

# Form fields
has_field 'start' =>
  (
   type => 'DatePicker',
  );
has_field 'end' =>
  (
   type => 'DatePicker',
  );
has_field 'all_or_any' =>
  (
   type => 'Select',
   options => [
    { value => 'all', label => 'All' },
    { value => 'any', label => 'Any' },
   ]
  );

has_field 'searches' =>
  (
   type => 'Repeatable',
   num_when_empty => 0,
  );
has_field 'searches.name' =>
  (
   type => 'Text',
   do_label => 0,
  );

has_field 'searches.op' =>
  (
   type => 'Text',
   do_label => 0,
  );

has_field 'searches.value' =>
  (
   type => 'Text',
   do_label => 0,
  );



=head2 options_status

=cut

sub options_status {
    my $self = shift;

    # $self->status comes from pfappserver::Model::Node->availableStatus
    my @status = map { $_ => $_ } @{$self->status} if ($self->status);

    return @status;
}

=head2 options_category_id

=cut

sub options_category_id {
    my $self = shift;

    # $self->roles comes from pfappserver::Model::Roles
    my @roles = map { $_->{category_id} => $_->{name} } @{$self->roles} if ($self->roles);

    return ('' => '', @roles);
}

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
