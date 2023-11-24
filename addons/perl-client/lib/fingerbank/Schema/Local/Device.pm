package fingerbank::Schema::Local::Device;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema::Device';

__PACKAGE__->meta->make_immutable;

1;
