package pfappserver::Form::Config::Profile;

=head1 NAME

pfappserver::Form::Config::Profile

=head1 DESCRIPTION

Connection profile.

=cut

use pf::authentication;

use HTML::FormHandler::Moose;
use pfappserver::Form::Field::ProfileFilter;
extends 'pfappserver::Base::Form';
with 'pfappserver::Form::Config::ProfileCommon';

use pf::config;
use List::MoreUtils qw(uniq);

=head1 FIELDS

=head2 filter

The filter container field

=cut

has_field 'filter' =>
  (
   type => 'DynamicTable',
   label => 'Filters',
   'do_label' => 0,
   'sortable' => 1,
  );

=head2 filter.conatains

The filter container field contents

=cut

has_field 'filter.contains' =>
  (
   type => '+ProfileFilter',
   widget_wrapper => 'DynamicTableRow',
  );

=head2 filter_match_style

The form field for filter_match_style
Field defining how the configured filters will be applied for matching

=cut

has_field 'filter_match_style' =>
(
    type => 'Select',
    default => 'any',
    options_method => \&options_filter_match_style,
    element_class => ['input-mini'],
);

sub options_filter_match_style {
    return  map { { value => $_, label => $_ } } qw(all any);
}

has_field 'advanced_filter' => 
(
    type => 'TextArea',
);

=head1 METHODS

=head2 update_fields

Don't allow to edit the profile id when editing an existing profile.

=cut

sub update_fields {
    my $self = shift;
    my $init_object = $self->init_object;

    $self->field('id')->readonly(1) if (defined $init_object && defined $init_object->{id});

    # Call the theme implementation of the method
    $self->SUPER::update_fields();
}

=head2 validate

=cut

sub validate {
    my ($self) = @_;
    my $value = $self->value;
    if (@{$value->{filter}} == 0 && !exists $value->{advanced_filter} ) {
        $self->field('filter')->add_error("A filter or an advanced filter must be specified");
        $self->field('advanced_filter')->add_error("A filter or an advanced filter must be specified");
    }
    return 1;
}


=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
