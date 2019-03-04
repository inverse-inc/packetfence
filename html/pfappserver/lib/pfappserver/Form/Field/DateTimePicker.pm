package pfappserver::Form::Field::DateTimePicker;

=head1 NAME

pfappserver::Form::Field::DateTimePicker - date/time pickers compound

=head1 DESCRIPTION

This is a compound field that requires a timestamp of the form
  YYY-MM-DD HH:MM

The date field is expected to be used with the datepicker jQuery widget.

The time field is expected to be used with the timepicker jQuery widget.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use namespace::autoclean;

has '+do_wrapper' => ( default => 1 );
has '+do_label' => ( default => 1 );
has '+inflate_default_method'=> ( default => sub { \&datetime_inflate } );
has '+deflate_value_method'=> ( default => sub { \&datetime_deflate } );

has_field 'date' =>
  (
   type => 'DatePicker',
   do_label => 0,
   widget_wrapper => 'None',
  );
has_field 'time' => 
  (
   type => 'TimePicker',
   do_label => 0,
   widget_wrapper => 'None',
  );

sub datetime_inflate {
    my ($self, $value) = @_;

    return {} unless ($value =~ m/(\d{4}-\d{1,2}-\d{1,2}) (\d{1,2}:\d{1,2})/);
    my $hash = {date => $1,
                time => $2};

    return $hash;
}

sub datetime_deflate {
    my ($self, $value) = @_;

    my $date = $value->{date};
    my $time = $value->{time};

    return "$date $time";
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
