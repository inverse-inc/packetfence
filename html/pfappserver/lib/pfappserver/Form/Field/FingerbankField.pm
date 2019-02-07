package pfappserver::Form::Field::FingerbankField;

=head1 NAME

pfappserver::Form::Field::FingerbankField

=head1 DESCRIPTION

This field extends a text field to allow type ahead on the Fingerbank database and to translate the values to IDs

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Text';

use pf::util;
use namespace::autoclean;

use pf::error qw(is_success);

has '+inflate_default_method'=> ( default => sub { \&fingerbank_inflate } );
has '+deflate_value_method'=> ( default => sub { \&fingerbank_deflate } );

has 'fingerbank_model' => (isa => 'Str', is => 'rw');

# Adding the fingerbank-type-ahead class to the element
around 'element_class' => sub {
    my ($orig, $self) = @_;
    return [ "fingerbank-type-ahead", @{$self->$orig()} ];
};

# Adding the model inside a data attribute
around 'element_attr' => sub {
    my ($orig, $self) = @_;
    return { 'data-type-ahead-for' => $self->fingerbank_model, %{$self->$orig()} };
};

=head2 validate

Validate that the field value is a valid Fingerbank value

=cut

sub validate {
    my ($self) = @_;
    my $value = $self->value;
    # Don't validate empty values
    return if($value eq "");

    unless(defined($self->_id_from_value($value))) {
        $self->add_error("Could not find ".$self->label." with value $value");
    }
}

=head2 fingerbank_inflate

Inflate the value stored as an ID to the value

=cut

sub fingerbank_inflate {
    my ($self, $value) = @_;

    my ($status, $result) = $self->fingerbank_model->read_hashref($value);

    if(is_success($status)) {
        my $value_field = $self->fingerbank_model->value_field;
        return $result->{$value_field};
    }
    else {
        return $value;
    }
}

=head2 fingerbank_deflate

Deflate the value to the appropriate Fingerbank ID

=cut

sub fingerbank_deflate {
    my ($self, $value) = @_;
    return $self->_id_from_value($value);
}

=head2 _id_from_value

Returns the appropriate ID for a given value

=cut

sub _id_from_value {
    my ($self, $value) = @_;
    
    my ($status, $result) = $self->fingerbank_model->search([$self->fingerbank_model->value_field => $value]);
    
    if(is_success($status)){
        return $result->[0]->first->id;
    }
    else {
        return undef;
    }
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


