package pfappserver::Form::Field::FingerbankField;

=head1 NAME

pfappserver::Form::Field::MACAddress - MAC address input field

=head1 DESCRIPTION

This field extends the default Text field and checks if the input
value is a MAC address.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Text';

use pf::util;
use namespace::autoclean;

use pf::error qw(is_success);

has '+inflate_default_method'=> ( default => sub { \&fingerbank_inflate } );
has '+deflate_value_method'=> ( default => sub { \&fingerbank_deflate } );

has 'fingerbank_model' => (isa => 'Str', is => 'rw');

around 'element_class' => sub {
    my ($orig, $self) = @_;
    return [ "fingerbank-type-ahead", @{$self->$orig()} ];
};

around 'element_attr' => sub {
    my ($orig, $self) = @_;
    return { 'data-type-ahead-for' => $self->fingerbank_model, %{$self->$orig()} };
};

sub fingerbank_inflate {
    my ($self, $value) = @_;

    my ($status, $result) = $self->fingerbank_model->read($value);

    if(is_success($status)) {
        my $value_field = $self->fingerbank_model->value_field;
        return $result->{$value_field};
    }
    else {
        return $value;
    }
}

sub fingerbank_deflate {
    my ($self, $value) = @_;

    my ($status, $result) = $self->fingerbank_model->search([$self->fingerbank_model->value_field => $value]);
    
    if(is_success($status)){
        return $result->[0]->first->id;
    }
    else {
        die "Cannot compute Fingerbank storable value from $value";
    }
}


=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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


