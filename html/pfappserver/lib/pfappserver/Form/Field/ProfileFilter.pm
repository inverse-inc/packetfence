package pfappserver::Form::Field::ProfileFilter;

=head1 NAME

pfappserver::Form::Field::ProfileFilter - a filter for the connection profile

=head1 DESCRIPTION

This is a compound field that requires only one value of the form
  \d[smhDWMY]

The time unit is rendered using the ButtonGroup widget.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use namespace::autoclean;

use pf::config;
use pf::factory::condition::profile;
use pf::validation::profile_filters;

has '+do_wrapper' => ( default => 1 );
has '+do_label' => ( default => 1 );
has '+inflate_default_method'=> ( default => sub { \&filter_inflate } );
has '+deflate_value_method'=> ( default => sub { \&filter_deflate } );
has '+wrapper_class' => (builder => 'filter_wrapper_class');

sub filter_wrapper_class {[qw(compound-input-btn-group)] }

has_field 'type' =>
  (
   type => 'Select',
   do_label => 0,
   required => 1,
   widget_wrapper => 'None',
   default => 'ssid',
   options_method => \&options_type,
  );
has_field 'match' =>
  (
   type => 'Text',
   do_label => 0,
   widget_wrapper => 'None',
   element_class => ['input-medium'],
   required => 1,
  );

sub filter_inflate {
    my ($self, $value) = @_;
    my $hash = {};
    if (defined $value) {
        if ($value =~ m/^([^:]+):(.+)$/) {
            @{$hash}{'type', 'match'} = ($1, $2);
        }
        else {
            @{$hash}{'type', 'match'} = ('ssid', $value);
        }
    }
    return $hash;
}

sub filter_deflate {
    my ($self, $value) = @_;
    my $type = $value->{type};
    my $match = $value->{match};
    return "${type}:${match}";
}

sub options_type {
    my $self = shift;
    local $_;
    return map {{value => $_, label => $self->_localize("profile.filter.$_")}}
      sort keys %pf::factory::condition::profile::PROFILE_FILTER_TYPE_TO_CONDITION_TYPE;
}

=head2 validate

Validate filter

=cut

sub validate {
    my ($self) = @_;
    my $validator = pf::validation::profile_filters->new;
    my $value = $self->filter_deflate($self->value);
    my ($rc, $message) = $validator->validate($value);
    unless ($rc) {
        $self->add_error($message);
    }
    return $rc;
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
