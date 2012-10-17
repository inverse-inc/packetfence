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

has '+do_wrapper' => ( default => 1 );
has '+do_label' => ( default => 1 );
has '+inflate_default_method'=> ( default => sub { \&duration_inflate } );
has '+deflate_value_method'=> ( default => sub { \&duration_deflate } );

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
   widget => 'ButtonGroup',
   do_label => 0,
   localize_labels => 1,
   tags => { no_errors => 1 },
   wrapper_class => ['btn-group'],
   wrapper_attr => {'data-toggle' => 'buttons-radio'},
   options => [
               {value => 's', label => 'seconds'},
               {value => 'm', label => 'minutes'},
               {value => 'h', label => 'hours'},
               {value => 'D', label => 'days'},
               {value => 'W', label => 'weeks'},
               {value => 'M', label => 'months'},
               {value => "Y", label => 'years'},
              ],
   apply => [ { check => $TIME_MODIFIER_RE } ],
  );

sub duration_inflate {
    my ($self, $value) = @_;

    return {} unless ($value =~ m/(\d+)($TIME_MODIFIER_RE)/);
    my $hash = {interval => $1,
                unit => $2};

    return $hash;
}

sub duration_deflate {
    my ($self, $value) = @_;

    my $interval = $value->{interval};
    my $unit = $value->{unit};

    return $interval.$unit;
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
