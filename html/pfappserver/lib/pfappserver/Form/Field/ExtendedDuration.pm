package pfappserver::Form::Field::ExtendedDuration;

=head1 NAME

pfappserver::Form::Field::ExtendedDuration - extended duration compound

=head1 DESCRIPTION

This is a compound field that requires only one value of the form
  \d[smhDWMY][RF][+-]\d[DWMY]

The time units are rendered using the ButtonGroup widget.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use namespace::autoclean;

use pf::config;
use pf::constants::config qw($TIME_MODIFIER_RE $DEADLINE_UNIT);

=head1 ATTRIBUTES

=head2 no_value (default: 0)

If this boolean attribute is true, don't return a value to the form.

=cut

has 'no_value' => (isa => 'Bool', is => 'ro', default => 0); # when enabled, don't return a value to the form

has '+do_wrapper' => ( default => 1 );
has '+do_label' => ( default => 1 );
has '+inflate_default_method'=> ( default => sub { \&duration_inflate } );
has '+deflate_value_method'=> ( default => sub { \&duration_deflate } );
has '+widget' => ( default => 'ExtendedDuration' );
has '+wrapper_class' => (builder => '_wrapper_class');

sub _wrapper_class { [qw(compound-input-btn-group)] }

=head1 FIELDS

=cut

has_field 'duration' =>
  (
   type => 'Duration',
   do_label => 0,
   do_wrapper => 0,
   with_time => 1,
  );

has_field 'day_base' =>
  (
   type => 'Toggle',
   label => 'Relative to the beginning of the day',
   do_label => 0,
   do_wrapper => 0,
  );

has_field 'period_base' =>
  (
   type => 'Toggle',
   label => 'Relative to the beginning of the period',
   do_label => 0,
   do_wrapper => 0,
   element_attr => { 'disabled' => 'disabled' },
  );

has_field 'extended_duration' =>
  (
   type => 'Duration',
   label => 'and',
   do_wrapper => 0,
   element_attr => { 'disabled' => 'disabled' },
   with_operator => 1,
   with_time => 0,
  );

has_field 'example' =>
  (
   type => 'Uneditable',
   label => 'Example',
   escape_value => 0,
   do_wrapper => 0,
   label_class => ['text-info'],
   element_class => ['text-info'],
   default => '<span id="extendedFrom">YYYY-MM-DD hh:mm:ss</span> <i class="icon-arrow-right"></i> <strong><span id="extendedTo">YYYY-MM-DD hh:mm:ss</span></strong>',
  );

=head1 METHODS

=cut

sub duration_inflate {
    my ($self, $value) = @_;

    my $hash = {};
    if (defined $value) {
        if ($value =~ /^(\d+$TIME_MODIFIER_RE)($DEADLINE_UNIT)([-+]\d+$TIME_MODIFIER_RE)$/i) {
            $hash = {'duration' => $1,
                     'day_base' => 'Y',
                     'period_base' => ($2 eq 'R')? 'Y':'N',
                     'extended_duration' => $3};
        }
        elsif ($value =~ m/(\d+)($TIME_MODIFIER_RE)/) {
            $hash = {'duration.interval' => $1,
                     'duration.unit' => $2};
        }
    }

    return $hash;
}

sub duration_deflate {
    my ($self, $value) = @_;

    return if ($self->{no_value});

    my $duration = $value->{duration};
    if ($value->{day_base} eq $self->field('day_base')->{checkbox_value}) {
        if ($value->{period_base} eq $self->field('day_base')->{checkbox_value}) {
            $duration .= 'R';
        } else {
            $duration .= 'F';
        }
        if ($value->{extended_duration}) {
            $duration .= $value->{extended_duration};
        }
        else {
            $duration .= '+0D';
        }
    }

    return $duration;
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
