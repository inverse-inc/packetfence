package pfappserver::Form::Field::Duration;

=head1 NAME

pfappserver::Form::Field::Duration - duration compound

=head1 DESCRIPTION

This is a compound field that requires only one value of the form
  \d[smhDWMY]

The time unit is rendered using the ButtonGroup widget.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use namespace::autoclean;

use pf::config;
use pf::constants::config qw($TIME_MODIFIER_RE);

=head1 ATTRIBUTES

=head2 with_operator (default: disabled)

If this boolean attribute is enabled, an operator select input will be printed with the options
B<add> and B<subtract>.

=cut

has 'with_operator' => (isa => 'Bool', is => 'ro', default => 0);

=head2 with_time (default: enabled)

If this boolean attribute is enabled, the time units will include hours, minutes and seconds.

=cut

has 'with_time' => (isa => 'Bool', is => 'ro', default => 1);

has '+do_wrapper' => ( default => 1 );
has '+do_label' => ( default => 1 );
has '+inflate_default_method'=> ( default => sub { \&duration_inflate } );
has '+deflate_value_method'=> ( default => sub { \&duration_deflate } );
has '+wrapper_class' => (builder => '_wrapper_class');

sub _wrapper_class { [qw(compound-input-btn-group)] }

has_field 'interval' =>
  (
   type => 'PosInteger',
   do_label => 0,
   widget_wrapper => 'None',
   apply => [ { check => qr/^[0-9]+$/ } ],
  );
has_field 'unit' =>
  (
   type => 'Select',
   do_label => 0,
   localize_labels => 1,
   tags => { no_errors => 1 },
   options_method => \&options_unit,
   apply => [ { check => $TIME_MODIFIER_RE } ],
  );

=head1 METHODS

=head2 BUILD

Propagate the 'disabled' attribute to all subfields.

=cut

sub BUILD {
    my ($self) = @_;

    if ($self->element_attr->{"disabled"}) {
        foreach my $subfield ( $self->sorted_fields ) {
            $self->set_disabled($subfield);
        }
    }
}

=head2 field_list

Dynamically build the 'operator' field.

=cut

sub field_list {
    my $self = shift;

    my $list = [];

    if ($self->{with_operator}) {
        my $field =
          {
           name => 'operator',
           order => 1, # place it before all other fields
           type => 'Select',
           do_label => 0,
           widget_wrapper => 'None',
           element_class => ['input-small'],
           options =>
           [
            {value => 'add', label => 'add'},
            {value => 'subtract', label => 'subtract'},
           ],
          };
        push(@$list, $field);
    }

    return $list;
}

=head2 set_disabled

Set the 'disable' attribute of a field.

=cut

sub set_disabled {
    my ($self, $field) = @_;
    if ($field->can("fields")) {
        foreach my $subfield ($field->fields) {
            set_disabled($subfield);
        }
    }
    $field->set_element_attr("disabled" => "disabled");
}

=head2 options_unit

Dynamically define the unit options based on the 'with_time' class attribute.

=cut

sub options_unit {
    my $self = shift;

    my @options;
    if ($self->parent->{with_time}) {
        @options =
          (
           {value => 's', label => 'seconds'},
           {value => 'm', label => 'minutes'},
           {value => 'h', label => 'hours'},
          );
    }
    push(@options,
         {value => 'D', label => 'days'},
         {value => 'W', label => 'weeks'},
         {value => 'M', label => 'months'},
         {value => "Y", label => 'years'},
        );

    return @options;
}

sub duration_inflate {
    my ($self, $value) = @_;

    return {} unless (defined $value && $value =~ m/([+\-])?(\d+)($TIME_MODIFIER_RE)/);
    my $hash = {operator => (defined $1 && $1 eq '-')? 'subtract':'add',
                interval => $2,
                unit => $3};

    return $hash;
}

sub duration_deflate {
    my ($self, $value) = @_;

    my $operator = '';
    my $interval = $value->{interval};
    my $unit = $value->{unit};

    if ($self->{with_operator}) {
        $operator = $value->{operator} eq 'add'? '+' : '-';
    }

    return $operator.$interval.$unit if (defined $interval && defined $unit);
}

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
