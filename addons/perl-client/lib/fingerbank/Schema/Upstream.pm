package fingerbank::Schema::Upstream;

use Moose;
use namespace::autoclean;

extends 'DBIx::Class::Schema';

__PACKAGE__->load_classes;

__PACKAGE__->meta->make_immutable;

1;
