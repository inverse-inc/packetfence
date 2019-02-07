package pfappserver::Form::RadiusLogSearch;

=head1 NAME

pfappserver::Form::Node - Web form for a node
pfappserver::Form::Search::Node - Web form for searching Nodes

=head1 DESCRIPTION

Form definition to create or update a node.

=cut

use HTML::FormHandler::Moose;
use pf::log;
use List::MoreUtils qw(true);
extends 'pfappserver::Base::Form';

=head2 Form Fields

=over

=item start

=cut

has_field 'start' => (
    type => 'Compound',
);

=item start.date

=cut

has_field 'start.date' =>
  (
   type => 'DatePicker',
   label => 'Start Date',
   required => 1,
  );

=item start.time

=cut

has_field 'start.time' =>
  (
   type => 'TimePicker',
   label => 'Start Time',
   required => 1,
  );

=item end

=cut

has_field 'end' =>
  (
   type => 'Compound',
  );

=item end.date

=cut

has_field 'end.date' =>
  (
   type => 'DatePicker',
   label => 'End Date',
   required => 1,
  );

=item end.time

=cut

has_field 'end.time' =>
  (
   type => 'TimePicker',
   label => 'End Time',
  );

=item per_page

=cut

has_field 'per_page' =>
  (
   type => 'Hidden',
   default => '1',
  );


=item page_num

=cut

has_field 'page_num' =>
  (
   type => 'Hidden',
   default => '1',
  );

=item by

=cut

has_field 'by' =>
  (
   type => 'Hidden',
  );

=item direction

=cut

has_field 'direction' =>
  (
   type => 'Hidden',
   default => 'asc',
  );

=item all_or_any

=cut

has_field 'all_or_any' =>
  (
   type => 'Select',
   options => [
    { value => 'all', label => 'All' },
    { value => 'any', label => 'Any' },
   ]
  );


=item search

=cut

has_field 'searches' =>
  (
   type => 'Repeatable',
   num_when_empty => 0,
  );

=item searches.name

=cut

has_field 'searches.name' =>
  (
   type => 'Text',
   do_label => 0,
  );

=item searches.op

=cut

has_field 'searches.op' =>
  (
   type => 'Text',
   do_label => 0,
  );

=item searches.value

=cut

has_field 'searches.value' =>
  (
   type => 'Text',
   do_label => 0,
  );

sub validate {
    my ($self) = @_;
    $self->SUPER::validate();
    my $value = $self->value;
    my $searches = $value->{searches} || [];
    if (true {defined $_->{value}} @$searches) {
        $self->field('start')->add_error("Start date not provided") unless defined $value->{start};
    }
}

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
