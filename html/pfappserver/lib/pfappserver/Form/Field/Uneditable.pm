package pfappserver::Form::Field::Uneditable;

use Moose;
extends 'HTML::FormHandler::Field::Text';

has '+widget' => ( default => 'Span' );

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
