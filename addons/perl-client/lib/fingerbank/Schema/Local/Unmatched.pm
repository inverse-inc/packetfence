package fingerbank::Schema::Local::Unmatched;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema::Unmatched';

__PACKAGE__->meta->make_immutable;

1;
