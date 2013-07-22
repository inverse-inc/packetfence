package pfappserver::Form::Field::ProfileFilter;

=head1 NAME

pfappserver::Form::Field::ProfileFilter - a filter for the portal profile

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
has '+inflate_default_method'=> ( default => sub { \&filter_inflate } );
has '+deflate_value_method'=> ( default => sub { \&filter_deflate } );
has '+wrapper_class' => (builder => 'filter_wrapper_class');

sub filter_wrapper_class {[qw(compound-input-btn-group)] }

has_field 'match' =>
  (
   type => 'Text',
   do_label => 0,
   widget_wrapper => 'None',
  );
has_field 'type' =>
  (
   type => 'Select',
   widget => 'ButtonGroup',
   do_label => 0,
   tags => { no_errors => 1 },
   wrapper_class => ['btn-group'],
   wrapper_attr => {'data-toggle' => 'buttons-radio'},
   default => 'ssid',
   options => [
               {value => 'ssid', label => 'SSID'},
               {value => 'vlan', label => 'VLAN'},
               {value => 'switch', label => 'SWITCH'},
              ],
  );

sub filter_inflate {
    my ($self, $value) = @_;
    my $hash = {};
    if (defined $value) {
        if($value =~ m/^([^:]+):(.+)$/) {
            @{$hash}{'type','match'} = ($1, $2);
        }
        else {
            @{$hash}{'type','match'} = ('ssid', $value);
        }
    }
    return $hash;
}

sub filter_deflate {
    my ($self, $value) = @_;
    my $type = $value->{type};
    my $match = $value->{match};
    return  $match ? "${type}:${match}"  : "" ;
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
