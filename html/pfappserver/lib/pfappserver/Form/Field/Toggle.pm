package pfappserver::Form::Field::Toggle;

=head1 NAME

pfappserver::Form::Field::Toggle - checkbox specific to PacketFence

=head1 DESCRIPTION

This field extends the default Checkbox. It is checked if the input
value matches the checkbox_value attribute.

=cut

use Moose;
extends 'HTML::FormHandler::Field::Checkbox';
use pf::util qw(isenabled) ;
use namespace::autoclean;

has '+checkbox_value' => ( default => 'Y' );
has 'unchecked_value' => ( is => 'ro', default => 'N' );
has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );
has '+input_without_param' => ( default => undef );

sub inflate {
    my ($self, $value) = @_;
    return isenabled($value) ? $self->checkbox_value : $self->unchecked_value;
}

sub deflate {
    my ($self, $value) = @_;
    if ($self->required) {
        return $self->inflate($value);
    }

    return !defined $value ? undef : $self->inflate($value)
}

sub value {
    my $field = shift;
    return $field->next::method(@_) if @_;
    my $v = HTML::FormHandler::Field::value($field);
    return defined $v ? $v : ($field->required ? $field->unchecked_value : undef);
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
