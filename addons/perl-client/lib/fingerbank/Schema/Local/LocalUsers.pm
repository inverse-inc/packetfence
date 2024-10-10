package fingerbank::Schema::Local::LocalUsers;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema::LocalUsers';

__PACKAGE__->meta->make_immutable;

1;
