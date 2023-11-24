package fingerbank::Schema::Local::User_Agent;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema::User_Agent';

__PACKAGE__->meta->make_immutable;

1;
