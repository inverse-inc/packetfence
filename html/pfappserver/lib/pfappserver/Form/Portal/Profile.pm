package pfappserver::Form::Portal::Profile;

=head1 NAME

pfappserver::Form::Portal::Profile

=head1 DESCRIPTION

Portal profile.

=cut

use pf::authentication;

use HTML::FormHandler::Moose;
use pfappserver::Form::Field::ProfileFilter;
extends 'pfappserver::Base::Form';

use pf::config;
use List::MoreUtils qw(uniq);

# Form fields
sub build_do_form_wrapper {0}
has_field 'id' =>
  (
   type => 'Text',
   label => 'Profile Name',
   required => 1,
   apply => [ { check => qr/^[a-zA-Z0-9][a-zA-Z0-9\._-]*$/ } ],
  );
has_field 'description' =>
  (
   type => 'Text',
   label => 'Profile Description',
   required => 1,
  );
has_field 'billing_engine' =>
  (
   type => 'Toggle',
   label => 'Enable Billing Engine',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
  );
has_field 'filter' =>
  (
   type => 'DynamicTable',
   'num_when_empty' => 2,
   'label' => 'Filters',
   inflate_default_method => sub {
       [
        map { pfappserver::Form::Field::ProfileFilter->filter_inflate($_) }
        @{$_[1]}
       ]
   }
  );
has_field 'filter.contains' =>
  (
   type => '+ProfileFilter',
   label => 'Filter',
   widget_wrapper => 'DynamicTableRow',
  );
has_field 'sources' =>
  (
   'type' => 'DynamicTable',
   'sortable' => 1,
   'label' => 'Sources',
  );
has_field 'sources.contains' =>
  (
   type => 'Select',
   label => 'Source',
   options_method => \&options_sources,
   widget_wrapper => 'DynamicTableRow',
  );

=head1 METHODS

=head2 options_sources

=cut

sub options_sources {
    return map { { value => $_->id, label => $_->id } } @{getAuthenticationSource()};
}


=head2 validate

Remove duplicates and make sure only one external authentication source is selected for each type.

=cut

sub validate {
    my $self = shift;

    my @all = uniq @{$self->value->{'sources'}};
    $self->field('sources')->value(\@all);
    my %external;
    foreach my $source_id (@all) {
        my $source = &pf::authentication::getAuthenticationSource($source_id);
        $external{$source->{'type'}} = 0 unless (defined $external{$source->{'type'}});
        $external{$source->{'type'}}++;
        if ($external{$source->{'type'}} > 1) {
            $self->field('sources')->add_error('Only one authentication source of each external type can be selected.');
            last;
        }
    }
}

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
